import api from "./api";
import type {
  DashboardStats,
  ApiResponse,
  BookingChartData,
  ChartData,
} from "../types";

interface AnalyticsData {
  byDay?: { _id: string; revenue: number; bookings: number }[];
  byStatus?: { _id: string; count: number }[];
}

export const dashboardService = {
  getStats: async (): Promise<ApiResponse<DashboardStats>> => {
    const response = await api.get("/admin/dashboard");
    return response.data;
  },

  getRevenueAnalytics: async (
    period: "day" | "week" | "month",
  ): Promise<ApiResponse<AnalyticsData>> => {
    const response = await api.get("/admin/analytics/revenue", {
      params: { period },
    });
    return response.data;
  },

  getBookingAnalytics: async (
    period: "day" | "week" | "month",
  ): Promise<ApiResponse<AnalyticsData>> => {
    const response = await api.get("/admin/analytics/bookings", {
      params: { period },
    });
    return response.data;
  },

  getBookingChart: async (
    period: "week" | "month" | "year",
  ): Promise<ApiResponse<BookingChartData[]>> => {
    const response = await api.get("/admin/analytics/bookings", {
      params: { period },
    });
    return response.data;
  },

  getRevenueChart: async (
    period: "week" | "month" | "year",
  ): Promise<ApiResponse<ChartData[]>> => {
    const response = await api.get("/admin/analytics/revenue", {
      params: { period },
    });
    return response.data;
  },

  getKPIs: async () => {
    const response = await api.get("/admin/dashboard/kpis");
    return response.data;
  },

  getEventTimeline: async (page = 1, limit = 50) => {
    const response = await api.get("/admin/dashboard/timeline", {
      params: { page, limit },
    });
    return response.data;
  },
};
