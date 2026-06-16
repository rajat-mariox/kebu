export interface Config {
  port: number;
  nodeEnv: string;
  redis: {
    host: string;
    port: number;
    password: string;
  };
  mqtt: {
    port: number;
    wsPort: number;
    username: string;
    password: string;
  };
  websocket: {
    heartbeatInterval: number;
    maxPayloadSize: number;
  };
  firebase: {
    projectId: string;
    privateKey: string;
    clientEmail: string;
  };
  backendApi: {
    url: string;
    secret: string;
  };
  logLevel: string;
}

export interface ClientInfo {
  id: string;
  type: 'user' | 'driver' | 'admin';
  userId?: string;
  bookingId?: string;
  connectedAt: number;
  lastActivity: number;
}

export interface LocationUpdate {
  driverId: string;
  bookingId?: string;
  latitude: number;
  longitude: number;
  heading?: number;
  speed?: number;
  timestamp: number;
}

export interface ChatMessage {
  id: string;
  bookingId: string;
  senderId: string;
  senderType: 'user' | 'driver';
  receiverId: string;
  message: string;
  type: 'text' | 'image' | 'location';
  attachments?: string[];
  timestamp: number;
  read: boolean;
}

export interface NotificationPayload {
  token?: string;
  topic?: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  android?: {
    priority?: 'high' | 'normal';
    channelId?: string;
    sound?: string;
  };
  ios?: {
    sound?: string;
    badge?: number;
  };
}

export interface RideRequest {
  bookingId: string;
  userId: string;
  pickup: {
    latitude: number;
    longitude: number;
    address: string;
  };
  drop: {
    latitude: number;
    longitude: number;
    address: string;
  };
  fare: number;
  distance: number;
  vehicleType?: string;
}

export interface SocketEvents {
  // Client to Server
  'join-room': { room: string; token?: string };
  'leave-room': { room: string };
  'location-update': LocationUpdate;
  'send-message': Omit<ChatMessage, 'id' | 'timestamp'>;
  'mark-read': { messageIds: string[] };
  'subscribe-booking': { bookingId: string };
  'unsubscribe-booking': { bookingId: string };
  
  // Server to Client
  'ride-request': RideRequest;
  'ride-accepted': { bookingId: string; driver: any };
  'ride-rejected': { bookingId: string };
  'driver-location': LocationUpdate;
  'driver-arrived': { bookingId: string };
  'ride-started': { bookingId: string };
  'ride-completed': { bookingId: string; fare: number };
  'ride-cancelled': { bookingId: string; reason?: string };
  'new-message': ChatMessage;
  'message-read': { messageIds: string[] };
  'typing': { senderId: string; bookingId: string; isTyping: boolean };
  'sos-alert': { bookingId: string; location: { lat: number; lng: number } };
  'notification': { title: string; body: string; data?: Record<string, string> };
  'error': { code: string; message: string };
}

export interface MqttTopics {
  'driver/location/+': LocationUpdate;
  'driver/status/+': { driverId: string; status: string };
  'booking/updates/+': any;
  'chat/+': ChatMessage;
  'notifications/+': NotificationPayload;
}
