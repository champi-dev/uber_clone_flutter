import { Response } from 'express';

export function ok(res: Response, data: unknown, pagination?: { page: number; limit: number; total: number }) {
  return res.json({ success: true, data, ...(pagination ? { pagination } : {}) });
}
export function fail(res: Response, status: number, error: string) {
  return res.status(status).json({ success: false, error });
}
