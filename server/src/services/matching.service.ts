import { prisma } from '../config/database.js';
import { haversineKm } from '../utils/geo.js';

export async function findNearestDriver(pickupLat: number, pickupLng: number, vehicleType: string, radiusKm = 5) {
  const drivers = await prisma.driverProfile.findMany({
    where: { status: 'available', isApproved: true },
    include: { user: true, vehicles: { where: { isActive: true } } },
  });

  const candidates = drivers
    .filter(d => d.currentLat != null && d.currentLng != null)
    .filter(d => d.vehicles.some(v => v.vehicleType === vehicleType))
    .map(d => {
      const dist = haversineKm(pickupLat, pickupLng, d.currentLat!, d.currentLng!);
      return { driver: d, distance: dist };
    })
    .filter(c => c.distance <= radiusKm)
    .sort((a, b) => a.distance - b.distance || b.driver.user.ratingAvg - a.driver.user.ratingAvg);

  return candidates[0] ?? null;
}
