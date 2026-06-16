import api from "./api";
import type { User, ApiResponse, PaginatedResponse } from "../types";

export interface UserFilters {
  page?: number;
  limit?: number;
  search?: string;
  isActive?: boolean;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}

export const userService = {
  getAll: async (
    filters: UserFilters = {},
  ): Promise<ApiResponse<PaginatedResponse<User>>> => {
    const response = await api.get("/admin/users", { params: filters });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<User>> => {
    const response = await api.get(`/admin/users/${id}`);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<User>,
  ): Promise<ApiResponse<User>> => {
    const response = await api.put(`/admin/users/${id}`, data);
    return response.data;
  },

  toggleStatus: async (id: string, isActive?: boolean): Promise<ApiResponse<User>> => {
    const response = await api.put(`/admin/users/${id}/status`, { isActive: isActive ?? true });
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/users/${id}`);
    return response.data;
  },

  getStats: async (): Promise<
    ApiResponse<{
      total: number;
      active: number;
      inactive: number;
      newThisMonth: number;
    }>
  > => {
    const response = await api.get("/admin/users/stats");
    return response.data;
  },
};
