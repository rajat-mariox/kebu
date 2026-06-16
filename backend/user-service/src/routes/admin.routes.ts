import { Router } from "express";

import * as AdminController from "../controllers/admin.controller";
import * as HouseholdController from "../controllers/household.controller";
import * as OfferController from "../controllers/offer.controller";
import * as AuditLogController from "../controllers/audit-log.controller";
import * as SearchController from "../controllers/search.controller";
import * as FinanceController from "../controllers/finance.controller";
import * as AlertController from "../controllers/alert.controller";
import * as AutomationController from "../controllers/automation.controller";
import * as ServiceConfigController from "../controllers/service-config.controller";
import * as ScratchCardController from "../controllers/scratch-card.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AdminAuthMiddleware from "../middlewares/admin-auth.middleware";
import upload from "../middlewares/upload.middleware";

const adminRouter = Router();

// ========== AUTH ==========

adminRouter.post(
  "/login",
  ErrorHandlerMiddleware(AdminController.adminLogin),
  ResponseMiddleware,
);

// ========== DASHBOARD ==========

adminRouter.get(
  "/dashboard",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDashboardStats),
  ResponseMiddleware,
);

// ========== USERS ==========

adminRouter.get(
  "/users",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getUsers),
  ResponseMiddleware,
);

adminRouter.get(
  "/users/:userId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getUserDetails),
  ResponseMiddleware,
);

adminRouter.put(
  "/users/:userId/status",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.updateUserStatus),
  ResponseMiddleware,
);

// ========== DRIVERS ==========

adminRouter.get(
  "/drivers",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDrivers),
  ResponseMiddleware,
);

adminRouter.post(
  "/drivers",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createDriver),
  ResponseMiddleware,
);

adminRouter.get(
  "/drivers/:driverId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDriverDetails),
  ResponseMiddleware,
);

adminRouter.put(
  "/drivers/:driverId/approve",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.approveDriver),
  ResponseMiddleware,
);

adminRouter.put(
  "/drivers/:driverId/reject",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.rejectDriver),
  ResponseMiddleware,
);

adminRouter.put(
  "/drivers/:driverId/suspend",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.suspendDriver),
  ResponseMiddleware,
);

// ========== BOOKINGS ==========

adminRouter.get(
  "/bookings",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getBookings),
  ResponseMiddleware,
);

adminRouter.get(
  "/bookings/:bookingId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getBookingDetails),
  ResponseMiddleware,
);

// ========== VEHICLE MANAGEMENT ==========

adminRouter.get(
  "/vehicle-categories",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getVehicleCategories),
  ResponseMiddleware,
);

adminRouter.post(
  "/vehicle-categories",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createVehicleCategory),
  ResponseMiddleware,
);

adminRouter.get(
  "/vehicle-types",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getVehicleTypes),
  ResponseMiddleware,
);

adminRouter.post(
  "/vehicle-types",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createVehicleType),
  ResponseMiddleware,
);

adminRouter.put(
  "/vehicle-types/:typeId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateVehicleType),
  ResponseMiddleware,
);

// ========== SERVICE CATEGORIES ==========

adminRouter.get(
  "/service-categories",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getServiceCategories),
  ResponseMiddleware,
);

adminRouter.post(
  "/service-categories",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createServiceCategory),
  ResponseMiddleware,
);

// ========== SERVICE PROVIDERS ==========

adminRouter.get(
  "/service-providers",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getServiceProviders),
  ResponseMiddleware,
);

adminRouter.put(
  "/service-providers/:providerId/approve",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.approveServiceProvider),
  ResponseMiddleware,
);

// Assign which household service categories a cleaning-type Driver can accept
adminRouter.put(
  "/drivers/:driverId/household-categories",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.setDriverHouseholdCategories),
  ResponseMiddleware,
);

// ========== ANALYTICS ==========

adminRouter.get(
  "/analytics/revenue",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getRevenueAnalytics),
  ResponseMiddleware,
);

adminRouter.get(
  "/analytics/bookings",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getBookingAnalytics),
  ResponseMiddleware,
);

// ========== ADMIN MANAGEMENT ==========

adminRouter.get(
  "/admins",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.getAdmins),
  ResponseMiddleware,
);

adminRouter.get(
  "/admins/:adminId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.getAdminById),
  ResponseMiddleware,
);

