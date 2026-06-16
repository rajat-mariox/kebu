import api from "./api";
import type { ApiResponse } from "../types";

export interface SupportTicket {
  _id: string;
  userId?: {
    _id: string;
    fullName: string;
    mobileNumber: string;
    email?: string;
  };
  driverId?: {
    _id: string;
    fullName: string;
    mobileNumber: string;
    email?: string;
  };
  subject: string;
  description: string;
  category: "BOOKING" | "PAYMENT" | "DRIVER" | "SERVICE" | "APP" | "OTHER";
  status: "OPEN" | "IN_PROGRESS" | "RESOLVED" | "CLOSED";
  priority: "LOW" | "MEDIUM" | "HIGH";
  bookingId?: string;
  assignedTo?: {
    _id: string;
    name: string;
    email: string;
  };
  messages: {
    _id?: string;
    senderId: string;
    senderType: "USER" | "ADMIN" | "DRIVER";
    message: string;
    attachments?: string[];
    createdAt: string;
  }[];
  resolvedAt?: string;
  closedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface SupportTicketFilters {
  page?: number;
  limit?: number;
  status?: string;
  priority?: string;
  category?: string;
  search?: string;
}

export interface SupportTicketStats {
  total: number;
  open: number;
  inProgress: number;
  resolved: number;
  closed: number;
  highPriority: number;
}

export const supportService = {
  getAll: async (
    filters: SupportTicketFilters = {},
  ): Promise<
    ApiResponse<{
      tickets: SupportTicket[];
      pagination: {
        page: number;
        limit: number;
        total: number;
        totalPages: number;
      };
    }>
  > => {
    const response = await api.get("/admin/support-tickets", {
      params: filters,
    });
    return response.data;
  },

  getById: async (
    id: string,
  ): Promise<ApiResponse<{ ticket: SupportTicket }>> => {
    const response = await api.get(`/admin/support-tickets/${id}`);
    return response.data;
  },

  reply: async (
    id: string,
    message: string,
  ): Promise<ApiResponse<{ ticket: SupportTicket }>> => {
    const response = await api.post(`/admin/support-tickets/${id}/reply`, {
      message,
    });
    return response.data;
  },

  updateStatus: async (
    id: string,
    status: string,
  ): Promise<ApiResponse<{ ticket: SupportTicket }>> => {
    const response = await api.put(`/admin/support-tickets/${id}/status`, {
      status,
    });
    return response.data;
  },

  getStats: async (): Promise<ApiResponse<SupportTicketStats>> => {
    const response = await api.get("/admin/support-tickets/stats");
    return response.data;
  },
};
