import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const LANDMARKS = [
  { name: 'CC Alamedas del Sinú', lat: 8.7489, lng: -75.8814 },
  { name: 'Universidad de Córdoba', lat: 8.7837, lng: -75.8608 },
  { name: 'Parque Lineal Río Sinú', lat: 8.7520, lng: -75.8835 },
  { name: 'Hospital San Jerónimo', lat: 8.7573, lng: -75.8862 },
  { name: 'Aeropuerto Los Garzones', lat: 8.8236, lng: -75.8258 },
  { name: 'CC Buenavista', lat: 8.7364, lng: -75.8783 },
  { name: 'Plaza de la Cruz', lat: 8.7530, lng: -75.8820 },
  { name: 'Terminal de Transportes', lat: 8.7665, lng: -75.8724 },
  { name: 'Estadio Jaraguay', lat: 8.7589, lng: -75.8775 },
  { name: 'Barrio Mocarí', lat: 8.7700, lng: -75.8650 },
  { name: 'Barrio La Castellana', lat: 8.7350, lng: -75.8850 },
  { name: 'CC Nuestro Montería', lat: 8.7480, lng: -75.8780 },
  { name: 'Colegio La Salle', lat: 8.7550, lng: -75.8790 },
  { name: 'Zona Industrial', lat: 8.7900, lng: -75.8550 },
  { name: 'Country Club', lat: 8.7300, lng: -75.8900 },
];

