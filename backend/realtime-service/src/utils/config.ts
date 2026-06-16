import dotenv from 'dotenv';
import type { Config } from '../types';

dotenv.config();

let config: Config | null = null;

export const loadConfig = (): Config => {
  if (config) return config;

  const required = (key: string, fallback?: string): string => {
    const value = process.env[key] || fallback;
    if (!value && process.env.NODE_ENV === 'production') {
      throw new Error(`Missing required environment variable: ${key}`);
    }
    return value || '';
  };

  const optional = (key: string, fallback?: string): string => {
    return process.env[key] || fallback || '';
  };

  const optionalNumber = (key: string, fallback: number): number => {
    const value = process.env[key];
    return value ? parseInt(value, 10) : fallback;
  };

  config = {
    port: optionalNumber('PORT', 3001),
    nodeEnv: optional('NODE_ENV', 'development'),
    redis: {
      host: optional('REDIS_HOST', 'localhost'),
      port: optionalNumber('REDIS_PORT', 6379),
      password: optional('REDIS_PASSWORD', ''),
    },
    mqtt: {
      port: optionalNumber('MQTT_PORT', 1883),
      wsPort: optionalNumber('MQTT_WS_PORT', 8080),
      username: optional('MQTT_USERNAME', ''),
      password: optional('MQTT_PASSWORD', ''),
    },
    websocket: {
      heartbeatInterval: optionalNumber('WS_HEARTBEAT_INTERVAL', 30000),
      maxPayloadSize: optionalNumber('WS_MAX_PAYLOAD_SIZE', 1048576),
    },
    firebase: {
      projectId: optional('FIREBASE_PROJECT_ID', ''),
      privateKey: optional('FIREBASE_PRIVATE_KEY', '').replace(/\\n/g, '\n'),
      clientEmail: optional('FIREBASE_CLIENT_EMAIL', ''),
    },
    backendApi: {
      url: optional('BACKEND_API_URL', 'http://localhost:3000'),
      secret: optional('BACKEND_API_SECRET', 'your-backend-secret-key'),
    },
    logLevel: optional('LOG_LEVEL', 'info'),
  };

  return config;
};

export const getConfig = (): Config => {
  if (!config) {
    return loadConfig();
  }
  return config;
};
