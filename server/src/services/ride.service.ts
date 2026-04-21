import { prisma } from '../config/database.js';
import { estimateFare } from './fare.service.js';
import { haversineKm, interpolateRoute, encodeRoute } from '../utils/geo.js';
import { badRequest, forbidden, notFound } from '../utils/errors.js';

export type RideStatus = 'requested' | 'accepted' | 'driver_arrived' | 'in_progress' | 'completed' | 'cancelled';

const VALID_TRANSITIONS: Record<string, RideStatus[]> = {
  requested: ['accepted', 'cancelled'],
  accepted: ['driver_arrived', 'cancelled'],
  driver_arrived: ['in_progress', 'cancelled'],
  in_progress: ['completed', 'cancelled'],
  completed: [],
  cancelled: [],
};

export function assertTransition(from: string, to: RideStatus) {
  if (!VALID_TRANSITIONS[from]?.includes(to)) {
    throw badRequest(`Invalid transition: ${from} → ${to}`);
  }
}

export async function createRide(riderId: string, body: {
  pickup_lat: number; pickup_lng: number; pickup_address: string;
  dropoff_lat: number; dropoff_lng: number; dropoff_address: string;
  vehicle_type_requested: string; promo_code?: string;
}) {
  const est = await estimateFare({
    pickupLat: body.pickup_lat, pickupLng: body.pickup_lng,
    dropoffLat: body.dropoff_lat, dropoffLng: body.dropoff_lng,
    vehicleType: body.vehicle_type_requested, promoCode: body.promo_code,
  });

  const pts = interpolateRoute(body.pickup_lat, body.pickup_lng, body.dropoff_lat, body.dropoff_lng);
  const polyline = encodeRoute(pts);

  const ride = await prisma.ride.create({
    data: {
      riderId,
      status: 'requested',
      vehicleTypeRequested: body.vehicle_type_requested,
      pickupAddress: body.pickup_address,
      pickupLat: body.pickup_lat, pickupLng: body.pickup_lng,
      dropoffAddress: body.dropoff_address,
      dropoffLat: body.dropoff_lat, dropoffLng: body.dropoff_lng,
      estimatedDistanceKm: est.estimated_distance_km,
      estimatedDurationMin: est.estimated_duration_min,
      estimatedFare: est.estimated_fare,
      surgeMultiplier: est.surge_multiplier,
      routePolyline: polyline,
      promoCodeApplied: body.promo_code ?? null,
      discountAmount: est.fare_breakdown.discount_amount,
    },
  });

  return { ride, estimate: est };
}

export async function getRide(rideId: string, userId: string) {
  const ride = await prisma.ride.findUnique({
    where: { id: rideId },
    include: {
      rider: { select: { id: true, fullName: true, phone: true, avatarUrl: true, ratingAvg: true, ratingCount: true } },
      driver: { select: { id: true, fullName: true, phone: true, avatarUrl: true, ratingAvg: true, ratingCount: true } },
      vehicle: true,
      rating: true,
    },
  });
  if (!ride) throw notFound('Ride not found');
  if (ride.riderId !== userId && ride.driverId !== userId) throw forbidden();
  return ride;
}

export async function cancelRide(rideId: string, userId: string, reason?: string) {
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw notFound('Ride not found');
  if (ride.riderId !== userId && ride.driverId !== userId) throw forbidden();
  assertTransition(ride.status, 'cancelled');
  const cancelledBy = ride.riderId === userId ? 'rider' : 'driver';
  const updated = await prisma.ride.update({
    where: { id: rideId },
    data: {
      status: 'cancelled', cancellationReason: reason ?? null,
      cancelledBy, cancelledAt: new Date(),
    },
  });
  if (ride.driverId) {
    await prisma.driverProfile.update({ where: { userId: ride.driverId }, data: { status: 'available' } });
  }
  return updated;
}

export async function rateRide(rideId: string, raterId: string, score: number, comment?: string, tags?: string[]) {
  if (score < 1 || score > 5) throw badRequest('Score must be 1-5');
  const ride = await prisma.ride.findUnique({ where: { id: rideId } });
  if (!ride) throw notFound('Ride not found');
  if (ride.status !== 'completed') throw badRequest('Ride not completed');
  const rated = ride.riderId === raterId ? ride.driverId : ride.riderId;
  if (!rated) throw badRequest('Cannot rate: no counterparty');
  if (ride.riderId !== raterId && ride.driverId !== raterId) throw forbidden();

  const existing = await prisma.rideRating.findUnique({ where: { rideId } });
  if (existing) throw badRequest('Already rated');

  const rating = await prisma.rideRating.create({
    data: {
      rideId, ratedById: raterId, ratedUserId: rated,
      score, comment: comment ?? null,
      tags: tags && tags.length ? JSON.stringify(tags) : null,
    },
  });

  // update rated user's rating_avg
  const user = await prisma.user.findUnique({ where: { id: rated } });
  if (user) {
    const newCount = user.ratingCount + 1;
    const newAvg = Math.round(((user.ratingAvg * user.ratingCount) + score) / newCount * 100) / 100;
    await prisma.user.update({ where: { id: rated }, data: { ratingAvg: newAvg, ratingCount: newCount } });
  }
  return rating;
}

export async function riderHistory(riderId: string, page: number, limit: number, status?: string) {
  const where: any = { riderId, ...(status ? { status } : {}) };
  const [rows, total] = await Promise.all([
    prisma.ride.findMany({
      where,
      orderBy: { requestedAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
      include: {
        driver: { select: { id: true, fullName: true, avatarUrl: true, ratingAvg: true } },
        vehicle: true,
        rating: true,
      },
    }),
    prisma.ride.count({ where }),
  ]);
  return { rows, total };
}

export { VALID_TRANSITIONS, haversineKm };
