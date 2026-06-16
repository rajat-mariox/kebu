import { v4 as uuidv4 } from "uuid";

export interface ChatMessage {
  id: string;
  bookingId: string;
  senderId: string;
  senderType: "user" | "driver";
  receiverId: string;
  message: string;
  type: "text" | "image" | "location";
  attachments?: string[];
  timestamp: number;
  read: boolean;
}

// In-memory chat store (per booking, capped at 100 messages)
const chatHistory = new Map<string, ChatMessage[]>();

export const saveMessage = (
  msg: Omit<ChatMessage, "id" | "timestamp" | "read">
): ChatMessage => {
  const fullMessage: ChatMessage = {
    ...msg,
    id: uuidv4(),
    timestamp: Date.now(),
    read: false,
  };

  if (!chatHistory.has(msg.bookingId)) {
    chatHistory.set(msg.bookingId, []);
  }

  const messages = chatHistory.get(msg.bookingId)!;
  messages.push(fullMessage);

  // Cap at 100 messages per booking
  if (messages.length > 100) {
    messages.splice(0, messages.length - 100);
  }

  return fullMessage;
};

export const getChatHistory = (
  bookingId: string,
  limit = 50,
  offset = 0
): ChatMessage[] => {
  const messages = chatHistory.get(bookingId) || [];
  return messages.slice(offset, offset + limit);
};

export const markMessagesAsRead = (
  bookingId: string,
  messageIds: string[]
): void => {
  const messages = chatHistory.get(bookingId);
  if (!messages) return;
  for (const id of messageIds) {
    const msg = messages.find((m) => m.id === id);
    if (msg) msg.read = true;
  }
};

export const getUnreadCount = (
  bookingId: string,
  userId: string
): number => {
  const messages = chatHistory.get(bookingId) || [];
  return messages.filter((m) => !m.read && m.receiverId === userId).length;
};

export const clearChatHistory = (bookingId: string): void => {
  chatHistory.delete(bookingId);
};

export const getActiveChats = (): {
  bookingId: string;
  lastMessage: ChatMessage;
  unreadCount: number;
}[] => {
  const result: {
    bookingId: string;
    lastMessage: ChatMessage;
    unreadCount: number;
  }[] = [];

  for (const [bookingId, messages] of chatHistory.entries()) {
    if (messages.length > 0) {
      result.push({
        bookingId,
        lastMessage: messages[messages.length - 1],
        unreadCount: messages.filter((m) => !m.read).length,
      });
    }
  }

  return result.sort(
    (a, b) => b.lastMessage.timestamp - a.lastMessage.timestamp
  );
};
