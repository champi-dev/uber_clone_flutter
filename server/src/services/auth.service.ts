import bcrypt from 'bcrypt';
import { prisma } from '../config/database.js';
import { signAccess, signRefresh, verify } from '../utils/jwt.js';
import { badRequest, unauthorized } from '../utils/errors.js';

export async function register(input: {
  email: string; password: string; fullName: string; phone: string; role?: string;
}) {
  const exists = await prisma.user.findUnique({ where: { email: input.email } });
  if (exists) throw badRequest('Email already registered');
  const passwordHash = await bcrypt.hash(input.password, 12);
  const user = await prisma.user.create({
    data: {
      email: input.email,
      passwordHash,
      fullName: input.fullName,
      phone: input.phone,
      role: input.role ?? 'rider',
    },
  });
  return tokenize(user);
}

export async function login(email: string, password: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !user.isActive) throw unauthorized('Incorrect email or password');
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) throw unauthorized('Incorrect email or password');
  return tokenize(user);
}

export async function refresh(refreshToken: string) {
  let payload;
  try { payload = verify(refreshToken); } catch { throw unauthorized('Invalid refresh token'); }
  const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
  if (!stored || stored.expiresAt < new Date()) throw unauthorized('Refresh token expired');
  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) throw unauthorized('User not found');
  return tokenize(user);
}

export async function logout(refreshToken: string) {
  await prisma.refreshToken.deleteMany({ where: { token: refreshToken } });
}

async function tokenize(user: { id: string; role: string; email: string; fullName: string }) {
  const access_token = signAccess({ sub: user.id, role: user.role });
  const refresh_token = signRefresh({ sub: user.id, role: user.role });
  await prisma.refreshToken.create({
    data: { token: refresh_token, userId: user.id, expiresAt: new Date(Date.now() + 7 * 24 * 3600 * 1000) },
  });
  return { access_token, refresh_token, user: sanitize(user) };
}

export function sanitize(u: any) {
  const { passwordHash, ...rest } = u;
  return rest;
}

export async function getMe(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { driverProfile: { include: { vehicles: true } } },
  });
  if (!user) throw unauthorized();
  return sanitize(user);
}
