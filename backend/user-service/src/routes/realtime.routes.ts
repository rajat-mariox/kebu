import { Router, Request, Response, NextFunction } from "express";
import AuthMiddleware from "../middlewares/auth.middleware";
import AdminAuthMiddleware from "../middlewares/admin-auth.middleware";
import * as NotificationService from "../services/notification.service";
import * as ChatService from "../services/chat.service";
import { getConnectedUsers, getConnectedDrivers } from "../socket/index";

const realtimeRouter = Router();

// ========== HEALTH / STATS ==========

realtimeRouter.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    connectedUsers: getConnectedUsers().size,
    connectedDrivers: getConnectedDrivers().size,
  });
});

realtimeRouter.get(
  "/stats",
  AdminAuthMiddleware().verifyAdminToken,
  (_req: Request, res: Response) => {
    res.json({
      connectedUsers: Array.from(getConnectedUsers().values()),
      connectedDrivers: Array.from(getConnectedDrivers().values()),
    });
  }
);

// ========== PUSH NOTIFICATIONS ==========

/**
 * Send push notification to a single device
 */
realtimeRouter.post(
  "/notifications/send",
  AdminAuthMiddleware().verifyAdminToken,
  async (req: Request, res: Response) => {
    try {
      const { token, title, body, data } = req.body;
      const result = await NotificationService.sendToDevice(token, { title, body, data });
      res.json({ success: true, result });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
);

/**
 * Send push to multiple devices
 */
realtimeRouter.post(
  "/notifications/multicast",
  AdminAuthMiddleware().verifyAdminToken,
  async (req: Request, res: Response) => {
    try {
      const { tokens, title, body, data } = req.body;
      const result = await NotificationService.sendToMultipleDevices(tokens, { title, body, data });
      res.json({ success: true, result });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
);

/**
 * Send push to a topic
 */
realtimeRouter.post(
  "/notifications/topic",
  AdminAuthMiddleware().verifyAdminToken,
  async (req: Request, res: Response) => {
    try {
      const { topic, title, body, data } = req.body;
      const result = await NotificationService.sendToTopic(topic, { title, body, data });
      res.json({ success: true, result });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
);

/**
 * Subscribe tokens to a topic
 */
realtimeRouter.post(
  "/notifications/subscribe",
  AdminAuthMiddleware().verifyAdminToken,
  async (req: Request, res: Response) => {
    try {
      const { tokens, topic } = req.body;
      const result = await NotificationService.subscribeToTopic(tokens, topic);
      res.json({ success: true, result });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  }
);

// ========== CHAT ==========

/**
 * Get chat history for a booking
 */
realtimeRouter.get(
  "/chat/:bookingId",
  AuthMiddleware().verifyUserToken,
  (req: Request, res: Response) => {
    const { bookingId } = req.params;
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;
    const messages = ChatService.getChatHistory(bookingId, limit, offset);
    res.json({ success: true, data: messages });
  }
);

/**
 * Mark messages as read
 */
realtimeRouter.post(
  "/chat/:bookingId/read",
  AuthMiddleware().verifyUserToken,
  (req: Request, res: Response) => {
    const { bookingId } = req.params;
    const { messageIds } = req.body;
    ChatService.markMessagesAsRead(bookingId, messageIds);
    res.json({ success: true });
  }
);

/**
 * Get active chats (admin)
 */
realtimeRouter.get(
  "/chat",
  AdminAuthMiddleware().verifyAdminToken,
  (_req: Request, res: Response) => {
    const activeChats = ChatService.getActiveChats();
    res.json({ success: true, data: activeChats });
  }
);

export default realtimeRouter;
