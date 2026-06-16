import Aedes from 'aedes';
import { createServer, Server as HttpServer } from 'http';
import { WebSocketServer } from 'ws';
import { getConfig } from '../utils/config';
import { createLogger } from '../utils/logger';
import { LocationUpdate } from '../types';

const logger = createLogger('MQTT');

let aedes: Aedes;
let httpServer: HttpServer;
let wsServer: WebSocketServer;
let locationUpdateCallback: ((update: LocationUpdate) => void) | null = null;

export const initMQTT = async (): Promise<void> => {
  const config = getConfig();

  aedes = new Aedes({
    persistence: {
      open: () => ({
        put: async () => {},
        del: async () => {},
        get: async () => null,
        createStream: () => ({ on: () => {}, once: () => {}, destroy: () => {} }),
        subscribe: async () => {},
        unsubscribe: async () => {},
       在线: 0,
      }),
    },
  });

  httpServer = createServer();
  wsServer = new WebSocketServer({ server: httpServer });

  aedes.on('client', (client) => {
    logger.info(`MQTT client connected: ${client.id}`);
  });

  aedes.on('clientDisconnect', (client) => {
    logger.info(`MQTT client disconnected: ${client.id}`);
  });

  aedes.on('subscribe', (subscriptions, client) => {
    logger.debug(`Client ${client.id} subscribed to: ${subscriptions.map(s => s.topic).join(', ')}`);
  });

  aedes.on('publish', (packet, client) => {
    if (client) {
      logger.debug(`Message from ${client.id} on ${packet.topic}`);
    }
  });

  wsServer.on('connection', (ws, req) => {
    const clientId = req.headers['sec-websocket-protocol'] || `ws-${Date.now()}`;
    aedes.handle(new WebSocketStreamWrapper(ws, clientId as string));
  });

  await new Promise<void>((resolve, reject) => {
    httpServer.listen(config.mqtt.wsPort, () => {
      logger.info(`MQTT over WebSocket listening on port ${config.mqtt.wsPort}`);
      resolve();
    });
    httpServer.on('error', reject);
  });

  if (config.mqtt.username && config.mqtt.password) {
    aedes.authenticate = (client, username, password, callback) => {
      if (username === config.mqtt.username && password?.toString() === config.mqtt.password) {
        callback(null, true);
      } else {
        callback(new Error('Authentication failed'), false);
      }
    };
  }

  logger.info(`MQTT broker initialized (TCP port: ${config.mqtt.port}, WS port: ${config.mqtt.wsPort})`);
};

export const onLocationUpdate = (callback: (update: LocationUpdate) => void): void => {
  locationUpdateCallback = callback;
};

export const subscribeToTopic = async (topic: string, callback: (message: any) => void): Promise<void> => {
  aedes.subscribe(topic, (packet, cb) => {
    try {
      const message = JSON.parse(packet.payload.toString());
      callback(message);
    } catch (e) {
      callback(packet.payload.toString());
    }
    cb();
  });
};

export const publishToTopic = async (topic: string, message: any): Promise<void> => {
  aedes.publish({
    topic,
    payload: Buffer.from(JSON.stringify(message)),
    qos: 1,
    retain: false,
  });
};

export const publishDriverLocation = async (driverId: string, location: LocationUpdate): Promise<void> => {
  await publishToTopic(`driver/location/${driverId}`, location);
  
  if (locationUpdateCallback) {
    locationUpdateCallback(location);
  }
};

export const broadcastToBooking = async (bookingId: string, event: string, data: any): Promise<void> => {
  await publishToTopic(`booking/${bookingId}`, { event, data, timestamp: Date.now() });
};

export const closeMQTT = async (): Promise<void> => {
  return new Promise((resolve) => {
    if (wsServer) {
      wsServer.close();
    }
    if (httpServer) {
      httpServer.close(() => {
        if (aedes) {
          aedes.close();
        }
        logger.info('MQTT broker closed');
        resolve();
      });
    } else {
      resolve();
    }
  });
};

class WebSocketStreamWrapper {
  public client: any;
  
  constructor(ws: any, clientId: string) {
    this.client = { id: clientId, conn: ws };
    
    ws.on('message', (data: Buffer) => {
      try {
        const packet = JSON.parse(data.toString());
        this.handlePacket(packet);
      } catch (e) {
        logger.error('Failed to parse MQTT over WS packet', { error: e });
      }
    });

    ws.on('close', () => {
      aedes.emit('clientDisconnect', this.client);
    });
  }

  private handlePacket(packet: any): void {
    switch (packet.type) {
      case 'CONNECT':
        this.handleConnect(packet);
        break;
      case 'PUBLISH':
        this.handlePublish(packet);
        break;
      case 'SUBSCRIBE':
        this.handleSubscribe(packet);
        break;
      case 'UNSUBSCRIBE':
        this.handleUnsubscribe(packet);
        break;
      case 'PINGREQ':
        this.sendPacket({ type: 'PINGRESP' });
        break;
    }
  }

  private handleConnect(packet: any): void {
    aedes.emit('client', this.client);
    this.sendPacket({ type: 'CONNACK', returnCode: 0 });
  }

  private handlePublish(packet: any): void {
    aedes.publish({
      topic: packet.topic,
      payload: Buffer.from(packet.payload),
      qos: packet.qos || 0,
      retain: packet.retain || false,
    }, this.client);
    
    if (packet.qos > 0) {
      this.sendPacket({ type: 'PUBACK', packetId: packet.packetId });
    }
  }

  private handleSubscribe(packet: any): void {
    const subscriptions = packet.subscriptions.map((s: any) => ({
      topic: s.topic,
      qos: s.qos || 0,
    }));
    
    aedes.emit('subscribe', subscriptions, this.client);
    
    this.sendPacket({
      type: 'SUBACK',
      packetId: packet.packetId,
      granted: subscriptions.map((s: any) => s.qos),
    });
  }

  private handleUnsubscribe(packet: any): void {
    aedes.emit('unsubscribe', packet.unsubscriptions, this.client);
    this.sendPacket({ type: 'UNSUBACK', packetId: packet.packetId });
  }

  private sendPacket(packet: any): void {
    if (this.client.conn.readyState === 1) {
      this.client.conn.send(JSON.stringify(packet));
    }
  }
}