adminRouter.post(
  "/admins",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.createAdmin),
  ResponseMiddleware,
);

adminRouter.put(
  "/admins/:adminId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.updateAdmin),
  ResponseMiddleware,
);

adminRouter.delete(
  "/admins/:adminId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.deleteAdmin),
  ResponseMiddleware,
);

adminRouter.patch(
  "/admins/:adminId/toggle-status",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.toggleAdminStatus),
  ResponseMiddleware,
);

adminRouter.patch(
  "/admins/:adminId/reset-password",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.resetAdminPassword),
  ResponseMiddleware,
);

// ========== ROLE MANAGEMENT ==========

adminRouter.get(
  "/roles",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getRoles),
  ResponseMiddleware,
);

adminRouter.get(
  "/roles/:roleId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getRoleById),
  ResponseMiddleware,
);

adminRouter.post(
  "/roles",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.createRole),
  ResponseMiddleware,
);

adminRouter.put(
  "/roles/:roleId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.updateRole),
  ResponseMiddleware,
);

adminRouter.delete(
  "/roles/:roleId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.deleteRole),
  ResponseMiddleware,
);

// ========== OFFERS MANAGEMENT ==========

adminRouter.get(
  "/offers",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(OfferController.listOffers),
  ResponseMiddleware,
);

adminRouter.get(
  "/offers/:offerId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(OfferController.getOfferById),
  ResponseMiddleware,
);

adminRouter.post(
  "/offers",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(OfferController.createOffer),
  ResponseMiddleware,
);

adminRouter.put(
  "/offers/:offerId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(OfferController.updateOffer),
  ResponseMiddleware,
);

adminRouter.patch(
  "/offers/:offerId/toggle-status",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(OfferController.toggleOfferStatus),
  ResponseMiddleware,
);

adminRouter.delete(
  "/offers/:offerId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(OfferController.deleteOffer),
  ResponseMiddleware,
);

// ========== CMS MANAGEMENT ==========

adminRouter.get(
  "/cms",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getCmsPages),
  ResponseMiddleware,
);

adminRouter.get(
  "/cms/:slug",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getCmsPageBySlug),
  ResponseMiddleware,
);

adminRouter.post(
  "/cms",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createCmsPage),
  ResponseMiddleware,
);

adminRouter.put(
  "/cms/:slug",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateCmsPage),
  ResponseMiddleware,
);

adminRouter.delete(
  "/cms/:slug",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteCmsPage),
  ResponseMiddleware,
);

// ========== SERVICE BOOKINGS ==========

adminRouter.get(
  "/service-bookings",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getServiceBookings),
  ResponseMiddleware,
);

adminRouter.get(
  "/service-bookings/:bookingId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getServiceBookingDetails),
  ResponseMiddleware,
);

adminRouter.put(
  "/service-bookings/:bookingId/status",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin", "support"),
  ErrorHandlerMiddleware(AdminController.updateServiceBookingStatus),
  ResponseMiddleware,
);

// ========== SERVICES MANAGEMENT ==========

adminRouter.get(
  "/services",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getServices),
  ResponseMiddleware,
);

adminRouter.post(
  "/services",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createService),
  ResponseMiddleware,
);

adminRouter.put(
  "/services/:serviceId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateService),
  ResponseMiddleware,
);

adminRouter.delete(
  "/services/:serviceId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteService),
  ResponseMiddleware,
);

// ========== SERVICE CATEGORIES (update & delete) ==========

adminRouter.put(
  "/service-categories/:categoryId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateServiceCategory),
  ResponseMiddleware,
);

adminRouter.delete(
  "/service-categories/:categoryId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteServiceCategory),
  ResponseMiddleware,
);

// ========== DELIVERIES ==========

adminRouter.get(
  "/deliveries",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDeliveries),
  ResponseMiddleware,
);

adminRouter.get(
  "/deliveries/:deliveryId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDeliveryDetails),
  ResponseMiddleware,
);

// ========== FAQ ==========

adminRouter.get(
  "/faqs",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getFaqs),
  ResponseMiddleware,
);

adminRouter.post(
  "/faqs",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createFaq),
  ResponseMiddleware,
);

adminRouter.put(
  "/faqs/:faqId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateFaq),
  ResponseMiddleware,
);

