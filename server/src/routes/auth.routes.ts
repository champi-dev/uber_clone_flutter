import { Router } from 'express';
import { z } from 'zod';
import { validateBody } from '../middleware/validate.js';
import { requireAuth, AuthedRequest } from '../middleware/auth.js';
import * as Auth from '../services/auth.service.js';
import { ok } from '../utils/response.js';

const router = Router();

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  full_name: z.string().min(1),
  phone: z.string().min(5),
  role: z.enum(['rider', 'driver']).optional(),
});

router.post('/register', validateBody(registerSchema), async (req, res, next) => {
  try {
    const b = req.body;
    const data = await Auth.register({
      email: b.email, password: b.password, fullName: b.full_name, phone: b.phone, role: b.role,
    });
    ok(res, data);
  } catch (e) { next(e); }
});

router.post('/login', validateBody(z.object({ email: z.string().email(), password: z.string() })), async (req, res, next) => {
  try { ok(res, await Auth.login(req.body.email, req.body.password)); } catch (e) { next(e); }
});

router.post('/refresh', validateBody(z.object({ refresh_token: z.string() })), async (req, res, next) => {
  try { ok(res, await Auth.refresh(req.body.refresh_token)); } catch (e) { next(e); }
});

router.post('/logout', validateBody(z.object({ refresh_token: z.string() })), async (req, res, next) => {
  try { await Auth.logout(req.body.refresh_token); ok(res, { success: true }); } catch (e) { next(e); }
});

router.get('/me', requireAuth, async (req: AuthedRequest, res, next) => {
  try { ok(res, await Auth.getMe(req.user!.id)); } catch (e) { next(e); }
});

export default router;
