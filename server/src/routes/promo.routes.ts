import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';
import { validatePromo } from '../services/promo.service.js';
import { ok } from '../utils/response.js';

const router = Router();

router.post('/validate', requireAuth, validateBody(z.object({ code: z.string() })), async (req, res, next) => {
  try { ok(res, await validatePromo(req.body.code)); } catch (e) { next(e); }
});

export default router;
