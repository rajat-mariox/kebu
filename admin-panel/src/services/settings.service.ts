import api from "./api";

export interface AppSetting {
  _id?: string;
  key: string;
  value: string;
  label: string;
  category: string;
  isPublic: boolean;
  updatedAt?: string;
}

export const settingsService = {
  getSettings: async () => {
    const response = await api.get("/admin/settings");
    return response.data;
  },

  updateSettings: async (settings: { key: string; value: string }[]) => {
    const response = await api.put("/admin/settings", { settings });
    return response.data;
  },

  addSetting: async (setting: Omit<AppSetting, "_id" | "updatedAt">) => {
    const response = await api.post("/admin/settings", setting);
    return response.data;
  },

  deleteSetting: async (key: string) => {
    const response = await api.delete(`/admin/settings/${key}`);
    return response.data;
  },
};
