import { prisma } from '../config/database.js';
import { env } from '../config/env.js';
import { getIO } from '../socket/index.js';
import { haversineKm, bearingDeg, interpolateRoute } from '../utils/geo.js';
import { fetchRoute, resample } from '../utils/osrm.js';
import { computeRunningFare } from '../services/fare.service.js';
import { findNearestDriver } from '../services/matching.service.js';
import { push } from '../services/notification.service.js';

interface ActiveRide {
  rideId: string;
  driverId: string;
  riderId: string;
  phase: 'to_pickup' | 'to_dropoff';
  route: Array<{ lat: number; lng: number }>;
  idx: number;
  vehicleType: string;
  fareConfig: { baseFare: number; perKmRate: number; perMinuteRate: number; bookingFee: number; minimumFare: number };
  surgeMultiplier: number;
  startedAt?: number;
  distanceTraveledKm: number;
}

const active = new Map<string, ActiveRide>();
const driverDriftSeed = new Map<string, { lat: number; lng: number }>();

export function startSimulation() {
  setInterval(tick, env.SIMULATION_TICK_MS);
  console.log(`[sim] tick every ${env.SIMULATION_TICK_MS}ms`);
}

export async function onRideRequested(rideId: string) {
  const delay = env.AUTO_ACCEPT_MIN_MS + Math.random() * (env.AUTO_ACCEPT_MAX_MS - env.AUTO_ACCEPT_MIN_MS);
  setTimeout(() => autoAccept(rideId).catch(e => console.error('[sim] autoAccept', e)), delay);

  getIO().to('available_drivers').emit('ride:requested', { ride_id: rideId });

  setTimeout(async () => {
    const r = await prisma.ride.findUnique({ where: { id: rideId } });
    if (r?.status === 'requested') {
      await prisma.ride.update({
        where: { id: rideId },
        data: { status: 'cancelled', cancelledBy: 'system', cancellationReason: 'No drivers available', cancelledAt: new Date() },
      });
      getIO().to(`ride:${rideId}`).emit('ride:no_drivers', { ride_id: rideId });
      getIO().to(`rider:${r.riderId}`).emit('ride:no_drivers', { ride_id: rideId });
    }
  }, env.RIDE_REQUEST_TIMEOUT_S * 1000);
}

// Pick a random realistic spawn ~0.5–1 km (haversine) from pickup.
// Road distance ≈ 1.3× → ~1.5–3 min at 25 km/h city speed.
function randomSpawn(pickupLat: number, pickupLng: number): { lat: number; lng: number } {
  const distKm = 0.5 + Math.random() * 0.5;
  const bearing = Math.random() * 2 * Math.PI;
  // 1 deg lat ~= 111km; lng factor depends on cos(lat)
  const dLat = (distKm / 111) * Math.cos(bearing);
  const dLng = (distKm / (111 * Math.cos((pickupLat * Math.PI) / 180))) * Math.sin(bearing);
  return { lat: pickupLat + dLat, lng: pickupLng + dLng };
}

