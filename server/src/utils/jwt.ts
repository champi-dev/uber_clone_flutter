import jwt, { SignOptions } from 'jsonwebtoken';
import { env } from '../config/env.js';

export interface AccessPayload { sub: string; role: string; }

export function signAccess(payload: AccessPayload): string {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: env.JWT_ACCESS_EXPIRY } as SignOptions);
}
export function signRefresh(payload: AccessPayload): string {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: env.JWT_REFRESH_EXPIRY } as SignOptions);
}
export function verify(token: string): AccessPayload {
  return jwt.verify(token, env.JWT_SECRET) as AccessPayload;
}
