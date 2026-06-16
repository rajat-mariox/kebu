import mqtt, { MqttClient } from "mqtt";
import config from "../config";

let client: MqttClient | null = null;

/**
 * Connect to EMQX Cloud MQTT broker over TLS (mqtts://).
 * The backend publishes messages; driver/user apps subscribe via their own connections.
 *
 * EMQX Cloud connection guide:
 *   https://docs.emqx.com/en/cloud/latest/connect_to_deployments/nodejs_sdk.html
 *
 * Topics:
 *   driver/rides/{driverId}      — new ride request bell for driver
 *   driver/location/{driverId}   — driver location updates
 *   booking/{bookingId}          — ride status changes
 */
export const initMQTT = async (): Promise<void> => {
  const host = config.mqtt.host;
  const port = config.mqtt.port;
  const useTls = config.mqtt.useTls;

  if (!host) {
    console.warn("⚠️ MQTT_HOST not set — MQTT disabled");
    return;
  }

  const protocol = useTls ? "mqtts" : "mqtt";
  const url = `${protocol}://${host}:${port}`;
  const clientId = `kebu_backend_${Math.random().toString(16).substring(2, 8)}`;

  console.log(`📡 MQTT connecting to ${url} as ${clientId}...`);

  return new Promise((resolve) => {
    client = mqtt.connect(url, {
      clientId,
      username: config.mqtt.username,
      password: config.mqtt.password,
      clean: true,
      connectTimeout: 10000,
      reconnectPeriod: 5000,
    });

    client.on("connect", () => {
      console.log(`📡 MQTT connected to ${host}:${port}`);
      resolve();
    });

    client.on("reconnect", () => {
      console.log("MQTT reconnecting...");
    });

    client.on("error", (err) => {
      console.error("MQTT error:", err.message);
    });

    client.on("close", () => {
      console.log("MQTT connection closed");
    });

    // Don't block server startup if MQTT fails
    setTimeout(() => {
      if (!client?.connected) {
        console.warn("⚠️ MQTT connection timed out — server continues without MQTT");
        resolve();
      }
    }, 10000);
  });
};

/**
 * Publish a JSON message to an MQTT topic (QoS 1)
 */
export const publishToTopic = (topic: string, payload: any): void => {
  if (!client?.connected) {
    return;
  }

  client.publish(topic, JSON.stringify(payload), { qos: 1 }, (err) => {
    if (err) {
      console.error(`MQTT publish error [${topic}]:`, err.message);
    }
  });
};

/**
 * Publish a new ride request bell to a driver.
 * Driver app subscribes to: driver/rides/{driverId}
 */
export const publishRideRequest = (
  driverId: string,
  rideData: {
    bookingId: string;
    pickup: any;
    drop: any;
    fare: number;
    distanceKm: number;
    durationMin: number;
    vehicleType?: string;
  }
): void => {
  publishToTopic(`driver/rides/${driverId}`, {
    type: "new_ride_request",
    ...rideData,
    timestamp: Date.now(),
  });
};

/**
 * Publish driver location update.
 * User app subscribes to: driver/location/{driverId}
 */
export const publishDriverLocation = (
  driverId: string,
  location: {
    latitude: number;
    longitude: number;
    heading?: number;
    speed?: number;
    bookingId?: string;
  }
): void => {
  publishToTopic(`driver/location/${driverId}`, {
    ...location,
    timestamp: Date.now(),
  });
};

/**
 * Publish ride status change.
 * Both apps subscribe to: booking/{bookingId}
 */
export const publishBookingUpdate = (
  bookingId: string,
  event: string,
  data: any
): void => {
  publishToTopic(`booking/${bookingId}`, {
    event,
    data,
    timestamp: Date.now(),
  });
};

/**
 * Graceful disconnect
 */
export const closeMQTT = async (): Promise<void> => {
  return new Promise((resolve) => {
    if (client) {
      client.end(false, {}, () => {
        console.log("MQTT disconnected");
        resolve();
      });
    } else {
      resolve();
    }
  });
};

/**
 * Returns EMQX connection info for mobile apps.
 * Apps connect via WSS: wss://{host}:{wsPort}/mqtt
 */
export const getMQTTConnectionInfo = () => ({
  host: config.mqtt.host,
  port: config.mqtt.port,
  wsPort: config.mqtt.wsPort,
  useTls: config.mqtt.useTls,
  // WSS URL for Flutter/mobile apps
  wssUrl: `wss://${config.mqtt.host}:${config.mqtt.wsPort}/mqtt`,
  // MQTTS URL for native MQTT clients
  mqttsUrl: `mqtts://${config.mqtt.host}:${config.mqtt.port}`,
});
