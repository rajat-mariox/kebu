# KEBU Realtime Service

Real-time microservice for KEBU ride-hailing platform.

## Features

- **MQTT Broker** - Efficient location tracking for drivers
- **WebSocket Server** - Real-time chat and ride updates
- **Push Notifications** - Firebase Cloud Messaging integration
- **Chat Service** - Persistent messaging between users and drivers
- **Redis Integration** - Pub/sub for horizontal scaling

## Quick Start

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Run in development
npm run dev

# Build for production
npm run build

# Run in production
npm start
```

## Docker

```bash
docker-compose up -d
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /health | Health check |
| GET | /stats | Connection stats |
| POST | /notifications/send | Send push notification |
| POST | /chat/message | Send chat message |
| GET | /chat/:bookingId | Get chat history |

See [INTEGRATION.md](INTEGRATION.md) for full documentation.