async function autoAccept(rideId: string) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride || ride.status !== 'requested') return;

  const match = await findNearestDriver(ride.pickupLat, ride.pickupLng, ride.vehicleTypeRequested, env.DRIVER_SEARCH_RADIUS_KM * 4);
  if (!match) return;

  const vehicle = match.driver.vehicles.find(v => v.vehicleType === ride.vehicleTypeRequested);
  if (!vehicle) return;

  // If driver is too close, relocate them realistically 2-5 km out.
  let startLat = match.driver.currentLat!;
  let startLng = match.driver.currentLng!;
  // Always reposition so arrival is ≤ ~3 min. Keeps demo snappy.
  const curDist = haversineKm(startLat, startLng, ride.pickupLat, ride.pickupLng);
  if (curDist < 0.4 || curDist > 1.0) {
    const spawn = randomSpawn(ride.pickupLat, ride.pickupLng);
    startLat = spawn.lat;
    startLng = spawn.lng;
    await prisma.driverProfile.update({
      where: { userId: match.driver.userId },
      data: { currentLat: startLat, currentLng: startLng },
    });
  }

  // Fetch real road route from driver → pickup
  const osrm = await fetchRoute(
    { lat: startLat, lng: startLng },
    { lat: ride.pickupLat, lng: ride.pickupLng },
  );
  const rawRoute = osrm?.geometry ?? interpolateRoute(startLat, startLng, ride.pickupLat, ride.pickupLng, 60);
  const route = resample(rawRoute, 40);

  const updated = await prisma.ride.update({
    where: { id: rideId },
    data: {
      status: 'accepted',
      driverId: match.driver.userId,
      vehicleId: vehicle.id,
      acceptedAt: new Date(),
    },
    include: {
      driver: { select: { id: true, fullName: true, phone: true, avatarUrl: true, ratingAvg: true, ratingCount: true } },
      vehicle: true,
    },
  });

  await prisma.driverProfile.update({
    where: { userId: match.driver.userId },
    data: { status: 'busy', currentVehicleId: vehicle.id },
  });

  const fareConfig = await prisma.fareConfig.findUnique({ where: { vehicleType: ride.vehicleTypeRequested } });
  if (!fareConfig) return;

  active.set(rideId, {
    rideId,
    driverId: match.driver.userId,
    riderId: ride.riderId,
    phase: 'to_pickup',
    route, idx: 0,
    vehicleType: ride.vehicleTypeRequested,
    fareConfig,
    surgeMultiplier: ride.surgeMultiplier,
    distanceTraveledKm: 0,
  });

  const eta = Math.max(1, Math.round((osrm?.durationSec ?? routeDurationSec(route)) / 60));

  const acceptedPayload = {
    ride_id: rideId,
    driver_info: updated.driver,
    vehicle_info: updated.vehicle,
    eta_minutes: eta,
    driver_location: { lat: startLat, lng: startLng },
    route_to_pickup: route, // full polyline for live drawing
  };

  getIO().to(`rider:${ride.riderId}`).emit('ride:accepted', acceptedPayload);
  getIO().to(`ride:${rideId}`).emit('ride:accepted', acceptedPayload);

  push(ride.riderId, 'ride_accepted', 'Driver on the way!',
    `${updated.driver?.fullName ?? 'Driver'} is coming to pick you up.`,
    { ride_id: rideId });
}

function routeDurationSec(route: Array<{ lat: number; lng: number }>): number {
  let km = 0;
  for (let i = 0; i < route.length - 1; i++) {
    km += haversineKm(route[i].lat, route[i].lng, route[i + 1].lat, route[i + 1].lng);
  }
  return (km / env.SIMULATION_SPEED_KMH) * 3600;
}

function etaFromIdx(route: Array<{ lat: number; lng: number }>, idx: number): number {
  let km = 0;
  for (let i = idx; i < route.length - 1; i++) {
    km += haversineKm(route[i].lat, route[i].lng, route[i + 1].lat, route[i + 1].lng);
  }
  return Math.max(1, Math.round((km / env.SIMULATION_SPEED_KMH) * 60));
}

async function tick() {
  for (const a of Array.from(active.values())) {
    try { await advanceRide(a); } catch (e) { console.error('[sim] advance', e); }
  }
  await idleDrift();
}

// With 40m steps and ~25 km/h, one tick should move ~14m. But to keep perceived motion,
// we advance by `stepsPerTick = max(1, floor((speed_kmh * tick_sec) / stepMeters))` positions.
function stepsPerTick(): number {
  const mPerTick = (env.SIMULATION_SPEED_KMH * 1000 / 3600) * (env.SIMULATION_TICK_MS / 1000);
  return Math.max(1, Math.round(mPerTick / 40));
}

