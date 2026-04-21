import { Request, Response, NextFunction } from 'express';
import { verify } from '../utils/jwt.js';
import { unauthorized } from '../utils/errors.js';

export interface AuthedRequest extends Request {
  user?: { id: string; role: string };
}

export function requireAuth(req: AuthedRequest, _res: Response, next: NextFunction) {
  const h = req.header('authorization');
  if (!h?.startsWith('Bearer ')) return next(unauthorized('Missing token'));
  try {
    const payload = verify(h.slice(7));
    req.user = { id: payload.sub, role: payload.role };
    next();
  } catch {
    next(unauthorized('Invalid token'));
  }
}

export function requireRole(...roles: string[]) {
  return (req: AuthedRequest, _res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) return next(unauthorized('Forbidden'));
    next();
  };
}
