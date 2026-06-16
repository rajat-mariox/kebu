import api from "./api";
import type { CMSPage, ApiResponse } from "../types";

export const cmsService = {
  getAll: async (): Promise<ApiResponse<CMSPage[]>> => {
    const response = await api.get("/admin/cms");
    return response.data;
  },

  getBySlug: async (slug: string): Promise<ApiResponse<CMSPage>> => {
    const response = await api.get(`/admin/cms/${slug}`);
    return response.data;
  },

  create: async (data: Partial<CMSPage>): Promise<ApiResponse<CMSPage>> => {
    const response = await api.post("/admin/cms", data);
    return response.data;
  },

  update: async (
    slug: string,
    data: Partial<CMSPage>,
  ): Promise<ApiResponse<CMSPage>> => {
    const response = await api.put(`/admin/cms/${slug}`, data);
    return response.data;
  },

  delete: async (slug: string): Promise<ApiResponse<null>> => {
    const response = await api.delete(`/admin/cms/${slug}`);
    return response.data;
  },

  toggleStatus: async (slug: string): Promise<ApiResponse<CMSPage>> => {
    const response = await api.patch(`/admin/cms/${slug}/toggle-status`);
    return response.data;
  },
};

// Predefined CMS pages
export const CMS_PAGES = [
  { slug: "terms-and-conditions", title: "Terms & Conditions" },
  { slug: "privacy-policy", title: "Privacy Policy" },
  { slug: "about-us", title: "About Us" },
  { slug: "contact-us", title: "Contact Us" },
  { slug: "faq", title: "FAQ" },
  { slug: "refund-policy", title: "Refund Policy" },
  { slug: "cancellation-policy", title: "Cancellation Policy" },
] as const;
