# KEBU Realtime Service - Integration Guide

## Overview

The KEBU Realtime Service is a standalone microservice that handles:
- **Real-time location tracking** (via MQTT)
- **WebSocket communication** (chat, live updates)
- **Push notifications** (via Firebase Cloud Messaging)
- **Chat messaging** (persistent, real-time)

## Architecture

```
┌─────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  Customer   │     │   Realtime Service    │     │    Backend      │
│    App      │────▶│  - MQTT Broker       │◀────│    API          │
│             │     │  - WebSocket Server   │     │                 │
│             │◀────│  - REST API           │────▶│  (Node.js)      │
└─────────────┘     │  - FCM Integration   │     └─────────────────┘
                    └──────────────────────┘
                           ▲     ▲     ▲
                           │     │     │
                    ┌──────┴─────┴─────┴──────┐
                    │                         │
              ┌─────▼─────┐           ┌──────▼──────┐
              │  Driver   │           │   Redis     │
              │   App     │           │  (Pub/Sub)  │
              └───────────┘           └─────────────┘
```

## Quick Start

### 1. Run with Docker

```bash
cd realtime-service
cp .env.example .env
docker-compose up -d
```

### 2. Run Locally

```bash
cd realtime-service
npm install
npm run dev
```

## REST API Endpoints

### Health & Stats
- `GET /health` - Service health check
- `GET /stats` - Connected clients statistics

### Push Notifications
- `POST /notifications/send` - Send to single device
- `POST /notifications/multicast` - Send to multiple devices
- `POST /notifications/subscribe` - Subscribe to topic
- `POST /notifications/unsubscribe` - Unsubscribe from topic
- `POST /notifications/ride/:type` - Send ride-specific notifications

### Chat
- `POST /chat/message` - Send a chat message
- `GET /chat/:bookingId` - Get chat history
- `POST /chat/:bookingId/read` - Mark messages as read
- `DELETE /chat/:bookingId` - Clear chat history

## WebSocket Events

### Client → Server

```javascript
// Authenticate
socket.emit('authenticate', { userId: 'user123', type: 'user' });

// Subscribe to booking updates
socket.emit('subscribe-booking', { bookingId: 'booking123', userId: 'user123' });

// Send location update (driver)
socket.emit('location-update', {
  driverId: 'driver123',
  bookingId: 'booking123',
  latitude: 12.9716,
  longitude: 77.5946,
  heading: 45,
  speed: 30
});

// Send chat message
socket.emit('send-message', {
  bookingId: 'booking123',
  senderId: 'user123',
  senderType: 'user',
  receiverId: 'driver123',
  message: 'I am waiting at the pickup',
  type: 'text'
});

// SOS Alert
socket.emit('sos-alert', {
  bookingId: 'booking123',
  location: { lat: 12.9716, lng: 77.5946 }
});
```

### Server → Client

```javascript
// Ride request received (driver)
socket.on('ride-request', (data) => {
  console.log('New ride request:', data);
});

// Driver location update (customer)
socket.on('driver-location', (data) => {
  console.log('Driver location:', data.latitude, data.longitude);
});

// New chat message
socket.on('new-message', (message) => {
  console.log('New message:', message);
});

// SOS Alert
socket.on('sos-alert', (data) => {
  console.log('SOS Alert!', data);
});
```

## MQTT Topics

### Publish Location Updates
```javascript
// Topic: driver/location/{driverId}
mqttClient.publish(`driver/location/${driverId}`, JSON.stringify({
  latitude: 12.9716,
  longitude: 77.5946,
  heading: 45,
  speed: 30,
  timestamp: Date.now()
}));
```

### Subscribe to Location Updates
```javascript
mqttClient.subscribe('driver/location/+', (topic, message) => {
  const data = JSON.parse(message);
  console.log(`Driver ${data.driverId} location:`, data);
});
```

## Integration with Backend

### 1. Update Backend Environment
```env
REALTIME_SERVICE_URL=http://localhost:3001
REALTIME_SERVICE_SECRET=your-secret
```

### 2. Call Realtime Service from Backend

```typescript
// Example: Send ride request notification
const response = await fetch('http://localhost:3001/notifications/ride/request', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    driverTokens: ['fcm_token_1', 'fcm_token_2'],
    pickup: '123 Main St',
    fare: 150,
    distance: 5.2
  })
});

// Example: Send chat message
const chatResponse = await fetch('http://localhost:3001/chat/message', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    bookingId: 'booking123',
    senderId: 'user123',
    senderType: 'user',
    receiverId: 'driver123',
    message: 'Hello!',
    type: 'text'
  })
});
```

### 3. Replace Socket.io in Backend

In your backend's socket handler, emit events to this service via REST API:

```typescript
// backend/src/socket/index.ts

// Instead of directly emitting, call realtime service
await fetch('http://localhost:3001/notifications/ride/accepted', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    token: userFcmToken,
    driverName: 'John',
    vehicleNumber: 'KA01AB1234',
    eta: 5
  })
});
```

## Flutter App Integration

### pubspec.yaml
```yaml
dependencies:
  socket_io_client: ^2.0.3+1
  mqtt_client: ^10.2.0
```

### Socket.io Connection
```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  
  IO.Socket? _socket;

  void connect(String userId, String type) {
    _socket = IO.io('http://your-realtime-service:3001', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      _socket!.emit('authenticate', {'userId': userId, 'type': type});
    });

    _socket!.on('ride-request', (data) {
      // Handle new ride request
    });

    _socket!.on('driver-location', (data) {
      // Update driver marker on map
    });
  }

  void sendLocation(double lat, double lng, String driverId, String? bookingId) {
    _socket?.emit('location-update', {
      'driverId': driverId,
      'bookingId': bookingId,
      'latitude': lat,
      'longitude': lng,
    });
  }

  void sendMessage(String bookingId, String senderId, String senderType, 
                   String receiverId, String message) {
    _socket?.emit('send-message', {
      'bookingId': bookingId,
      'senderId': senderId,
      'senderType': senderType,
      'receiverId': receiverId,
      'message': message,
      'type': 'text',
    });
  }

  void triggerSOS(String bookingId, double lat, double lng) {
    _socket?.emit('sos-alert', {
      'bookingId': bookingId,
      'location': {'lat': lat, 'lng': lng},
    });
  }
}
```

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | REST API port | 3001 |
| `NODE_ENV` | Environment | development |
| `REDIS_HOST` | Redis host | localhost |
| `REDIS_PORT` | Redis port | 6379 |
| `MQTT_WS_PORT` | MQTT WebSocket port | 8080 |
| `FIREBASE_*` | Firebase credentials | Optional |
| `BACKEND_API_URL` | Main backend URL | http://localhost:3000 |

## Scaling

For production scaling:
1. Run multiple instances behind a load balancer
2. Use Redis pub/sub to sync between instances
3. Consider using EMQX cluster for MQTT
4. Use Redis cluster for high availability
