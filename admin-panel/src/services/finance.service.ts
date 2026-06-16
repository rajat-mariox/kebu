import api from "./api";

export const financeService = {
  getOverview: (params: {
    range?: string;
    startDate?: string;
    endDate?: string;
  }) => api.get("/admin/finance/overview", { params }),

  getRevenueTrend: (params: {
    range?: string;
    startDate?: string;
    endDate?: string;
  }) => api.get("/admin/finance/revenue-trend", { params }),

  getVehicleBreakdown: (params: {
    range?: string;
    startDate?: string;
    endDate?: string;
  }) => api.get("/admin/finance/vehicle-breakdown", { params }),

  exportFinanceData: (params: {
    range?: string;
    startDate?: string;
    endDate?: string;
  }) => api.get("/admin/finance/export", { params }),
};
