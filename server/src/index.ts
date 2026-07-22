import path from 'path';
import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { env } from './config/env.js';
import { initSocket } from './socket/index.js';
import { startSimulation } from './simulation/engine.js';
import authRoutes from './routes/auth.routes.js';
import { rideRouter, fareRouter } from './routes/ride.routes.js';
import savedPlaceRoutes from './routes/savedPlace.routes.js';
import promoRoutes from './routes/promo.routes.js';
import notificationRoutes from './routes/notification.routes.js';
import { errorHandler } from './middleware/error.js';
import { prisma } from './config/database.js';

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ success: true, data: { status: 'ok' } }));

// App-store requirement: privacy policy reachable in a browser
app.get('/privacy', (_req, res) =>
  res.sendFile(path.resolve(process.cwd(), 'public', 'privacy.html'))
);

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/rides', rideRouter);
app.use('/api/v1/fare', fareRouter);
app.use('/api/v1/saved-places', savedPlaceRoutes);
app.use('/api/v1/promo', promoRoutes);
app.use('/api/v1/notifications', notificationRoutes);

app.use(errorHandler);

const httpServer = createServer(app);
initSocket(httpServer);

httpServer.listen(env.PORT, async () => {
  console.log(`[ridenow] listening on :${env.PORT}`);
  // Set all drivers to 'available' on boot so demo works without a driver app
  try {
    const drivers = await prisma.driverProfile.findMany();
    for (const d of drivers) {
      if (d.status === 'offline') {
        await prisma.driverProfile.update({ where: { id: d.id }, data: { status: 'available' } });
      }
    }
    console.log(`[ridenow] ${drivers.length} driver(s) ready`);
  } catch (e) {
    console.warn('[ridenow] could not auto-activate drivers (db not seeded?)');
  }
  startSimulation();
});
