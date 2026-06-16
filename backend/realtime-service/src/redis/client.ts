import Redis from 'ioredis';
import { getConfig } from '../utils/config';
import { createLogger } from '../utils/logger';

const logger = createLogger('Redis');

let redisClient: Redis | null = null;
let redisPubClient: Redis | null = null;
let redisSubClient: Redis | null = null;

export const initRedis = async (): Promise<void> => {
  const config = getConfig();
  
  const options: any = {
    host: config.redis.host,
    port: config.redis.port,
    retryStrategy: (times: number) => {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
    maxRetriesPerRequest: 3,
  };

  if (config.redis.password) {
    options.password = config.redis.password;
  }

  redisClient = new Redis(options);
  redisPubClient = new Redis(options);
  redisSubClient = new Redis(options);

  redisClient.on('connect', () => {
    logger.info('Redis client connected');
  });

  redisClient.on('error', (err) => {
    logger.error('Redis client error', { error: err.message });
  });

  await new Promise<void>((resolve, reject) => {
    redisClient!.once('ready', () => resolve());
    redisClient!.once('error', (err) => reject(err));
  });

  logger.info('Redis initialized successfully');
};

export const getRedisClient = (): Redis => {
  if (!redisClient) {
    throw new Error('Redis not initialized. Call initRedis() first.');
  }
  return redisClient;
};

export const getRedisPubClient = (): Redis => {
  if (!redisPubClient) {
    throw new Error('Redis pub client not initialized.');
  }
  return redisPubClient;
};

export const getRedisSubClient = (): Redis => {
  if (!redisSubClient) {
    throw new Error('Redis sub client not initialized.');
  }
  return redisSubClient;
};

export const publishMessage = async (channel: string, message: any): Promise<void> => {
  const client = getRedisPubClient();
  await client.publish(channel, JSON.stringify(message));
};

export const subscribeToChannel = async (
  channel: string,
  callback: (message: string) => void
): Promise<void> => {
  const client = getRedisSubClient();
  await client.subscribe(channel);
  client.on('message', (ch, msg) => {
    if (ch === channel) {
      callback(msg);
    }
  });
};

export const setWithExpiry = async (
  key: string,
  value: any,
  expirySeconds: number
): Promise<void> => {
  const client = getRedisClient();
  await client.setex(key, expirySeconds, JSON.stringify(value));
};

export const get = async (key: string): Promise<any | null> => {
  const client = getRedisClient();
  const value = await client.get(key);
  return value ? JSON.parse(value) : null;
};

export const del = async (key: string): Promise<void> => {
  const client = getRedisClient();
  await client.del(key);
};

export const closeRedis = async (): Promise<void> => {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
  if (redisPubClient) {
    await redisPubClient.quit();
    redisPubClient = null;
  }
  if (redisSubClient) {
    await redisSubClient.quit();
    redisSubClient = null;
  }
  logger.info('Redis connections closed');
};
