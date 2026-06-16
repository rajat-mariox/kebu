import api from "./api";

export const alertService = {
  getActiveAlerts: () => api.get("/admin/alerts/active"),

  getAlerts: (params: {
    page?: number;
    limit?: number;
    type?: string;
    severity?: string;
    isResolved?: string;
  }) => api.get("/admin/alerts", { params }),

  resolveAlert: (alertId: string) =>
    api.put(`/admin/alerts/${alertId}/resolve`),

  checkAlerts: () => api.post("/admin/alerts/check"),
};
