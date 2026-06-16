import api from "./api";

export interface ScratchCardRecord {
  _id: string;
  userId: string | { _id: string; name?: string; phone?: string; email?: string };
  title: string;
  description?: string;
  rewardType: "WALLET_CREDIT" | "DISCOUNT_COUPON" | "BETTER_LUCK";
  rewardValue: number;
  couponCode?: string;
  status: "UNSCRATCHED" | "SCRATCHED" | "EXPIRED";
  expiresAt: string;
  scratchedAt?: string;
  sourceType?: string;
  createdAt?: string;
}

export interface ScratchCardCreatePayload {
  userId?: string;
  userIds?: string[];
  title: string;
  description?: string;
  rewardType: "WALLET_CREDIT" | "DISCOUNT_COUPON" | "BETTER_LUCK";
  rewardValue?: number;
  couponCode?: string;
  expiresAt: string;
  sourceType?: string;
}

export const scratchCardService = {
  getAll: async (params: { userId?: string; status?: string; page?: number; limit?: number } = {}) => {
    const res = await api.get("/admin/scratch-cards", { params });
    return {
      cards: (res.data?.data?.cards || []) as ScratchCardRecord[],
      total: res.data?.data?.total || 0,
    };
  },

  create: async (payload: ScratchCardCreatePayload): Promise<{ created: number }> => {
    const res = await api.post("/admin/scratch-cards", payload);
    return res.data?.data || { created: 0 };
  },

  remove: async (id: string): Promise<void> => {
    await api.delete(`/admin/scratch-cards/${id}`);
  },
};
