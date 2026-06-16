import api from "./api";
import type {
  Admin,
  AdminRole,
  ApiResponse,
  PaginatedResponse,
  Permission,
} from "../types";

// Admin Service
export const adminService = {
  getAll: async (params?: {
    page?: number;
    limit?: number;
    search?: string;
  }): Promise<ApiResponse<PaginatedResponse<Admin>>> => {
    const response = await api.get("/admin/admins", { params });
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<Admin>> => {
    const response = await api.get(`/admin/admins/${id}`);
    return response.data;
  },

  create: async (data: {
    name: string;
    email: string;
    password: string;
    mobileNumber?: string;
    roleId: string;
    permissions?: Permission[];
  }): Promise<ApiResponse<Admin>> => {
    const response = await api.post("/admin/admins", data);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<Admin & { roleId?: string }>,
  ): Promise<ApiResponse<Admin>> => {
    const response = await api.put(`/admin/admins/${id}`, data);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/admins/${id}`);
    return response.data;
  },

  toggleStatus: async (id: string): Promise<ApiResponse<Admin>> => {
    const response = await api.patch(`/admin/admins/${id}/toggle-status`);
    return response.data;
  },

  resetPassword: async (
    id: string,
    newPassword: string,
  ): Promise<ApiResponse<null>> => {
    const response = await api.patch(`/admin/admins/${id}/reset-password`, {
      newPassword,
    });
    return response.data;
  },
};

// Role Service
export const roleService = {
  getAll: async (): Promise<ApiResponse<AdminRole[]>> => {
    const response = await api.get("/admin/roles");
    return response.data;
  },

  getById: async (id: string): Promise<ApiResponse<AdminRole>> => {
    const response = await api.get(`/admin/roles/${id}`);
    return response.data;
  },

  create: async (data: {
    name: string;
    description?: string;
    permissions: Permission[];
  }): Promise<ApiResponse<AdminRole>> => {
    const response = await api.post("/admin/roles", data);
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<AdminRole>,
  ): Promise<ApiResponse<AdminRole>> => {
    const response = await api.put(`/admin/roles/${id}`, data);
    return response.data;
  },

  delete: async (id: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/roles/${id}`);
    return response.data;
  },
};

// All available permissions grouped by module
export const PERMISSIONS_BY_MODULE: Record<
  string,
  { label: string; permissions: Permission[] }
> = {
  dashboard: {
    label: "Dashboard",
    permissions: ["dashboard:view"],
  },
  users: {
    label: "User Management",
    permissions: ["users:view", "users:create", "users:edit", "users:delete"],
  },
  drivers: {
    label: "Driver Management",
    permissions: [
      "drivers:view",
      "drivers:create",
      "drivers:edit",
      "drivers:delete",
      "drivers:approve",
    ],
  },
  bookings: {
    label: "Ride Bookings",
    permissions: ["bookings:view", "bookings:edit", "bookings:cancel"],
  },
  household: {
    label: "Household Services",
    permissions: [
      "household:view",
      "household:create",
      "household:edit",
      "household:delete",
    ],
  },
  categories: {
    label: "Categories",
    permissions: [
      "categories:view",
      "categories:create",
      "categories:edit",
      "categories:delete",
    ],
  },
  serviceBookings: {
    label: "Service Bookings",
    permissions: [
      "service-bookings:view",
      "service-bookings:edit",
      "service-bookings:cancel",
    ],
  },
  providers: {
    label: "Service Providers",
    permissions: [
      "providers:view",
      "providers:create",
      "providers:edit",
      "providers:delete",
      "providers:approve",
    ],
  },
  cms: {
    label: "CMS",
    permissions: ["cms:view", "cms:create", "cms:edit", "cms:delete"],
  },
  admins: {
    label: "Admin Management",
    permissions: [
      "admins:view",
      "admins:create",
      "admins:edit",
      "admins:delete",
    ],
  },
  roles: {
    label: "Role Management",
    permissions: ["roles:view", "roles:create", "roles:edit", "roles:delete"],
  },
  settings: {
    label: "Settings",
    permissions: ["settings:view", "settings:edit"],
  },
};
