import api from "./api";
import type {
  Driver,
  ApiResponse,
  PaginatedResponse,
  DriverStatus,
} from "../types";

export interface DriverFilters {
  page?: number;
  limit?: number;
  search?: string;
  status?: DriverStatus;
  isActive?: boolean;
  isOnline?: boolean;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}

interface KycResponse {
  kyc?: Record<string, unknown>;
}

interface VehicleResponse {
  vehicle?: Record<string, unknown>;
}

export const driverService = {
  getAll: async (
    filters: DriverFilters = {},
  ): Promise<ApiResponse<PaginatedResponse<Driver>>> => {
    const response = await api.get("/admin/drivers", { params: filters });
    return response.data;
  },

  create: async (data: {
    mobileNumber: string;
    countryCode?: string;
    fullName?: string;
    email?: string;
    serviceType?: "cab" | "cleaning" | "parcel" | "";
    city?: string;
    state?: string;
    address?: string;
  }): Promise<ApiResponse<{ driver: Driver }>> => {
    const response = await api.post("/admin/drivers", data);
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<Driver>> => {
    const response = await api.get(`/admin/drivers/${id}`);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<Driver>,
  ): Promise<ApiResponse<Driver>> => {
    const response = await api.put(`/admin/drivers/${id}`, data);
    return response.data;
  },

  approve: async (id: string): Promise<ApiResponse<Driver>> => {
    const response = await api.put(`/admin/drivers/${id}/approve`);
    return response.data;
  },

  reject: async (id: string, reason: string): Promise<ApiResponse<Driver>> => {
    const response = await api.put(`/admin/drivers/${id}/reject`, { reason });
    return response.data;
  },

  suspend: async (id: string, reason: string): Promise<ApiResponse<Driver>> => {
    const response = await api.put(`/admin/drivers/${id}/suspend`, {
      reason,
    });
    return response.data;
  },

  activate: async (id: string): Promise<ApiResponse<Driver>> => {
    const response = await api.put(`/admin/drivers/${id}/activate`);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/drivers/${id}`);
    return response.data;
  },

  getStats: async (): Promise<
    ApiResponse<{
      total: number;
      approved: number;
      pending: number;
      online: number;
      suspended: number;
    }>
  > => {
    const response = await api.get("/admin/drivers/stats");
    return response.data;
  },

  getKycDocuments: async (id: string): Promise<ApiResponse<KycResponse>> => {
    const response = await api.get(`/admin/drivers/${id}/kyc`);
    return response.data;
  },

  getVehicle: async (id: string): Promise<ApiResponse<VehicleResponse>> => {
    const response = await api.get(`/admin/drivers/${id}/vehicle`);
    return response.data;
  },

  getPerformance: async (id: string) => {
    const response = await api.get(`/admin/drivers/${id}/performance`);
    return response.data;
  },
};
