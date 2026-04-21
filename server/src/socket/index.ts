import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import { verify } from '../utils/jwt.js';

let io: Server | null = null;

export function initSocket(httpServer: HttpServer): Server {
  io = new Server(httpServer, { cors: { origin: '*' } });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token || typeof token !== 'string') return next(new Error('Missing token'));
    try {
      const p = verify(token);
      (socket as any).userId = p.sub;
      (socket as any).role = p.role;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const userId = (socket as any).userId;
    const role = (socket as any).role;
    socket.join(`user:${userId}`);
    if (role === 'rider') socket.join(`rider:${userId}`);
    if (role === 'driver') socket.join(`driver:${userId}`);
    if (role === 'admin') socket.join('admin');

    socket.on('ride:join', (rideId: string) => {
      if (rideId) socket.join(`ride:${rideId}`);
    });
    socket.on('ride:leave', (rideId: string) => {
      if (rideId) socket.leave(`ride:${rideId}`);
    });
  });

  return io;
}

export function getIO(): Server {
  if (!io) throw new Error('Socket.IO not initialized');
  return io;
}