async function advanceRide(a: ActiveRide) {
  const steps = stepsPerTick();
  const nextIdx = Math.min(a.idx + steps, a.route.length - 1);
  const cur = a.route[nextIdx];
  const prev = a.route[a.idx];
  const heading = bearingDeg(prev.lat, prev.lng, cur.lat, cur.lng);
  let addKm = 0;
  for (let i = a.idx; i < nextIdx; i++) {
    addKm += haversineKm(a.route[i].lat, a.route[i].lng, a.route[i + 1].lat, a.route[i + 1].lng);
  }
  a.distanceTraveledKm += addKm;
  a.idx = nextIdx;

  await prisma.driverProfile.update({
    where: { userId: a.driverId },
    data: { currentLat: cur.lat, currentLng: cur.lng, currentHeading: heading },
  });

  if (a.phase === 'to_pickup') {
    const ride = await prisma.ride.findUnique({ where: { id: a.rideId } });
    if (!ride || ride.status === 'cancelled') { active.delete(a.rideId); return; }

    const distToPickup = haversineKm(cur.lat, cur.lng, ride.pickupLat, ride.pickupLng);
    const eta = etaFromIdx(a.route, a.idx);

    const payload = {
      ride_id: a.rideId,
      driver_location: { lat: cur.lat, lng: cur.lng, heading },
      eta_minutes: eta,
      distance_km: round(distToPickup),
      phase: 'to_pickup',
    };
    getIO().to(`rider:${a.riderId}`).emit('ride:driver_arriving', payload);
    getIO().to(`ride:${a.rideId}`).emit('ride:location_tick', {
      ...payload, lat: cur.lat, lng: cur.lng, distance_remaining_km: round(distToPickup),
    });

    if (distToPickup < 0.04 || a.idx >= a.route.length - 1) {
      await prisma.ride.update({ where: { id: a.rideId }, data: { status: 'driver_arrived', arrivedAt: new Date() } });
      getIO().to(`rider:${a.riderId}`).emit('ride:driver_arrived', { ride_id: a.rideId });
      getIO().to(`ride:${a.rideId}`).emit('ride:driver_arrived', { ride_id: a.rideId });
      push(a.riderId, 'driver_arriving', 'Your driver is here!', 'Head out to meet your driver.', { ride_id: a.rideId });
      setTimeout(() => startRide(a.rideId).catch(e => console.error(e)), 6000);
      active.delete(a.rideId);
    }
  } else if (a.phase === 'to_dropoff') {
    const ride = await prisma.ride.findUnique({ where: { id: a.rideId } });
    if (!ride || ride.status === 'cancelled') { active.delete(a.rideId); return; }

    const distRemain = haversineKm(cur.lat, cur.lng, ride.dropoffLat, ride.dropoffLng);
    const elapsedMin = (Date.now() - (a.startedAt ?? Date.now())) / 60000;
    const runningFare = computeRunningFare(a.distanceTraveledKm, elapsedMin, a.fareConfig, a.surgeMultiplier);
    const eta = etaFromIdx(a.route, a.idx);

    const tickData = {
      ride_id: a.rideId,
      lat: cur.lat, lng: cur.lng, heading,
      eta_minutes: eta,
      distance_remaining_km: round(distRemain),
      distance_traveled_km: round(a.distanceTraveledKm),
      fare_current: Math.round(runningFare),
      phase: 'to_dropoff',
    };
    getIO().to(`ride:${a.rideId}`).emit('ride:location_tick', tickData);
    getIO().to(`rider:${a.riderId}`).emit('ride:location_tick', tickData);

    if (distRemain < 0.04 || a.idx >= a.route.length - 1) {
      await completeRide(a);
      active.delete(a.rideId);
    }
  }
}

