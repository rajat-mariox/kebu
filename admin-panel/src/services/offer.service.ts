import api from "./api";

export interface OfferRecord {
  _id: string;
  title: string;
  subtitle?: string;
  description: string;
  code?: string;
  type?: "PERCENTAGE" | "FLAT" | "CASHBACK";
  value?: number;
  maxDiscount?: number;
  minOrderValue?: number;
  applicableOn: "ALL" | "CAB" | "DELIVERY" | "HOUSEHOLD" | "WALLET";
  section: "latest" | "limited" | "just_for_you";
  targetService: "booking" | "cleaning" | "parcel" | "none";
  targetCategory?: string;
  startDate: string;
  endDate: string;
  image?: string;
  bannerImage?: string;
  tag?: string;
  priority: number;
  isActive: boolean;
  isDeleted: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface OfferListParams {
  section?: string;
  targetService?: string;
  isActive?: boolean;
  search?: string;
}

export const offerService = {
  getAll: async (params: OfferListParams = {}): Promise<OfferRecord[]> => {
    const query: Record<string, string> = {};
    if (params.section) query.section = params.section;
    if (params.targetService) query.targetService = params.targetService;
    if (params.isActive !== undefined)
      query.isActive = params.isActive ? "true" : "false";
    if (params.search) query.search = params.search;
    const res = await api.get("/admin/offers", { params: query });
    return res.data?.data?.offers || [];
  },

  getById: async (id: string): Promise<OfferRecord | null> => {
    const res = await api.get(`/admin/offers/${id}`);
    return res.data?.data?.offer || null;
  },

  create: async (payload: Partial<OfferRecord>): Promise<OfferRecord> => {
    const res = await api.post("/admin/offers", payload);
    return res.data?.data?.offer;
  },

  update: async (
    id: string,
    payload: Partial<OfferRecord>,
  ): Promise<OfferRecord> => {
    const res = await api.put(`/admin/offers/${id}`, payload);
    return res.data?.data?.offer;
  },

  remove: async (id: string): Promise<void> => {
    await api.delete(`/admin/offers/${id}`);
  },

  toggleStatus: async (id: string): Promise<OfferRecord> => {
    const res = await api.patch(`/admin/offers/${id}/toggle-status`);
    return res.data?.data?.offer;
  },
};
