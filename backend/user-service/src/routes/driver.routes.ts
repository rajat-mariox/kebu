import { Router } from "express";

import * as DriverController from "../controllers/driver.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import DriverAuthMiddleware from "../middlewares/driver-auth.middleware";
import upload from "../middlewares/upload.middleware";

const driverRouter = Router();

/**
 * Dashboard
 */
driverRouter.get(
  "/dashboard",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getDashboard),
  ResponseMiddleware,
);

/**
 * Toggle online/offline
 */
driverRouter.put(
  "/status",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.toggleOnlineStatus),
  ResponseMiddleware,
);

/**
 * Update location
 */
driverRouter.put(
  "/location",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.updateLocation),
  ResponseMiddleware,
);

/**
 * Get active booking
 */
driverRouter.get(
  "/booking/active",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getActiveBooking),
  ResponseMiddleware,
);

/**
 * Get booking history
 */
driverRouter.get(
  "/bookings",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getBookingHistory),
  ResponseMiddleware,
);

/**
 * Get earnings
 */
driverRouter.get(
  "/earnings",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getEarnings),
  ResponseMiddleware,
);

/**
 * Get a single booking by id (driver-authenticated)
 */
driverRouter.get(
  "/booking/:bookingId",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getBookingById),
  ResponseMiddleware,
);

/**
 * Accept ride
 */
driverRouter.post(
  "/booking/:bookingId/accept",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.acceptRide),
  ResponseMiddleware,
);

/**
 * Update ride status (arrived, picked, started, completed)
 */
driverRouter.put(
  "/booking/:bookingId/status",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.updateRideStatus),
  ResponseMiddleware,
);

/**
 * Cancel ride
 */
driverRouter.put(
  "/booking/:bookingId/cancel",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.cancelRide),
  ResponseMiddleware,
);

/**
 * Mark cash payment as collected (post-ride). Driver-only.
 */
driverRouter.put(
  "/booking/:bookingId/payment",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.markPaymentCollected),
  ResponseMiddleware,
);

/**
 * Get vehicle
 */
driverRouter.get(
  "/vehicle",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getVehicle),
  ResponseMiddleware,
);

/**
 * Onboarding - Basic details
 */
driverRouter.post(
  "/onboarding/basic-details",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveBasicDetails),
  ResponseMiddleware,
);

/**
 * Onboarding - Driving licence (with file uploads)
 */
driverRouter.post(
  "/onboarding/driving-licence",
  DriverAuthMiddleware().verifyDriverToken,
  upload.fields([
    { name: "frontImage", maxCount: 1 },
    { name: "backImage", maxCount: 1 },
  ]),
  ErrorHandlerMiddleware(DriverController.saveDrivingLicence),
  ResponseMiddleware,
);

/**
 * Onboarding - Documents (Aadhar + PAN with file uploads)
 */
driverRouter.post(
  "/onboarding/documents",
  DriverAuthMiddleware().verifyDriverToken,
  upload.fields([
    { name: "aadharFrontImage", maxCount: 1 },
    { name: "aadharBackImage", maxCount: 1 },
    { name: "panFrontImage", maxCount: 1 },
  ]),
  ErrorHandlerMiddleware(DriverController.saveDocuments),
  ResponseMiddleware,
);

/**
 * Onboarding - Address
 */
driverRouter.post(
  "/onboarding/address",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveAddress),
  ResponseMiddleware,
);

/**
 * Onboarding - Bank details
 */
driverRouter.post(
  "/onboarding/bank-details",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveBankDetails),
  ResponseMiddleware,
);

/**
 * Get vehicle types (for onboarding selection)
 */
driverRouter.get(
  "/vehicle-types",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getVehicleTypes),
  ResponseMiddleware,
);

/**
 * Onboarding - Vehicle details
 */
driverRouter.post(
  "/onboarding/vehicle-details",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveVehicleDetails),
  ResponseMiddleware,
);

/**
 * Upload vehicle images
 */
driverRouter.post(
  "/onboarding/vehicle-images",
  DriverAuthMiddleware().verifyDriverToken,
  upload.fields([
    { name: "selfieImage", maxCount: 1 },
    { name: "frontImage", maxCount: 1 },
    { name: "rightImage", maxCount: 1 },
    { name: "leftImage", maxCount: 1 },
    { name: "backImage", maxCount: 1 },
  ]),
  ErrorHandlerMiddleware(DriverController.uploadVehicleImages),
  ResponseMiddleware,
);

/**
 * Onboarding (household partner) - fetch backend-driven "Personal Details"
 * form schema (fields, dropdown options) + any saved values.
 */
driverRouter.get(
  "/onboarding/household/personal-info",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getHouseholdPersonalInfo),
  ResponseMiddleware,
);

/**
 * Onboarding (household partner) - save the "Personal Details" step.
 */
driverRouter.post(
  "/onboarding/household/personal-info",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveHouseholdPersonalInfo),
  ResponseMiddleware,
);

/**
 * Onboarding (cleaning vendor) - fetch service category tree
 */
driverRouter.get(
  "/onboarding/service-categories",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getOnboardingServiceCategories),
  ResponseMiddleware,
);

/**
 * Onboarding (cleaning vendor) - save selected service categories
 */
driverRouter.post(
  "/onboarding/service-categories",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveOnboardingServiceCategories),
  ResponseMiddleware,
);

/**
 * Upload profile image
 */
driverRouter.post(
  "/profile-image",
  DriverAuthMiddleware().verifyDriverToken,
  upload.fields([{ name: "profileImage", maxCount: 1 }]),
  ErrorHandlerMiddleware(DriverController.uploadProfileImage),
  ResponseMiddleware,
);

/**
 * Save preferred work hours
 */
driverRouter.put(
  "/work-hours",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.saveWorkHours),
  ResponseMiddleware,
);

// ============ DRIVER SUPPORT CHAT ============

/**
 * Create support ticket
 */
driverRouter.post(
  "/support/tickets",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.createSupportTicket),
  ResponseMiddleware,
);

/**
 * Get support tickets
 */
driverRouter.get(
  "/support/tickets",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getSupportTickets),
  ResponseMiddleware,
);

/**
 * Add message to ticket
 */
driverRouter.post(
  "/support/tickets/:ticketId/message",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.addTicketMessage),
  ResponseMiddleware,
);

/**
 * Distance & duration via Google Distance Matrix (driver-authenticated).
 * Used by ActiveRideScreen for distance to pickup/drop.
 */
driverRouter.get(
  "/distance",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getDistanceAndDuration),
  ResponseMiddleware,
);

/**
 * Driving route polyline (driver-authenticated). Returns the encoded
 * polyline + distance + duration so the active-ride map can draw the
 * actual driving path between origin and destination.
 */
driverRouter.get(
  "/route",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getRoute),
  ResponseMiddleware,
);

// ============ DRIVER WALLET ============

driverRouter.get(
  "/wallet",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getWallet),
  ResponseMiddleware,
);

driverRouter.get(
  "/wallet/transactions",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getWalletTransactions),
  ResponseMiddleware,
);

driverRouter.post(
  "/wallet/recharge",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.rechargeWallet),
  ResponseMiddleware,
);

driverRouter.post(
  "/wallet/send",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.sendFromWallet),
  ResponseMiddleware,
);

// ============ DRIVER NOTIFICATIONS ============

driverRouter.get(
  "/notifications",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.getNotifications),
  ResponseMiddleware,
);

driverRouter.put(
  "/notifications/:notificationId/read",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(DriverController.markNotificationRead),
  ResponseMiddleware,
);

export default driverRouter;
