import { createServer, Server as HttpServer } from 'http';
import { loadConfig, getConfig } from './utils/config';
import { createLogger } from './utils/logger';
import { initRedis, closeRedis } from './redis/client';
import { initMQTT, closeMQTT } from './mqtt/broker';
import { initWebSocket, closeWebSocket } from './websocket/server';
import { initAPI } from './api/rest';
import { initFirebase } from './services/notification.service';

const logger = createLogger('Main');

let server: HttpServer;

const start = async (): Promise<void> => {
  try {
    loadConfig();
    const config = getConfig();

    logger.info('Starting KEBU Realtime Service...');

    await initRedis();
    logger.info('Redis initialized');

    await initMQTT();
    logger.info('MQTT broker initialized');

    await initFirebase();
    logger.info('Firebase initialized');

    const app = initAPI();
    server = createServer(app);

    initWebSocket(server);
    logger.info('WebSocket server initialized');

    await new Promise<void>((resolve) => {
      server.listen(config.port, () => {
        logger.info(`KEBU Realtime Service running on port ${config.port}`);
        logger.info(`  - REST API: http://localhost:${config.port}`);
        logger.info(`  - WebSocket: ws://localhost:${config.port}`);
        logger.info(`  - MQTT WS: ws://localhost:${config.mqtt.wsPort}`);
        resolve();
      });
    });

    logger.info('All services started successfully');
  } catch (error) {
    logger.error('Failed to start service', { error });
    process.exit(1);
  }
};

const shutdown = async (signal: string): Promise<void> => {
  logger.info(`Received ${signal}. Shutting down gracefully...`);

  try {
    await closeWebSocket();
    await closeMQTT();
    await closeRedis();

    if (server) {
      await new Promise<void>((resolve) => {
        server.close(() => {
          logger.info('HTTP server closed');
          resolve();
        });
      });
    }

    logger.info('Graceful shutdown complete');
    process.exit(0);
  } catch (error) {
    logger.error('Error during shutdown', { error });
    process.exit(1);
  }
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', { error });
  shutdown('uncaughtException');
});

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection', { reason });
  shutdown('unhandledRejection');
});

start();