adminRouter.delete(
  "/faqs/:faqId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteFaq),
  ResponseMiddleware,
);

// ========== SUBSCRIPTION PLANS ==========

adminRouter.get(
  "/subscription-plans",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getSubscriptionPlans),
  ResponseMiddleware,
);

adminRouter.post(
  "/subscription-plans",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.createSubscriptionPlan),
  ResponseMiddleware,
);

adminRouter.put(
  "/subscription-plans/:planId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateSubscriptionPlan),
  ResponseMiddleware,
);

adminRouter.delete(
  "/subscription-plans/:planId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteSubscriptionPlan),
  ResponseMiddleware,
);

adminRouter.get(
  "/user-subscriptions",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getUserSubscriptions),
  ResponseMiddleware,
);

// ========== NOTIFICATIONS ==========

adminRouter.get(
  "/notifications",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getNotifications),
  ResponseMiddleware,
);

adminRouter.post(
  "/notifications/send",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.sendBulkNotification),
  ResponseMiddleware,
);

// ========== WALLET & TRANSACTIONS ==========

adminRouter.get(
  "/wallet/stats",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getWalletStats),
  ResponseMiddleware,
);

adminRouter.get(
  "/wallet/transactions",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getWalletTransactions),
  ResponseMiddleware,
);

// ========== SUPPORT TICKETS ==========

adminRouter.get(
  "/support-tickets/stats",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getSupportTicketStats),
  ResponseMiddleware,
);

adminRouter.get(
  "/support-tickets",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getSupportTickets),
  ResponseMiddleware,
);

adminRouter.get(
  "/support-tickets/:ticketId",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getSupportTicketById),
  ResponseMiddleware,
);

adminRouter.post(
  "/support-tickets/:ticketId/reply",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.replySupportTicket),
  ResponseMiddleware,
);

adminRouter.put(
  "/support-tickets/:ticketId/status",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.updateSupportTicketStatus),
  ResponseMiddleware,
);

// ========== FILE UPLOAD ==========

adminRouter.post(
  "/upload",
  AdminAuthMiddleware().verifyAdminToken,
  upload.array("files", 10),
  ErrorHandlerMiddleware(AdminController.uploadFile),
  ResponseMiddleware,
);

adminRouter.post(
  "/upload/single",
  AdminAuthMiddleware().verifyAdminToken,
  upload.single("file"),
  ErrorHandlerMiddleware(AdminController.uploadFile),
  ResponseMiddleware,
);

// ========== VEHICLE CATEGORY EXTENDED ==========

adminRouter.put(
  "/vehicle-categories/:categoryId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateVehicleCategory),
  ResponseMiddleware,
);

adminRouter.delete(
  "/vehicle-categories/:categoryId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteVehicleCategory),
  ResponseMiddleware,
);

adminRouter.delete(
  "/vehicle-types/:typeId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteVehicleType),
  ResponseMiddleware,
);

// ========== USER EXTENDED ==========

adminRouter.get(
  "/users/stats",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getUserStats),
  ResponseMiddleware,
);

adminRouter.delete(
  "/users/:userId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteUser),
  ResponseMiddleware,
);

// ========== DRIVER EXTENDED ==========

adminRouter.get(
  "/drivers/stats",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDriverStats),
  ResponseMiddleware,
);

adminRouter.get(
  "/drivers/:driverId/kyc",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDriverKyc),
  ResponseMiddleware,
);

adminRouter.get(
  "/drivers/:driverId/vehicle",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDriverVehicle),
  ResponseMiddleware,
);

adminRouter.put(
  "/drivers/:driverId/activate",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.activateDriver),
  ResponseMiddleware,
);

adminRouter.delete(
  "/drivers/:driverId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.deleteDriver),
  ResponseMiddleware,
);

// ========== ONLINE DRIVERS ==========

adminRouter.get(
  "/drivers/online",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getOnlineDrivers),
  ResponseMiddleware,
);

// ========== APP SETTINGS ==========

adminRouter.get(
  "/settings",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getAppSettings),
  ResponseMiddleware,
);

adminRouter.put(
  "/settings",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.updateAppSettings),
  ResponseMiddleware,
);

adminRouter.post(
  "/settings",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AdminController.addAppSetting),
  ResponseMiddleware,
);

adminRouter.delete(
  "/settings/:key",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AdminController.deleteAppSetting),
  ResponseMiddleware,
);

