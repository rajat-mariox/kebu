import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { createLogger } from '../utils/logger';
import { getConnectedClients, getClientCount } from '../websocket/server';
import { 
  sendPushNotification, 
  sendToMultipleDevices,
  subscribeToTopic,
  unsubscribeFromTopic,
  sendRideAcceptedNotification,
  sendDriverArrivedNotification,
  sendRideCompletedNotification,
  sendNewRideRequestNotification,
  sendSOSAlertNotification,
  sendChatMessageNotification,
} from '../services/notification.service';
import { 
  saveMessage, 
  getChatHistory, 
  markMessagesAsRead, 
  getActiveChats,
  clearChatHistory 
} from '../services/chat.service';
import { ChatMessage, NotificationPayload, RideRequest } from '../types';

const logger = createLogger('API');
const app = express();

app.use(cors());
app.use(express.json());

app.use((req: Request, res: Response, next: NextFunction) => {
  logger.debug(`${req.method} ${req.path}`, { query: req.query, body: req.body });
  next();
});

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    clients: getClientCount(),
  });
});

app.get('/stats', (req: Request, res: Response) => {
  res.json({
    connectedClients: getConnectedClients().length,
    clientList: getConnectedClients().map(c => ({
      id: c.id,
      type: c.type,
      userId: c.userId,
      connectedAt: new Date(c.connectedAt).toISOString(),
    })),
  });
});

app.post('/notifications/send', async (req: Request, res: Response) => {
  try {
    const payload = req.body as NotificationPayload;
    const success = await sendPushNotification(payload);
    res.json({ success });
  } catch (error: any) {
    logger.error('Failed to send notification', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/notifications/multicast', async (req: Request, res: Response) => {
  try {
    const { tokens, ...payload } = req.body;
    const result = await sendToMultipleDevices(tokens, payload);
    res.json(result);
  } catch (error: any) {
    logger.error('Failed to send multicast notification', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/notifications/subscribe', async (req: Request, res: Response) => {
  try {
    const { tokens, topic } = req.body;
    const success = await subscribeToTopic(tokens, topic);
    res.json({ success });
  } catch (error: any) {
    logger.error('Failed to subscribe to topic', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/notifications/unsubscribe', async (req: Request, res: Response) => {
  try {
    const { tokens, topic } = req.body;
    const success = await unsubscribeFromTopic(tokens, topic);
    res.json({ success });
  } catch (error: any) {
    logger.error('Failed to unsubscribe from topic', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/notifications/ride/:type', async (req: Request, res: Response) => {
  try {
    const { type } = req.params;
    const { token, driverTokens, ...data } = req.body;

    let success = false;
    switch (type) {
      case 'accepted':
        success = await sendRideAcceptedNotification(token, data.driverName, data.vehicleNumber, data.eta);
        break;
      case 'arrived':
        success = await sendDriverArrivedNotification(token, data.driverName);
        break;
      case 'completed':
        success = await sendRideCompletedNotification(token, data.fare, data.rating);
        break;
      case 'request':
        const result = await sendNewRideRequestNotification(driverTokens, data.pickup, data.fare, data.distance);
        res.json(result);
        return;
      case 'sos':
        const sosResult = await sendSOSAlertNotification(driverTokens, data.bookingId, data.location);
        res.json(sosResult);
        return;
      case 'chat':
        success = await sendChatMessageNotification(token, data.senderName, data.message);
        break;
      default:
        res.status(400).json({ error: 'Invalid notification type' });
        return;
    }

    res.json({ success });
  } catch (error: any) {
    logger.error('Failed to send ride notification', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/chat/message', async (req: Request, res: Response) => {
  try {
    const message = req.body as Omit<ChatMessage, 'id' | 'timestamp' | 'read'>;
    const savedMessage = await saveMessage(message);
    res.json(savedMessage);
  } catch (error: any) {
    logger.error('Failed to save message', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.get('/chat/:bookingId', (req: Request, res: Response) => {
  try {
    const { bookingId } = req.params;
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;
    const messages = getChatHistory(bookingId, limit, offset);
    res.json(messages);
  } catch (error: any) {
    logger.error('Failed to get chat history', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.post('/chat/:bookingId/read', (req: Request, res: Response) => {
  try {
    const { bookingId } = req.params;
    const { messageIds } = req.body;
    markMessagesAsRead(bookingId, messageIds);
    res.json({ success: true });
  } catch (error: any) {
    logger.error('Failed to mark messages as read', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.get('/chat', (req: Request, res: Response) => {
  try {
    const activeChats = getActiveChats();
    res.json(activeChats);
  } catch (error: any) {
    logger.error('Failed to get active chats', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.delete('/chat/:bookingId', (req: Request, res: Response) => {
  try {
    const { bookingId } = req.params;
    clearChatHistory(bookingId);
    res.json({ success: true });
  } catch (error: any) {
    logger.error('Failed to clear chat history', { error: error.message });
    res.status(500).json({ error: error.message });
  }
});

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal server error' });
});

export const initAPI = (): express.Application => {
  logger.info('REST API initialized');
  return app;
};

export const getApp = (): express.Application => app;
