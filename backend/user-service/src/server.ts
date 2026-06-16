import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import { createServer } from "http";

import routes from "./routes";
import connectDB from "./models";
import config from "./config";
import { initializeSocket } from "./socket";
import { initMQTT, closeMQTT } from "./mqtt/broker";

const app = express();
const httpServer = createServer(app);

/**
 * Initialize Socket.io (async — connects Redis adapter for cross-instance fan-out)
 */
initializeSocket(httpServer)
  .then((io) => {
    app.set("io", io);
  })
  .catch((err) => {
    console.error("⚠️ Socket.io initialization failed:", err.message);
  });

/**
 * Connect MongoDB
 */
connectDB();

/**
 * Initialize MQTT broker (embedded Aedes)
 */
initMQTT().then(() => {
  console.log("🔌 MQTT broker ready");
}).catch((err) => {
  console.error("⚠️ MQTT broker failed to start:", err.message);
});

/**
 * Body parser
 */
app.use(express.json());

/**
 * Log all incoming requests
 */
app.use((req: Request, _res: Response, next: NextFunction) => {
  console.log(`Incoming Request: ${req.method} ${req.originalUrl}`);
  next();
});

/**
 * CORS
 */
const corsOrigins = process.env.CORS_ORIGINS?.split(",").map((origin) =>
  origin.trim(),
) || [
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "http://localhost:4173",
  "http://127.0.0.1:4173",
  "https://admin.kebuone.com"
];

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || corsOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error(`CORS blocked for origin: ${origin}`));
    },
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "x-user-data"],
    credentials: true,
  }),
);

app.options(/.*/, cors());

/**
 * Routes
 */
app.use("/v1/api", routes);

/**
 * Health check
 */
app.get("/", (_req: Request, res: Response) => {
  res.send("Kebu Backend — API + Socket.io + MQTT");
});

/**
 * Start server
 */
const PORT = config.server.port;

httpServer.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🔌 Socket.io initialized`);
  console.log(`📡 MQTT → ${config.mqtt.host}:${config.mqtt.port}`);
});

/**
 * Graceful shutdown
 */
const shutdown = async (signal: string) => {
  console.log(`\n${signal} received. Shutting down gracefully...`);
  await closeMQTT();
  httpServer.close(() => {
    console.log("Server closed");
    process.exit(0);
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
