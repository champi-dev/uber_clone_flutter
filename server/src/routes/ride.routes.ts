import { Router } from 'express';
import { z } from 'zod';
import { validateBody } from '../middleware/validate.js';
import { requireAuth, AuthedRequest } from '../middleware/auth.js';
import * as Rides from '../services/ride.service.js';
import { onRideRequested } from '../simulation/engine.js';
import { estimateFare } from '../services/fare.service.js';
import { ok } from '../utils/response.js';

const router = Router();

const createSchema = z.object({
  pickup_lat: z.number(), pickup_lng: z.number(), pickup_address: z.string(),
  dropoff_lat: z.number(), dropoff_lng: z.number(), dropoff_address: z.string(),
  vehicle_type_requested: z.enum(['economy', 'comfort', 'premium', 'xl']),
  promo_code: z.string().optional(),
});

router.post('/', requireAuth, validateBody(createSchema), async (req: AuthedRequest, res, next) => {
  try {
    const { ride, estimate } = await Rides.createRide(req.user!.id, req.body);
    onRideRequested(ride.id).catch(e => console.error(e));
    ok(res, { ride, estimate });
  } catch (e) { next(e); }
});

router.get('/history', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const page = Math.max(1, parseInt((req.query.page as string) || '1', 10));
    const limit = Math.min(50, parseInt((req.query.limit as string) || '20', 10));
    const status = req.query.status as string | undefined;
    const { rows, total } = await Rides.riderHistory(req.user!.id, page, limit, status);
    ok(res, rows, { page, limit, total });
  } catch (e) { next(e); }
});

router.get('/:id', requireAuth, async (req: AuthedRequest, res, next) => {
  try { ok(res, await Rides.getRide(req.params.id, req.user!.id)); } catch (e) { next(e); }
});

router.patch('/:id/cancel', requireAuth, validateBody(z.object({ reason: z.string().optional() })), async (req: AuthedRequest, res, next) => {
  try { ok(res, await Rides.cancelRide(req.params.id, req.user!.id, req.body.reason)); } catch (e) { next(e); }
});

router.post('/:id/rate', requireAuth, validateBody(z.object({
  score: z.number().int().min(1).max(5),
  comment: z.string().optional(),
  tags: z.array(z.string()).optional(),
})), async (req: AuthedRequest, res, next) => {
  try { ok(res, await Rides.rateRide(req.params.id, req.user!.id, req.body.score, req.body.comment, req.body.tags)); } catch (e) { next(e); }
});

// fare estimate (no auth needed to compute, but we still require it for consistency)
const fareRouter = Router();
fareRouter.get('/estimate', requireAuth, async (req, res, next) => {
  try {
    const q = req.query;
    const est = await estimateFare({
      pickupLat: parseFloat(q.pickup_lat as string),
      pickupLng: parseFloat(q.pickup_lng as string),
      dropoffLat: parseFloat(q.dropoff_lat as string),
      dropoffLng: parseFloat(q.dropoff_lng as string),
      vehicleType: q.vehicle_type as string,
      promoCode: q.promo_code as string | undefined,
    });
    ok(res, est);
  } catch (e) { next(e); }
});

export { router as rideRouter, fareRouter };
