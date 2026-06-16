import dotenv from "dotenv";
import { isProduction } from "../utils/env";

dotenv.config({ quiet: true } as any);

const required = (key: string): string => {
  const value = process.env[key];
  if (!value) {
    if (isProduction) {
      throw new Error(`Environment variable ${key} is missing`);
    }
    console.warn(`⚠️ Environment variable ${key} is missing`);
  }
  return value || "";
};

const optional = (key: string, defaultValue: string = ""): string => {
  return process.env[key] || defaultValue;
};

const config = {
  env: process.env.NODE_ENV || "development",

  server: {
    port: Number(process.env.PORT) || 4000,
  },

  database: {
    url: required("DB_URL"),
  },

  auth: {
    jwtSecret: required("JWTSECRET"),
    jwtExpiresIn: "30d",
    masterOtp: process.env.MASTER_OTP || 123456,
  },

  redis: {
    url: required("REDIS_URL"),
  },

  aws: {
    bucket: required("BUCKET"),
    region: required("REGION"),
    accessKeyId: required("ACCESSKEY"),
    secretAccessKey: required("SECRETACCESSKEY"),
  },

  google: {
    mapsApiKey: optional("GOOGLE_MAPS_API_KEY"),
  },

  razorpay: {
    keyId: optional("RAZORPAY_KEY_ID"),
    keySecret: optional("RAZORPAY_KEY_SECRET"),
  },

  firebase: {
    projectId: optional("FIREBASE_PROJECT_ID"),
    privateKey: optional("FIREBASE_PRIVATE_KEY"),
    clientEmail: optional("FIREBASE_CLIENT_EMAIL"),
  },

  mqtt: {
    host: optional("MQTT_HOST", "x891df71.ala.asia-southeast1.emqxsl.com"),
    port: Number(process.env.MQTT_PORT) || 8883,
    wsPort: Number(process.env.MQTT_WS_PORT) || 8084,
    username: optional("MQTT_USERNAME"),
    password: optional("MQTT_PASSWORD"),
    useTls: process.env.MQTT_USE_TLS === "true",
  },

  sms: {
    apiKey: optional("SMS_API_KEY"),
    senderId: optional("SMS_SENDER_ID", "KEBUON"),
  },
};

export default config;
