import { prisma } from '../config/database.js';
import { haversineKm } from '../utils/geo.js';
import { badRequest } from '../utils/errors.js';

const SPEEDS: Record<string, number> = { economy: 25, comfort: 28, premium: 30, xl: 25 };
const ROAD_FACTOR = 1.3;

export interface FareEstimate {
  estimated_fare: number;
  estimated_distance_km: number;
  estimated_duration_min: number;
  surge_multiplier: number;
  fare_breakdown: {
    base_fare: number;
    distance_charge: number;
    time_charge: number;
    booking_fee: number;
    subtotal: number;
    surge_amount: number;
    discount_amount: number;
    total: number;
  };
  vehicle_type: string;
  currency: string;
}

export async function estimateFare(params: {
  pickupLat: number; pickupLng: number; dropoffLat: number; dropoffLng: number;
  vehicleType: string; surgeMultiplier?: number; promoCode?: string;
}): Promise<FareEstimate> {
  const config = await prisma.fareConfig.findUnique({ where: { vehicleType: params.vehicleType } });
  if (!config || !config.isActive) throw badRequest('Invalid vehicle type');

  const straightKm = haversineKm(params.pickupLat, params.pickupLng, params.dropoffLat, params.dropoffLng);
  const distanceKm = straightKm * ROAD_FACTOR;
  const avgSpeed = SPEEDS[params.vehicleType] ?? 25;
  const durationMin = (distanceKm / avgSpeed) * 60;

  const base = config.baseFare;
  const distCharge = distanceKm * config.perKmRate;
  const timeCharge = durationMin * config.perMinuteRate;
  const booking = config.bookingFee;
  let subtotal = base + distCharge + timeCharge + booking;

  const surge = params.surgeMultiplier ?? 1.0;
  const surgeAmount = subtotal * (surge - 1);
  subtotal = subtotal * surge;

  let discount = 0;
  if (params.promoCode) {
    const promo = await prisma.promoCode.findUnique({ where: { code: params.promoCode } });
    if (promo && promo.isActive && promo.validFrom <= new Date() && promo.validUntil >= new Date() && promo.usedCount < promo.maxUses) {
      discount = promo.discountType === 'percentage'
        ? subtotal * (promo.discountValue / 100)
        : promo.discountValue;
    }
  }

  let total = Math.max(subtotal - discount, config.minimumFare);
  total = Math.round(total / 100) * 100;

  return {
    estimated_fare: total,
    estimated_distance_km: Math.round(distanceKm * 100) / 100,
    estimated_duration_min: Math.round(durationMin),
    surge_multiplier: surge,
    fare_breakdown: {
      base_fare: base,
      distance_charge: Math.round(distCharge),
      time_charge: Math.round(timeCharge),
      booking_fee: booking,
      subtotal: Math.round(subtotal),
      surge_amount: Math.round(surgeAmount),
      discount_amount: Math.round(discount),
      total,
    },
    vehicle_type: params.vehicleType,
    currency: 'COP',
  };
}

export function computeRunningFare(
  distanceKm: number, elapsedMin: number,
  config: { baseFare: number; perKmRate: number; perMinuteRate: number; bookingFee: number; minimumFare: number },
  surge: number,
): number {
  const f = (config.baseFare + distanceKm * config.perKmRate + elapsedMin * config.perMinuteRate + config.bookingFee) * surge;
  return Math.max(f, config.minimumFare);
}