async function startRide(rideId: string) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride || ride.status !== 'driver_arrived') return;

  const fareConfig = await prisma.fareConfig.findUnique({ where: { vehicleType: ride.vehicleTypeRequested } });
  if (!fareConfig || !ride.driverId) return;

  await prisma.ride.update({ where: { id: rideId }, data: { status: 'in_progress', startedAt: new Date() } });
  await prisma.driverProfile.update({ where: { userId: ride.driverId }, data: { status: 'on_ride' } });

  const osrm = await fetchRoute(
    { lat: ride.pickupLat, lng: ride.pickupLng },
    { lat: ride.dropoffLat, lng: ride.dropoffLng },
  );
  const raw = osrm?.geometry ?? interpolateRoute(ride.pickupLat, ride.pickupLng, ride.dropoffLat, ride.dropoffLng, 60);
  const route = resample(raw, 40);

  await prisma.ride.update({ where: { id: rideId }, data: { routePolyline: JSON.stringify(route) } });

  active.set(rideId, {
    rideId,
    driverId: ride.driverId,
    riderId: ride.riderId,
    phase: 'to_dropoff',
    route, idx: 0,
    vehicleType: ride.vehicleTypeRequested,
    fareConfig,
    surgeMultiplier: ride.surgeMultiplier,
    startedAt: Date.now(),
    distanceTraveledKm: 0,
  });

  const startPayload = {
    ride_id: rideId,
    route_polyline: route,
    eta_minutes: Math.max(1, Math.round((osrm?.durationSec ?? routeDurationSec(route)) / 60)),
  };
  getIO().to(`ride:${rideId}`).emit('ride:started', startPayload);
  getIO().to(`rider:${ride.riderId}`).emit('ride:started', startPayload);
  push(ride.riderId, 'ride_started', 'Ride started', 'Enjoy the trip!', { ride_id: rideId });
}

async function completeRide(a: ActiveRide) {
  const ride = await prisma.ride.findUnique({ where: { id: a.rideId } });
  if (!ride) return;
  const durationMin = ride.startedAt
    ? Math.max(1, Math.round((Date.now() - ride.startedAt.getTime()) / 60000))
    : 1;
  const fare = computeRunningFare(a.distanceTraveledKm, durationMin, a.fareConfig, a.surgeMultiplier);
  let finalFare = fare;
  if (ride.discountAmount) finalFare = Math.max(fare - ride.discountAmount, a.fareConfig.minimumFare);
  finalFare = Math.round(finalFare / 100) * 100;

  await prisma.ride.update({
    where: { id: a.rideId },
    data: {
      status: 'completed', completedAt: new Date(),
      actualDistanceKm: round(a.distanceTraveledKm), actualDurationMin: durationMin,
      actualFare: finalFare, paymentStatus: 'paid',
    },
  });
  await prisma.driverProfile.update({
    where: { userId: a.driverId },
    data: { status: 'available', totalRides: { increment: 1 }, totalEarnings: { increment: finalFare * (1 - 0.2) } },
  });
  if (ride.promoCodeApplied) {
    await prisma.promoCode.update({ where: { code: ride.promoCodeApplied }, data: { usedCount: { increment: 1 } } }).catch(() => {});
  }

  const breakdown = {
    base_fare: a.fareConfig.baseFare,
    distance_charge: Math.round(a.distanceTraveledKm * a.fareConfig.perKmRate),
    time_charge: Math.round(durationMin * a.fareConfig.perMinuteRate),
    booking_fee: a.fareConfig.bookingFee,
    surge_multiplier: a.surgeMultiplier,
    discount_amount: ride.discountAmount ?? 0,
    total: finalFare,
  };

  const payload = {
    ride_id: a.rideId, actual_fare: finalFare,
    distance_km: round(a.distanceTraveledKm), duration_min: durationMin,
    fare_breakdown: breakdown,
  };
  getIO().to(`ride:${a.rideId}`).emit('ride:completed', payload);
  getIO().to(`rider:${a.riderId}`).emit('ride:completed', payload);
  push(a.riderId, 'ride_completed', 'Ride complete',
    `Thanks for riding! Fare: ${finalFare.toLocaleString()} COP`, { ride_id: a.rideId });
}

async function idleDrift() {
  const drivers = await prisma.driverProfile.findMany({ where: { status: 'available' } });
  for (const d of drivers) {
    if (d.currentLat == null || d.currentLng == null) continue;
    const seed = driverDriftSeed.get(d.id) ?? { lat: d.currentLat, lng: d.currentLng };
    driverDriftSeed.set(d.id, seed);
    const jitter = 0.0003;
    const newLat = seed.lat + (Math.random() - 0.5) * jitter;
    const newLng = seed.lng + (Math.random() - 0.5) * jitter;
    await prisma.driverProfile.update({ where: { id: d.id }, data: { currentLat: newLat, currentLng: newLng } });
  }
}

function round(v: number) { return Math.round(v * 100) / 100; }