// ========== DASHBOARD KPIs ==========

adminRouter.get(
  "/dashboard/kpis",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDashboardKPIs),
  ResponseMiddleware,
);

// ========== EVENT TIMELINE ==========

adminRouter.get(
  "/dashboard/timeline",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getEventTimeline),
  ResponseMiddleware,
);

// ========== DRIVER PERFORMANCE ==========

adminRouter.get(
  "/drivers/:driverId/performance",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AdminController.getDriverPerformance),
  ResponseMiddleware,
);

// ========== GLOBAL SEARCH ==========

adminRouter.get(
  "/search",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(SearchController.globalSearch),
  ResponseMiddleware,
);

// ========== AUDIT LOGS ==========

adminRouter.get(
  "/audit-logs",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(AuditLogController.getAuditLogs),
  ResponseMiddleware,
);

adminRouter.get(
  "/audit-logs/export",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(AuditLogController.exportAuditLogs),
  ResponseMiddleware,
);

adminRouter.get(
  "/export-logs",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(AuditLogController.getExportLogs),
  ResponseMiddleware,
);

// ========== FINANCE & INSIGHTS ==========

adminRouter.get(
  "/finance/overview",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(FinanceController.getFinanceOverview),
  ResponseMiddleware,
);

adminRouter.get(
  "/finance/revenue-trend",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(FinanceController.getRevenueTrend),
  ResponseMiddleware,
);

adminRouter.get(
  "/finance/vehicle-breakdown",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(FinanceController.getRevenueByVehicleType),
  ResponseMiddleware,
);

adminRouter.get(
  "/finance/export",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  AdminAuthMiddleware().requirePermission("finance:export"),
  ErrorHandlerMiddleware(FinanceController.exportFinanceData),
  ResponseMiddleware,
);

// ========== ALERTS ==========

adminRouter.get(
  "/alerts/active",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AlertController.getActiveAlerts),
  ResponseMiddleware,
);

adminRouter.get(
  "/alerts",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AlertController.getAlerts),
  ResponseMiddleware,
);

adminRouter.put(
  "/alerts/:alertId/resolve",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(AlertController.resolveAlert),
  ResponseMiddleware,
);

adminRouter.post(
  "/alerts/check",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AlertController.checkAlerts),
  ResponseMiddleware,
);

// ========== AUTOMATION RULES ==========

adminRouter.get(
  "/automation-rules",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(AutomationController.getRules),
  ResponseMiddleware,
);

adminRouter.post(
  "/automation-rules",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AutomationController.createRule),
  ResponseMiddleware,
);

adminRouter.put(
  "/automation-rules/:ruleId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AutomationController.updateRule),
  ResponseMiddleware,
);

adminRouter.delete(
  "/automation-rules/:ruleId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AutomationController.deleteRule),
  ResponseMiddleware,
);

adminRouter.patch(
  "/automation-rules/:ruleId/toggle",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(AutomationController.toggleRule),
  ResponseMiddleware,
);

// ========== SURGE CONFIG ==========

adminRouter.get(
  "/surge-configs",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getSurgeConfigs),
  ResponseMiddleware,
);

adminRouter.post(
  "/surge-configs",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.createSurgeConfig),
  ResponseMiddleware,
);

adminRouter.put(
  "/surge-configs/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.updateSurgeConfig),
  ResponseMiddleware,
);

adminRouter.delete(
  "/surge-configs/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(ServiceConfigController.deleteSurgeConfig),
  ResponseMiddleware,
);

// ========== COMMISSION CONFIG ==========

adminRouter.get(
  "/commission-configs",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getCommissionConfigs),
  ResponseMiddleware,
);

adminRouter.post(
  "/commission-configs",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.createCommissionConfig),
  ResponseMiddleware,
);

adminRouter.put(
  "/commission-configs/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.updateCommissionConfig),
  ResponseMiddleware,
);

adminRouter.delete(
  "/commission-configs/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(ServiceConfigController.deleteCommissionConfig),
  ResponseMiddleware,
);

// ========== CANCELLATION POLICY ==========

adminRouter.get(
  "/cancellation-policies",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getCancellationPolicies),
  ResponseMiddleware,
);

adminRouter.post(
  "/cancellation-policies",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.createCancellationPolicy),
  ResponseMiddleware,
);

