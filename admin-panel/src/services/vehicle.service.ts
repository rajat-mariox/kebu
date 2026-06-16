import api from "./api";

export interface VehicleCategory {
  _id: string;
  name: string;
  code: string;
  icon?: string;
  isActive: boolean;
  createdAt: string;
}

export interface VehicleType {
  _id: string;
  name: string;
  category: string | VehicleCategory;
  categoryId?: string | VehicleCategory;
  baseFare: number;
  perKmRate: number;
  perMinuteRate: number;
  minimumFare: number;
  surgeMultiplier: number;
  cancellationFee: number;
  maxSeats: number;
  maxWeightKg?: number;
  minDistanceKm?: number;
  description?: string;
  image?: string;
  icon?: string;
  isActive: boolean;
  createdAt: string;
}

export const vehicleService = {
  // ── Categories ──
  getCategories: async () => {
    const response = await api.get("/admin/vehicle-categories");
    return response.data;
  },

  createCategory: async (data: Partial<VehicleCategory>) => {
    const response = await api.post("/admin/vehicle-categories", data);
    return response.data;
  },

  updateCategory: async (id: string, data: Partial<VehicleCategory>) => {
    const response = await api.put(`/admin/vehicle-categories/${id}`, data);
    return response.data;
  },

  deleteCategory: async (id: string) => {
    const response = await api.delete(`/admin/vehicle-categories/${id}`);
    return response.data;
  },

  // ── Vehicle Types ──
  getTypes: async () => {
    const response = await api.get("/admin/vehicle-types");
    return response.data;
  },

  createType: async (data: Partial<VehicleType>) => {
    const response = await api.post("/admin/vehicle-types", data);
    return response.data;
  },

  updateType: async (id: string, data: Partial<VehicleType>) => {
    const response = await api.put(`/admin/vehicle-types/${id}`, data);
    return response.data;
  },

  deleteType: async (id: string) => {
    const response = await api.delete(`/admin/vehicle-types/${id}`);
    return response.data;
  },
};
