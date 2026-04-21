import { Router } from 'express';
import { prisma } from '../config/database.js';
import { requireAuth, AuthedRequest } from '../middleware/auth.js';
import { ok } from '../utils/response.js';
import { forbidden, notFound } from '../utils/errors.js';

const router = Router();

router.get('/', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const page = Math.max(1, parseInt((req.query.page as string) || '1', 10));
    const limit = Math.min(50, parseInt((req.query.limit as string) || '20', 10));
    const unreadOnly = req.query.is_read === 'false';
    const where: any = { userId: req.user!.id, ...(unreadOnly ? { isRead: false } : {}) };
    const [rows, total] = await Promise.all([
      prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' }, skip: (page - 1) * limit, take: limit }),
      prisma.notification.count({ where }),
    ]);
    ok(res, rows, { page, limit, total });
  } catch (e) { next(e); }
});

router.patch('/:id/read', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    const n = await prisma.notification.findUnique({ where: { id: req.params.id } });
    if (!n) throw notFound();
    if (n.userId !== req.user!.id) throw forbidden();
    const updated = await prisma.notification.update({ where: { id: req.params.id }, data: { isRead: true } });
    ok(res, updated);
  } catch (e) { next(e); }
});

router.patch('/read-all', requireAuth, async (req: AuthedRequest, res, next) => {
  try {
    await prisma.notification.updateMany({ where: { userId: req.user!.id, isRead: false }, data: { isRead: true } });
    ok(res, { success: true });
  } catch (e) { next(e); }
});

export default router;
