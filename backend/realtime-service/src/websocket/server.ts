import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { getConfig } from '../utils/config';
import { createLogger } from '../utils/logger';
import { publishMessage, getRedisClient } from '../redis/client';
import { ClientInfo, LocationUpdate, ChatMessage, RideRequest } from '../types';

const logger = createLogger('WebSocket');

let io: SocketIOServer;
let httpServer: HttpServer;
const connectedClients: Map<string, ClientInfo> = new Map();

export const initWebSocket = (server: HttpServer): void => {
  const config = getConfig();
  httpServer = server;

  io = new SocketIOServer(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
    pingInterval: config.websocket.heartbeatInterval,
    pingTimeout: config.websocket.heartbeatInterval / 2,
    maxPayload: config.websocket.maxPayloadSize,
  });

  io.on('connection', (socket: Socket) => {
    const clientInfo: ClientInfo = {
      id: socket.id,
      type: 'user',
      connectedAt: Date.now(),
      lastActivity: Date.now(),
    };
    connectedClients.set(socket.id, clientInfo);

    logger.info(`WebSocket client connected: ${socket.id}`);

    socket.on('authenticate', (data: { userId: string; type: 'user' | 'driver' | 'admin' }) => {
      clientInfo.userId = data.userId;
      clientInfo.type = data.type;
      socket.join(`${data.type}_${data.userId}`);
      logger.info(`Client ${socket.id} authenticated as ${data.type}:${data.userId}`);
      socket.emit('authenticated', { success: true });
    });

    socket.on('join-room', (data: { room: string; token?: string }) => {
      socket.join(data.room);
      logger.debug(`Client ${socket.id} joined room: ${data.room}`);
      socket.emit('room-joined', { room: data.room });
    });

    socket.on('leave-room', (data: { room: string }) => {
      socket.leave(data.room);
      logger.debug(`Client ${socket.id} left room: ${data.room}`);
    });

    socket.on('location-update', async (data: LocationUpdate) => {
      clientInfo.lastActivity = Date.now();
      const locationData: LocationUpdate = {
        driverId: data.driverId,
        bookingId: data.bookingId,
        latitude: data.latitude,
        longitude: data.longitude,
        heading: data.heading,
        speed: data.speed,
        timestamp: Date.now(),
      };

      await publishMessage(`location:${data.driverId}`, locationData);

      if (data.bookingId) {
        io.to(`user_room:${data.bookingId}`).emit('driver-location', locationData);
      }
    });

    socket.on('subscribe-booking', (data: { bookingId: string; userId: string }) => {
      socket.join(`booking:${data.bookingId}`);
      socket.join(`user_room:${data.bookingId}`);
      logger.debug(`Client subscribed to booking: ${data.bookingId}`);
    });

    socket.on('unsubscribe-booking', (data: { bookingId: string }) => {
      socket.leave(`booking:${data.bookingId}`);
      socket.leave(`user_room:${data.bookingId}`);
      logger.debug(`Client unsubscribed from booking: ${data.bookingId}`);
    });

    socket.on('send-message', async (data: Omit<ChatMessage, 'id' | 'timestamp' | 'read'>) => {
      const message: ChatMessage = {
        ...data,
        id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        timestamp: Date.now(),
        read: false,
      };

      await publishMessage(`chat:${data.bookingId}`, message);

      io.to(`booking:${data.bookingId}`).emit('new-message', message);

      const receiverRoom = data.senderType === 'user' 
        ? `driver_${data.receiverId}` 
        : `user_${data.receiverId}`;
      io.to(receiverRoom).emit('new-message', message);
    });

    socket.on('typing', (data: { bookingId: string; senderId: string; isTyping: boolean }) => {
      socket.to(`booking:${data.bookingId}`).emit('typing', {
        senderId: data.senderId,
        isTyping: data.isTyping,
      });
    });

    socket.on('mark-read', (data: { messageIds: string[] }) => {
      socket.emit('message-read', { messageIds: data.messageIds });
    });

    socket.on('sos-alert', async (data: { bookingId: string; location: { lat: number; lng: number } }) => {
      logger.warn(`SOS Alert received for booking: ${data.bookingId}`, data);
      
      io.to(`booking:${data.bookingId}`).emit('sos-alert', {
        bookingId: data.bookingId,
        location: data.location,
        timestamp: Date.now(),
      });

      io.to('admin_*').emit('sos-alert', {
        bookingId: data.bookingId,
        location: data.location,
        timestamp: Date.now(),
      });

      await publishMessage('sos-alerts', {
        bookingId: data.bookingId,
        location: data.location,
        timestamp: Date.now(),
      });
    });

    socket.on('disconnect', () => {
      connectedClients.delete(socket.id);
      logger.info(`WebSocket client disconnected: ${socket.id}`);
    });

    socket.on('error', (error) => {
      logger.error(`WebSocket error for ${socket.id}`, { error: error.message });
    });
  });

  logger.info('WebSocket server initialized');
};

export const emitToUser = (userId: string, event: string, data: any): void => {
  io.to(`user_${userId}`).emit(event, data);
};

export const emitToDriver = (driverId: string, event: string, data: any): void => {
  io.to(`driver_${driverId}`).emit(event, data);
};

export const emitToRoom = (room: string, event: string, data: any): void => {
  io.to(room).emit(event, data);
};

export const emitToBooking = (bookingId: string, event: string, data: any): void => {
  io.to(`booking:${bookingId}`).emit(event, data);
};

export const emitRideRequest = async (driverIds: string[], rideRequest: RideRequest): Promise<void> => {
  for (const driverId of driverIds) {
    io.to(`driver_${driverId}`).emit('ride-request', rideRequest);
  }
  logger.info(`Ride request emitted to ${driverIds.length} drivers`, { bookingId: rideRequest.bookingId });
};

export const emitRideAccepted = (userId: string, driverId: string, bookingId: string, driverDetails: any): void => {
  io.to(`user_${userId}`).emit('ride-accepted', {
    bookingId,
    driver: driverDetails,
    timestamp: Date.now(),
  });
  logger.info(`Ride accepted notification sent to user: ${userId}`);
};

export const emitDriverArrived = (userId: string, bookingId: string): void => {
  io.to(`user_${userId}`).emit('driver-arrived', { bookingId, timestamp: Date.now() });
};

export const emitRideStarted = (userId: string, bookingId: string): void => {
  io.to(`user_${userId}`).emit('ride-started', { bookingId, timestamp: Date.now() });
};

export const emitRideCompleted = (userId: string, bookingId: string, fare: number): void => {
  io.to(`user_${userId}`).emit('ride-completed', { bookingId, fare, timestamp: Date.now() });
};

export const emitRideCancelled = (userId: string, driverId: string, bookingId: string, reason?: string): void => {
  io.to(`user_${userId}`).emit('ride-cancelled', { bookingId, reason, timestamp: Date.now() });
  io.to(`driver_${driverId}`).emit('ride-cancelled', { bookingId, reason, timestamp: Date.now() });
};

export const broadcastToDrivers = (event: string, data: any): void => {
  io.emit(event, data);
};

export const getConnectedClients = (): ClientInfo[] => {
  return Array.from(connectedClients.values());
};

export const getClientCount = (): number => {
  return connectedClients.size;
};

export const closeWebSocket = async (): Promise<void> => {
  return new Promise((resolve) => {
    if (io) {
      io.close(() => {
        logger.info('WebSocket server closed');
        resolve();
      });
    } else {
      resolve();
    }
  });
};
