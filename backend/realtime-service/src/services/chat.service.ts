import { v4 as uuidv4 } from 'uuid';
import { createLogger } from '../utils/logger';
import { ChatMessage } from '../types';
import { emitToBooking } from '../websocket/server';

const logger = createLogger('Chat');

const chatHistory: Map<string, ChatMessage[]> = new Map();
const TYPING_TIMEOUT = 5000;

export const saveMessage = async (message: Omit<ChatMessage, 'id' | 'timestamp' | 'read'>): Promise<ChatMessage> => {
  const fullMessage: ChatMessage = {
    ...message,
    id: uuidv4(),
    timestamp: Date.now(),
    read: false,
  };

  const bookingId = message.bookingId;
  if (!chatHistory.has(bookingId)) {
    chatHistory.set(bookingId, []);
  }
  
  const messages = chatHistory.get(bookingId)!;
  messages.push(fullMessage);
  
  if (messages.length > 100) {
    messages.splice(0, messages.length - 100);
  }

  emitToBooking(bookingId, 'new-message', fullMessage);

  logger.debug(`Message saved for booking ${bookingId}`, { messageId: fullMessage.id });
  return fullMessage;
};

export const getChatHistory = (bookingId: string, limit = 50, offset = 0): ChatMessage[] => {
  const messages = chatHistory.get(bookingId) || [];
  return messages.slice(offset, offset + limit);
};

export const markMessagesAsRead = (bookingId: string, messageIds: string[]): void => {
  const messages = chatHistory.get(bookingId);
  if (!messages) return;

  for (const id of messageIds) {
    const message = messages.find(m => m.id === id);
    if (message) {
      message.read = true;
    }
  }
};

export const getUnreadCount = (bookingId: string, userId: string): number => {
  const messages = chatHistory.get(bookingId) || [];
  return messages.filter(m => !m.read && m.receiverId === userId).length;
};

export const clearChatHistory = (bookingId: string): void => {
  chatHistory.delete(bookingId);
  logger.info(`Chat history cleared for booking ${bookingId}`);
};

export const searchMessages = (bookingId: string, query: string): ChatMessage[] => {
  const messages = chatHistory.get(bookingId) || [];
  const lowerQuery = query.toLowerCase();
  return messages.filter(m => m.message.toLowerCase().includes(lowerQuery));
};

export const getActiveChats = (): { bookingId: string; lastMessage: ChatMessage; unreadCount: number }[] => {
  const activeChats: { bookingId: string; lastMessage: ChatMessage; unreadCount: number }[] = [];

  for (const [bookingId, messages] of chatHistory.entries()) {
    if (messages.length > 0) {
      const lastMessage = messages[messages.length - 1];
      const unreadCount = messages.filter(m => !m.read).length;
      activeChats.push({ bookingId, lastMessage, unreadCount });
    }
  }

  return activeChats.sort((a, b) => b.lastMessage.timestamp - a.lastMessage.timestamp);
};
