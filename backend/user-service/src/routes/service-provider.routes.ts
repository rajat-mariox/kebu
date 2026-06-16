import { Router } from "express";

import * as ServiceProviderController from "../controllers/service-provider.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import ProviderAuthMiddleware from "../middlewares/provider-auth.middleware";

const providerRouter = Router();

// ========== AUTH ==========

/**
 * Login
 */
providerRouter.post(
  "/login",
  ErrorHandlerMiddleware(ServiceProviderController.providerLogin),
  ResponseMiddleware,
);

/**
 * Verify OTP
 */
providerRouter.post(
  "/verify-otp",
  ErrorHandlerMiddleware(ServiceProviderController.verifyProviderOtp),
  ResponseMiddleware,
);

/**
 * Resend OTP
 */
providerRouter.post(
  "/resend-otp",
  ErrorHandlerMiddleware(ServiceProviderController.resendProviderOtp),
  ResponseMiddleware,
);

// ========== PROFILE ==========

/**
 * Get Profile
 */
providerRouter.get(
  "/profile",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.getProviderDetails),
  ResponseMiddleware,
);

/**
 * Update Profile
 */
providerRouter.put(
  "/profile",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.updateProfile),
  ResponseMiddleware,
);

// ========== APP ==========

/**
 * Dashboard
 */
providerRouter.get(
  "/app/dashboard",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.getDashboard),
  ResponseMiddleware,
);

/**
 * Toggle Online Status
 */
providerRouter.put(
  "/app/status",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.toggleOnlineStatus),
  ResponseMiddleware,
);

/**
 * Update Location
 */
providerRouter.put(
  "/app/location",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.updateLocation),
  ResponseMiddleware,
);

/**
 * Get Active Booking
 */
providerRouter.get(
  "/app/booking/active",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.getActiveBooking),
  ResponseMiddleware,
);

/**
 * Get Booking History
 */
providerRouter.get(
  "/app/bookings",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.getBookingHistory),
  ResponseMiddleware,
);

/**
 * Accept Booking
 */
providerRouter.post(
  "/app/booking/:bookingId/accept",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.acceptBooking),
  ResponseMiddleware,
);

/**
 * Update Booking Status
 */
providerRouter.put(
  "/app/booking/:bookingId/status",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.updateBookingStatus),
  ResponseMiddleware,
);

/**
 * Cancel Booking
 */
providerRouter.put(
  "/app/booking/:bookingId/cancel",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.cancelBooking),
  ResponseMiddleware,
);

/**
 * Get Earnings
 */
providerRouter.get(
  "/app/earnings",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.getEarnings),
  ResponseMiddleware,
);

/**
 * Logout
 */
providerRouter.post(
  "/logout",
  ProviderAuthMiddleware().verifyProviderToken,
  ErrorHandlerMiddleware(ServiceProviderController.providerLogout),
  ResponseMiddleware,
);

export default providerRouter;