adminRouter.put(
  "/cancellation-policies/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.updateCancellationPolicy),
  ResponseMiddleware,
);

adminRouter.delete(
  "/cancellation-policies/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(ServiceConfigController.deleteCancellationPolicy),
  ResponseMiddleware,
);

// ========== DELIVERY PACKAGE TYPES ==========

adminRouter.get(
  "/delivery-package-types",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getDeliveryPackageTypes),
  ResponseMiddleware,
);

adminRouter.post(
  "/delivery-package-types",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.createDeliveryPackageType),
  ResponseMiddleware,
);

adminRouter.put(
  "/delivery-package-types/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.updateDeliveryPackageType),
  ResponseMiddleware,
);

adminRouter.delete(
  "/delivery-package-types/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(ServiceConfigController.deleteDeliveryPackageType),
  ResponseMiddleware,
);

// ========== SERVICE-SPECIFIC ANALYTICS ==========

adminRouter.get(
  "/analytics/cab",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getCabAnalytics),
  ResponseMiddleware,
);

adminRouter.get(
  "/analytics/delivery",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getDeliveryAnalytics),
  ResponseMiddleware,
);

adminRouter.get(
  "/analytics/household",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getHouseholdAnalytics),
  ResponseMiddleware,
);

// ========== HOUSEHOLD SERVICE HOURS ==========

adminRouter.get(
  "/household/service-hours",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(HouseholdController.getServiceHours),
  ResponseMiddleware,
);

adminRouter.put(
  "/household/service-hours",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(HouseholdController.updateServiceHours),
  ResponseMiddleware,
);

// ========== HOUSEHOLD BOOKING TYPE PRICING (Single / Multiple) ==========

adminRouter.get(
  "/household/booking-types",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(HouseholdController.getBookingTypeConfigs),
  ResponseMiddleware,
);

adminRouter.put(
  "/household/booking-types/:bookingType",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(HouseholdController.updateBookingTypeConfig),
  ResponseMiddleware,
);

// ========== SERVICE PROVIDER ACTIONS ==========

adminRouter.put(
  "/service-providers/:providerId/reject",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.rejectServiceProvider),
  ResponseMiddleware,
);

adminRouter.put(
  "/service-providers/:providerId/suspend",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.suspendServiceProvider),
  ResponseMiddleware,
);

adminRouter.put(
  "/service-providers/:providerId/activate",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.activateServiceProvider),
  ResponseMiddleware,
);

// ========== SERVICE PACKAGES ==========

adminRouter.get(
  "/service-packages",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ServiceConfigController.getServicePackages),
  ResponseMiddleware,
);

adminRouter.post(
  "/service-packages",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.createServicePackage),
  ResponseMiddleware,
);

adminRouter.put(
  "/service-packages/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ServiceConfigController.updateServicePackage),
  ResponseMiddleware,
);

adminRouter.delete(
  "/service-packages/:id",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin"),
  ErrorHandlerMiddleware(ServiceConfigController.deleteServicePackage),
  ResponseMiddleware,
);

// ========== PAYOUTS ==========

adminRouter.get(
  "/payouts",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(ServiceConfigController.getPayouts),
  ResponseMiddleware,
);

adminRouter.get(
  "/payouts/summary",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(ServiceConfigController.getPayoutSummary),
  ResponseMiddleware,
);

adminRouter.post(
  "/payouts/process",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(ServiceConfigController.processPayouts),
  ResponseMiddleware,
);

adminRouter.post(
  "/payouts/complete",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "finance"),
  ErrorHandlerMiddleware(ServiceConfigController.completePayouts),
  ResponseMiddleware,
);

// ========== SCRATCH CARDS ==========

adminRouter.get(
  "/scratch-cards",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(ScratchCardController.adminListScratchCards),
  ResponseMiddleware,
);

adminRouter.post(
  "/scratch-cards",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ScratchCardController.adminCreateScratchCard),
  ResponseMiddleware,
);

adminRouter.delete(
  "/scratch-cards/:cardId",
  AdminAuthMiddleware().verifyAdminToken,
  AdminAuthMiddleware().requireRole("super_admin", "admin"),
  ErrorHandlerMiddleware(ScratchCardController.adminDeleteScratchCard),
  ResponseMiddleware,
);

export default adminRouter;
