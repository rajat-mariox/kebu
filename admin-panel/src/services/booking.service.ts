import api from "./api";
import type {
  Booking,
  ApiResponse,
  PaginatedResponse,
  BookingStatus,
} from "../types";

export interface BookingFilters {
  page?: number;
  limit?: number;
  search?: string;
  status?: BookingStatus;
  paymentStatus?: string;
  startDate?: string;
  endDate?: string;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}

export const bookingService = {
  getAll: async (
    filters: BookingFilters = {},
  ): Promise<ApiResponse<PaginatedResponse<Booking>>> => {
    const response = await api.get("/admin/bookings", { params: filters });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<Booking>> => {
    const response = await api.get(`/admin/bookings/${id}`);
    return response.data;
  },

  cancel: async (id: string, reason: string): Promise<ApiResponse<Booking>> => {
    const response = await api.patch(`/admin/bookings/${id}/cancel`, {
      reason,
    });
    return response.data;
  },

  getStats: async (): Promise<
    ApiResponse<{
      total: number;
      completed: number;
      cancelled: number;
      active: number;
      todayBookings: number;
      totalRevenue: number;
      todayRevenue: number;
    }>
  > => {
    const response = await api.get("/admin/bookings/stats");
    return response.data;
  },

  getChartData: async (
    period: "week" | "month" | "year",
  ): Promise<
    ApiResponse<
      {
        date: string;
        bookings: number;
        revenue: number;
      }[]
    >
  > => {
    const response = await api.get("/admin/bookings/chart", {
      params: { period },
    });
    return response.data;
  },
};
