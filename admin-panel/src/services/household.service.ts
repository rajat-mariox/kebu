import api from "./api";
import type {
  ServiceCategory,
  ServiceDetails,
  ServicePackage,
  ServiceProvider,
  ServiceBooking,
  ApiResponse,
  PaginatedResponse,
  ServiceBookingStatus,
} from "../types";

// Category Service
export const categoryService = {
  getAll: async (params?: {
    page?: number;
    limit?: number;
    search?: string;
  }): Promise<ApiResponse<{ categories: ServiceCategory[] }>> => {
    const response = await api.get("/admin/service-categories", { params });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<ServiceCategory>> => {
    const response = await api.get(`/admin/service-categories/${id}`);
    return response.data;
  },

  create: async (
    data: Partial<ServiceCategory>,
  ): Promise<ApiResponse<ServiceCategory>> => {
    const response = await api.post("/admin/service-categories", data);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<ServiceCategory>,
  ): Promise<ApiResponse<ServiceCategory>> => {
    const response = await api.put(`/admin/service-categories/${id}`, data);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/service-categories/${id}`);
    return response.data;
  },

  toggleStatus: async (id: string): Promise<ApiResponse<ServiceCategory>> => {
    const response = await api.patch(
      `/admin/service-categories/${id}/toggle-status`,
    );
    return response.data;
  },
};

// Service Details Service
export const serviceService = {
  getAll: async (params?: {
    page?: number;
    limit?: number;
    search?: string;
    categoryId?: string;
  }): Promise<ApiResponse<{ services: ServiceDetails[] }>> => {
    const response = await api.get("/admin/services", { params });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<ServiceDetails>> => {
    const response = await api.get(`/admin/services/${id}`);
    return response.data;
  },

  create: async (
    data: Partial<ServiceDetails>,
  ): Promise<ApiResponse<ServiceDetails>> => {
    const response = await api.post("/admin/services", data);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<ServiceDetails>,
  ): Promise<ApiResponse<ServiceDetails>> => {
    const response = await api.put(`/admin/services/${id}`, data);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/services/${id}`);
    return response.data;
  },

  toggleStatus: async (id: string): Promise<ApiResponse<ServiceDetails>> => {
    const response = await api.patch(`/admin/services/${id}/toggle-status`);
    return response.data;
  },
};

// Package Service
export const packageService = {
  getAll: async (params?: {
    page?: number;
    limit?: number;
    serviceId?: string;
    categoryId?: string;
  }): Promise<ApiResponse<PaginatedResponse<ServicePackage>>> => {
    const response = await api.get("/admin/service-packages", { params });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<ServicePackage>> => {
    const response = await api.get(`/admin/service-packages/${id}`);
    return response.data;
  },

  create: async (
    data: Partial<ServicePackage>,
  ): Promise<ApiResponse<ServicePackage>> => {
    const response = await api.post("/admin/service-packages", data);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<ServicePackage>,
  ): Promise<ApiResponse<ServicePackage>> => {
    const response = await api.put(`/admin/service-packages/${id}`, data);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/service-packages/${id}`);
    return response.data;
  },

  toggleStatus: async (id: string): Promise<ApiResponse<ServicePackage>> => {
    const response = await api.patch(
      `/admin/service-packages/${id}/toggle-status`,
    );
    return response.data;
  },
};

// Service Provider Service
export const providerService = {
  getAll: async (params?: {
    page?: number;
    limit?: number;
    search?: string;
    status?: string;
  }): Promise<ApiResponse<PaginatedResponse<ServiceProvider>>> => {
    const response = await api.get("/admin/service-providers", { params });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<ServiceProvider>> => {
    const response = await api.get(`/admin/service-providers/${id}`);
    return response.data;
  },

  approve: async (id: string): Promise<ApiResponse<ServiceProvider>> => {
    const response = await api.patch(`/admin/service-providers/${id}/approve`);
    return response.data;
  },

  reject: async (
    id: string,
    reason: string,
  ): Promise<ApiResponse<ServiceProvider>> => {
    const response = await api.patch(`/admin/service-providers/${id}/reject`, {
      reason,
    });
    return response.data;
  },

  suspend: async (
    id: string,
    reason: string,
  ): Promise<ApiResponse<ServiceProvider>> => {
    const response = await api.patch(`/admin/service-providers/${id}/suspend`, {
      reason,
    });
    return response.data;
  },

  activate: async (id: string): Promise<ApiResponse<ServiceProvider>> => {
    const response = await api.patch(`/admin/service-providers/${id}/activate`);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/service-providers/${id}`);
    return response.data;
  },
};

// Service Booking Service
export interface ServiceBookingFilters {
  page?: number;
  limit?: number;
  search?: string;
  status?: ServiceBookingStatus;
  paymentStatus?: string;
  startDate?: string;
  endDate?: string;
  categoryId?: string;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}

export const serviceBookingService = {
  getAll: async (
    filters: ServiceBookingFilters = {},
  ): Promise<ApiResponse<PaginatedResponse<ServiceBooking>>> => {
    const response = await api.get("/admin/service-bookings", {
      params: filters,
    });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<ServiceBooking>> => {
    const response = await api.get(`/admin/service-bookings/${id}`);
    return response.data;
  },

  updateStatus: async (
    id: string,
    status: string,
    notes?: string,
  ): Promise<ApiResponse<ServiceBooking>> => {
    const response = await api.put(`/admin/service-bookings/${id}/status`, {
      status,
      notes,
    });
    return response.data;
  },

  cancel: async (
    id: string,
    reason: string,
  ): Promise<ApiResponse<ServiceBooking>> => {
    const response = await api.put(`/admin/service-bookings/${id}/status`, {
      status: "cancelled",
      notes: reason,
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
    }>
  > => {
    const response = await api.get("/admin/service-bookings/stats");
    return response.data;
  },
};

// Household service operating hours
export interface HouseholdServiceHours {
  openTime: string;
  closeTime: string;
  daysActive: number[];
  timezone: string;
  isEnabled: boolean;
  closedMessage?: string;
  arrivalEta?: string;
  isOpen?: boolean;
  reason?: string;
}

export const serviceHoursService = {
  get: async (): Promise<ApiResponse<HouseholdServiceHours>> => {
    const response = await api.get("/admin/household/service-hours");
    return response.data;
  },
  update: async (
    data: Partial<HouseholdServiceHours>,
  ): Promise<ApiResponse<HouseholdServiceHours>> => {
    const response = await api.put("/admin/household/service-hours", data);
    return response.data;
  },
};

// Admin-configured pricing for Household pre-book tiles (Single / Multiple)
export type BookingTypeKey = "SINGLE" | "MULTIPLE";

export interface BookingTypeConfig {
  _id?: string;
  bookingType: BookingTypeKey;
  title: string;
  description?: string;
  basePrice: number;
  discountedPrice?: number;
  displayOrder: number;
  isActive: boolean;
}

export const bookingTypeConfigService = {
  getAll: async (): Promise<
    ApiResponse<{ bookingTypes: BookingTypeConfig[] }>
  > => {
    const response = await api.get("/admin/household/booking-types");
    return response.data;
  },
  update: async (
    bookingType: BookingTypeKey,
    data: Partial<BookingTypeConfig>,
  ): Promise<ApiResponse<{ bookingType: BookingTypeConfig }>> => {
    const response = await api.put(
      `/admin/household/booking-types/${bookingType}`,
      data,
    );
    return response.data;
  },
};
