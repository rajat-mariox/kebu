import api from "./api";
import type { Admin, ApiResponse } from "../types";

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  admin: Admin;
  token: string;
}

export const authService = {
  login: async (data: LoginRequest): Promise<ApiResponse<LoginResponse>> => {
    const response = await api.post("/admin/login", data);
    return response.data;
  },

  logout: async (): Promise<void> => {
    localStorage.removeItem("adminToken");
    localStorage.removeItem("admin");
  },

  getProfile: async (): Promise<ApiResponse<Admin>> => {
    const response = await api.get("/admin/profile");
    return response.data;
  },

  updateProfile: async (data: Partial<Admin>): Promise<ApiResponse<Admin>> => {
    const response = await api.put("/admin/profile", data);
    return response.data;
  },

  changePassword: async (data: {
    currentPassword: string;
    newPassword: string;
  }): Promise<ApiResponse<null>> => {
    const response = await api.put("/admin/change-password", data);
    return response.data;
  },
};
