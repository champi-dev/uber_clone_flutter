import { ErrorRequestHandler } from 'express';
import { AppError } from '../utils/errors.js';

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof AppError) {
    return res.status(err.status).json({ success: false, error: err.message });
  }
  console.error(err);
  return res.status(500).json({ success: false, error: 'Internal server error' });
};
