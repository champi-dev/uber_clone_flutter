import { prisma } from '../config/database.js';
import { getIO } from '../socket/index.js';

export async function push(userId: string, type: string, title: string, body: string, data?: unknown) {
  const n = await prisma.notification.create({
    data: { userId, type, title, body, dataJson: data ? JSON.stringify(data) : null },
  });
  try {
    getIO().to(`user:${userId}`).emit('notification:new', {
      id: n.id, type: n.type, title: n.title, body: n.body, data, created_at: n.createdAt,
    });
  } catch { /* socket not ready */ }
  return n;
}