async function main() {
  console.log('🌱 seeding...');

  // Clean slate
  await prisma.rideRating.deleteMany();
  await prisma.rideLocationLog.deleteMany();
  await prisma.ride.deleteMany();
  await prisma.savedPlace.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.vehicle.deleteMany();
  await prisma.driverProfile.deleteMany();
  await prisma.promoCode.deleteMany();
  await prisma.fareConfig.deleteMany();
  await prisma.user.deleteMany();

  // Fare configs
  await prisma.fareConfig.createMany({
    data: [
      { vehicleType: 'economy', baseFare: 3500, perKmRate: 1200, perMinuteRate: 250, minimumFare: 5000, bookingFee: 1000, surgeThreshold: 5, maxSurgeMultiplier: 3.0 },
      { vehicleType: 'comfort', baseFare: 5000, perKmRate: 1800, perMinuteRate: 400, minimumFare: 8000, bookingFee: 1500, surgeThreshold: 4, maxSurgeMultiplier: 3.0 },
      { vehicleType: 'premium', baseFare: 8000, perKmRate: 2500, perMinuteRate: 600, minimumFare: 12000, bookingFee: 2000, surgeThreshold: 3, maxSurgeMultiplier: 3.5 },
      { vehicleType: 'xl',      baseFare: 6000, perKmRate: 2000, perMinuteRate: 450, minimumFare: 9000, bookingFee: 1500, surgeThreshold: 4, maxSurgeMultiplier: 3.0 },
    ],
  });

  // Promo codes
  await prisma.promoCode.createMany({
    data: [
      { code: 'RIDENOW50', discountType: 'percentage', discountValue: 50, maxUses: 100, validFrom: new Date('2026-01-01'), validUntil: new Date('2026-12-31') },
      { code: 'FIRST5K',   discountType: 'fixed',      discountValue: 5000, maxUses: 50,  validFrom: new Date('2026-01-01'), validUntil: new Date('2026-12-31') },
      { code: 'WELCOME',   discountType: 'percentage', discountValue: 25, maxUses: 200, validFrom: new Date('2026-01-01'), validUntil: new Date('2026-12-31') },
    ],
  });

  const riderPass = await bcrypt.hash('demo1234', 12);
  const driverPass = await bcrypt.hash('demo1234', 12);
  const adminPass = await bcrypt.hash('admin1234', 12);

  // Riders
  const rider1 = await prisma.user.create({
    data: { email: 'rider@demo.com', passwordHash: riderPass, fullName: 'Daniel Sarmiento', phone: '5555555', role: 'rider', ratingAvg: 4.85, ratingCount: 12 },
  });
  const rider2 = await prisma.user.create({
    data: { email: 'rider2@demo.com', passwordHash: riderPass, fullName: 'María López', phone: '+57 301 234 5678', role: 'rider', ratingAvg: 4.92, ratingCount: 8 },
  });

  // Admin
  await prisma.user.create({
    data: { email: 'admin@demo.com', passwordHash: adminPass, fullName: 'Admin RideNow', phone: '+57 300 000 0000', role: 'admin' },
  });

  // Drivers + vehicles (spawn near different landmarks)
  const driverDefs = [
    { email: 'driver@demo.com',  fullName: 'Juan Rodríguez',   phone: '+57 302 345 6789', rating: 4.78, license: 'LIC-001', vt: 'economy', make: 'Toyota',  model: 'Corolla',   year: 2020, color: 'Silver', plate: 'ABC-123', cap: 4, spawn: LANDMARKS[0] },
    { email: 'driver2@demo.com', fullName: 'Ana Gómez',        phone: '+57 303 456 7890', rating: 4.95, license: 'LIC-002', vt: 'comfort', make: 'Mazda',   model: '3',         year: 2022, color: 'Red',    plate: 'DEF-456', cap: 4, spawn: LANDMARKS[1] },
    { email: 'driver3@demo.com', fullName: 'Pedro Sánchez',    phone: '+57 304 567 8901', rating: 4.60, license: 'LIC-003', vt: 'premium', make: 'BMW',     model: '320i',      year: 2023, color: 'Black',  plate: 'GHI-789', cap: 4, spawn: LANDMARKS[6] },
    { email: 'driver4@demo.com', fullName: 'Laura Hernández',  phone: '+57 305 678 9012', rating: 4.88, license: 'LIC-004', vt: 'xl',      make: 'Toyota',  model: 'Fortuner',  year: 2021, color: 'White',  plate: 'JKL-012', cap: 7, spawn: LANDMARKS[11] },
    { email: 'driver5@demo.com', fullName: 'Diego Torres',     phone: '+57 306 789 0123', rating: 4.72, license: 'LIC-005', vt: 'economy', make: 'Renault', model: 'Logan',     year: 2019, color: 'Blue',   plate: 'MNO-345', cap: 4, spawn: LANDMARKS[10] },
  ];

  const drivers: Array<{ userId: string; profileId: string; vehicleId: string; vt: string; spawn: { lat: number; lng: number } }> = [];
  for (const d of driverDefs) {
    const user = await prisma.user.create({
      data: { email: d.email, passwordHash: driverPass, fullName: d.fullName, phone: d.phone, role: 'driver', ratingAvg: d.rating, ratingCount: 20 },
    });
    const profile = await prisma.driverProfile.create({
      data: {
        userId: user.id,
        licenseNumber: d.license,
        licenseExpiry: new Date('2028-12-31'),
        status: 'available',
        currentLat: d.spawn.lat, currentLng: d.spawn.lng, currentHeading: Math.random() * 360,
        isApproved: true,
      },
    });
    const vehicle = await prisma.vehicle.create({
      data: {
        driverProfileId: profile.id,
        vehicleType: d.vt, make: d.make, model: d.model, year: d.year, color: d.color,
        plateNumber: d.plate, capacity: d.cap, isActive: true,
      },
    });
    await prisma.driverProfile.update({ where: { id: profile.id }, data: { currentVehicleId: vehicle.id } });
    drivers.push({ userId: user.id, profileId: profile.id, vehicleId: vehicle.id, vt: d.vt, spawn: d.spawn });
  }

  // Saved places for rider1
  await prisma.savedPlace.createMany({
    data: [
      { userId: rider1.id, label: 'Home',  address: 'Barrio La Castellana, Cra 6 #56-30',       lat: 8.7350, lng: -75.8850, icon: 'home',     sortOrder: 0 },
      { userId: rider1.id, label: 'Work',  address: 'Centro, Calle 29 #4-45',                    lat: 8.7530, lng: -75.8820, icon: 'work',     sortOrder: 1 },
      { userId: rider1.id, label: 'Gym',   address: 'CC Alamedas del Sinú, Local 215',           lat: 8.7489, lng: -75.8814, icon: 'fitness',  sortOrder: 2 },
    ],
  });

  // Historic rides
  const now = Date.now();
  for (let i = 0; i < 25; i++) {
    const a = LANDMARKS[Math.floor(Math.random() * LANDMARKS.length)];
    let b = LANDMARKS[Math.floor(Math.random() * LANDMARKS.length)];
    while (b === a) b = LANDMARKS[Math.floor(Math.random() * LANDMARKS.length)];
    const driver = drivers[i % drivers.length];
    const daysAgo = Math.floor(Math.random() * 30);
    const requested = new Date(now - daysAgo * 86400000 - Math.random() * 86400000);
    const accepted = new Date(requested.getTime() + 30_000);
    const arrived = new Date(accepted.getTime() + 5 * 60_000);
    const started = new Date(arrived.getTime() + 90_000);
    const durationMin = 8 + Math.floor(Math.random() * 20);
    const completed = new Date(started.getTime() + durationMin * 60_000);
    const distKm = 2 + Math.random() * 10;
    const fare = Math.round((5000 + distKm * 1500 + durationMin * 300) / 100) * 100;

    const ride = await prisma.ride.create({
      data: {
        riderId: i % 2 === 0 ? rider1.id : rider2.id,
        driverId: driver.userId,
        vehicleId: driver.vehicleId,
        status: 'completed',
        vehicleTypeRequested: driver.vt,
        pickupAddress: a.name, pickupLat: a.lat, pickupLng: a.lng,
        dropoffAddress: b.name, dropoffLat: b.lat, dropoffLng: b.lng,
        estimatedDistanceKm: distKm, actualDistanceKm: distKm,
        estimatedDurationMin: durationMin, actualDurationMin: durationMin,
        estimatedFare: fare, actualFare: fare,
        paymentStatus: 'paid',
        requestedAt: requested, acceptedAt: accepted, arrivedAt: arrived, startedAt: started, completedAt: completed,
      },
    });
    if (Math.random() < 0.7) {
      await prisma.rideRating.create({
        data: { rideId: ride.id, ratedById: ride.riderId, ratedUserId: ride.driverId!, score: 4 + Math.floor(Math.random() * 2) },
      });
    }
  }

  // Cancelled rides
  for (let i = 0; i < 4; i++) {
    const a = LANDMARKS[Math.floor(Math.random() * LANDMARKS.length)];
    const b = LANDMARKS[Math.floor(Math.random() * LANDMARKS.length)];
    const daysAgo = Math.floor(Math.random() * 20);
    const requested = new Date(now - daysAgo * 86400000);
    await prisma.ride.create({
      data: {
        riderId: rider1.id,
        status: 'cancelled',
        vehicleTypeRequested: 'economy',
        pickupAddress: a.name, pickupLat: a.lat, pickupLng: a.lng,
        dropoffAddress: b.name, dropoffLat: b.lat, dropoffLng: b.lng,
        estimatedFare: 8000,
        cancelledBy: i % 2 === 0 ? 'rider' : 'system',
        cancellationReason: i % 2 === 0 ? 'Changed my mind' : 'No drivers available',
        requestedAt: requested, cancelledAt: new Date(requested.getTime() + 60_000),
      },
    });
  }

  console.log('✅ seed complete');
  console.log('   rider@demo.com / demo1234');
  console.log('   driver@demo.com / demo1234');
  console.log('   admin@demo.com / admin1234');
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
