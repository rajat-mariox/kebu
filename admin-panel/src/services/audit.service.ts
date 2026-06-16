import api from "./api";

export const auditService = {
  getAuditLogs: (params: {
    page?: number;
    limit?: number;
    adminId?: string;
    actionType?: string;
    entity?: string;
    startDate?: string;
    endDate?: string;
    search?: string;
  }) => api.get("/admin/audit-logs", { params }),

  exportAuditLogs: (params: {
    adminId?: string;
    actionType?: string;
    entity?: string;
    startDate?: string;
    endDate?: string;
  }) => api.get("/admin/audit-logs/export", { params }),

  getExportLogs: (params: { page?: number; limit?: number }) =>
    api.get("/admin/export-logs", { params }),
};
