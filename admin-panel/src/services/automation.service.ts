import api from "./api";

export const automationService = {
  getRules: (params?: { category?: string; isActive?: string }) =>
    api.get("/admin/automation-rules", { params }),

  createRule: (data: Record<string, any>) =>
    api.post("/admin/automation-rules", data),

  updateRule: (ruleId: string, data: Record<string, any>) =>
    api.put(`/admin/automation-rules/${ruleId}`, data),

  deleteRule: (ruleId: string) =>
    api.delete(`/admin/automation-rules/${ruleId}`),

  toggleRule: (ruleId: string) =>
    api.patch(`/admin/automation-rules/${ruleId}/toggle`),
};
