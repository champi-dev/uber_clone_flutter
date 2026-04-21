import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../config/database.js';
import { requireAuth, AuthedRequest } from '../middleware/auth.js';
import { validateBody } from '../middleware/validate.js';
import { ok } from '../utils/response.js';
import { forbidden, notFound } from '../utils/errors.js';

const router = Router();

router.get('/', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const rows = await prisma.savedPlace.findMany({
      where: { userId: req.user!.id },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    });
    ok(res, rows);
  } catch (e) { next(e); }
});

const createSchema = z.object({
  label: z.string().min(1).max(50),
  address: z.string().min(1),
  lat: z.number(), lng: z.number(),
  icon: z.string().optional(),
  sort_order: z.number().optional(),
});

router.post('/', requireAuth, validateBody(createSchema), async (req: AuthedRequest, res, next) => {
  try {
    const b = req.body;
    const row = await prisma.savedPlace.create({
      data: {
        userId: req.user!.id,
        label: b.label, address: b.address, lat: b.lat, lng: b.lng,
        icon: b.icon ?? 'home', sortOrder: b.sort_order ?? 0,
      },
    });
    ok(res, row);
  } catch (e) { next(e); }
});

router.put('/:id', requireAuth, validateBody(createSchema.partial()), async (req: AuthedRequest, res, next) => {
  try {
    const existing = await prisma.savedPlace.findUnique({ where: { id: req.params.id } });
    if (!existing) throw notFound();
    if (existing.userId !== req.user!.id) throw forbidden();
    const b = req.body;
    const row = await prisma.savedPlace.update({
      where: { id: req.params.id },
      data: {
        ...(b.label !== undefined ? { label: b.label } : {}),
        ...(b.address !== undefined ? { address: b.address } : {}),
        ...(b.lat !== undefined ? { lat: b.lat } : {}),
        ...(b.lng !== undefined ? { lng: b.lng } : {}),
        ...(b.icon !== undefined ? { icon: b.icon } : {}),
        ...(b.sort_order !== undefined ? { sortOrder: b.sort_order } : {}),
      },
    });
    ok(res, row);
  } catch (e) { next(e); }
});

router.delete('/:id', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const existing = await prisma.savedPlace.findUnique({ where: { id: req.params.id } });
    if (!existing) throw notFound();
    if (existing.userId !== req.user!.id) throw forbidden();
    await prisma.savedPlace.delete({ where: { id: req.params.id } });
    ok(res, { deleted: true });
  } catch (e) { next(e); }
});

export default router;
