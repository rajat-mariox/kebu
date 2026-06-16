import api from "./api";

// ========== SURGE CONFIG ==========
export const getSurgeConfigs = (serviceType?: string) =>
  api.get("/admin/surge-configs", { params: { serviceType } });

export const createSurgeConfig = (data: any) =>
  api.post("/admin/surge-configs", data);

export const updateSurgeConfig = (id: string, data: any) =>
  api.put(`/admin/surge-configs/${id}`, data);

export const deleteSurgeConfig = (id: string) =>
  api.delete(`/admin/surge-configs/${id}`);

// ========== COMMISSION CONFIG ==========
export const getCommissionConfigs = (serviceType?: string) =>
  api.get("/admin/commission-configs", { params: { serviceType } });

export const createCommissionConfig = (data: any) =>
  api.post("/admin/commission-configs", data);

export const updateCommissionConfig = (id: string, data: any) =>
  api.put(`/admin/commission-configs/${id}`, data);

export const deleteCommissionConfig = (id: string) =>
  api.delete(`/admin/commission-configs/${id}`);

// ========== CANCELLATION POLICY ==========
export const getCancellationPolicies = (serviceType?: string) =>
  api.get("/admin/cancellation-policies", { params: { serviceType } });

export const createCancellationPolicy = (data: any) =>
  api.post("/admin/cancellation-policies", data);

export const updateCancellationPolicy = (id: string, data: any) =>
  api.put(`/admin/cancellation-policies/${id}`, data);

export const deleteCancellationPolicy = (id: string) =>
  api.delete(`/admin/cancellation-policies/${id}`);

// ========== DELIVERY PACKAGE TYPES ==========
export const getDeliveryPackageTypes = () =>
  api.get("/admin/delivery-package-types");

export const createDeliveryPackageType = (data: any) =>
  api.post("/admin/delivery-package-types", data);

export const updateDeliveryPackageType = (id: string, data: any) =>
  api.put(`/admin/delivery-package-types/${id}`, data);

export const deleteDeliveryPackageType = (id: string) =>
  api.delete(`/admin/delivery-package-types/${id}`);

// ========== SERVICE-SPECIFIC ANALYTICS ==========
export const getCabAnalytics = (params?: { range?: string; startDate?: string; endDate?: string }) =>
  api.get("/admin/analytics/cab", { params });

export const getDeliveryAnalytics = (params?: { range?: string; startDate?: string; endDate?: string }) =>
  api.get("/admin/analytics/delivery", { params });

export const getHouseholdAnalytics = (params?: { range?: string; startDate?: string; endDate?: string }) =>
  api.get("/admin/analytics/household", { params });

// ========== SERVICE PROVIDER ACTIONS ==========
export const rejectServiceProvider = (providerId: string, reason: string) =>
  api.put(`/admin/service-providers/${providerId}/reject`, { reason });

export const suspendServiceProvider = (providerId: string, reason: string) =>
  api.put(`/admin/service-providers/${providerId}/suspend`, { reason });

export const activateServiceProvider = (providerId: string) =>
  api.put(`/admin/service-providers/${providerId}/activate`);

// ========== SERVICE PACKAGES ==========
export const getServicePackages = (serviceId?: string) =>
  api.get("/admin/service-packages", { params: { serviceId } });

export const createServicePackage = (data: any) =>
  api.post("/admin/service-packages", data);

export const updateServicePackage = (id: string, data: any) =>
  api.put(`/admin/service-packages/${id}`, data);

export const deleteServicePackage = (id: string) =>
  api.delete(`/admin/service-packages/${id}`);

// ========== PAYOUTS ==========
export const getPayouts = (params?: { page?: number; limit?: number; serviceType?: string; status?: string; recipientType?: string }) =>
  api.get("/admin/payouts", { params });

export const getPayoutSummary = () =>
  api.get("/admin/payouts/summary");

export const processPayouts = (payoutIds: string[]) =>
  api.post("/admin/payouts/process", { payoutIds });

export const completePayouts = (payoutIds: string[], transactionRef: string) =>
  api.post("/admin/payouts/complete", { payoutIds, transactionRef });
