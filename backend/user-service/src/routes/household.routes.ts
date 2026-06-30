import { Router } from "express";

import * as HouseholdController from "../controllers/household.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";
import DriverAuthMiddleware from "../middlewares/driver-auth.middleware";
import HouseholdValidator from "../validators/household.validator";
import upload from "../middlewares/upload.middleware";

const householdRouter = Router();

/**
 * Get all service categories
 */
householdRouter.get(
  "/categories",
  ErrorHandlerMiddleware(HouseholdController.getCategories),
  ResponseMiddleware,
);

/**
 * Get providers by category
 */
householdRouter.get(
  "/categories/:categoryId/providers",
  ErrorHandlerMiddleware(HouseholdController.getProvidersByCategory),
  ResponseMiddleware,
);

/**
 * Get count of active experts near a location (public)
 */
householdRouter.get(
  "/active-experts",
  ErrorHandlerMiddleware(HouseholdController.getActiveExpertsCount),
  ResponseMiddleware,
);

/**
 * Find nearby providers
 */
householdRouter.post(
  "/providers/nearby",
  AuthMiddleware().verifyUserToken,
  HouseholdValidator().validateNearbySearch,
  ErrorHandlerMiddleware(HouseholdController.findNearbyProviders),
  ResponseMiddleware,
);

/**
 * Get provider details
 */
householdRouter.get(
  "/providers/:providerId",
  ErrorHandlerMiddleware(HouseholdController.getProviderDetails),
  ResponseMiddleware,
);

/**
 * Create service booking
 */
householdRouter.post(
  "/booking",
  AuthMiddleware().verifyUserToken,
  HouseholdValidator().validateCreateBooking,
  ErrorHandlerMiddleware(HouseholdController.createBooking),
  ResponseMiddleware,
);

/**
 * Get active booking
 */
householdRouter.get(
  "/booking/active",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.getActiveBooking),
  ResponseMiddleware,
);

/**
 * Get user's booking history
 */
householdRouter.get(
  "/bookings",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.getUserBookings),
  ResponseMiddleware,
);

/**
 * Provider/Driver lists available (PENDING, unassigned) bookings they can take.
 * A reliable fallback to the live socket broadcast. Registered before the
 * `/booking/:bookingId` route so "available" isn't read as a booking id.
 */
householdRouter.get(
  "/booking/available",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.getAvailableServiceBookings),
  ResponseMiddleware,
);

/**
 * Get booking details
 */
householdRouter.get(
  "/booking/:bookingId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.getBookingDetails),
  ResponseMiddleware,
);

/**
 * Cancel booking
 */
householdRouter.put(
  "/booking/:bookingId/cancel",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.cancelBooking),
  ResponseMiddleware,
);

/**
 * "Search again" — re-broadcast a still-PENDING booking to online partners so
 * the customer can keep searching for another round (instead of auto-cancel).
 */
householdRouter.post(
  "/booking/:bookingId/search-again",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.searchAgainServiceBooking),
  ResponseMiddleware,
);

/**
 * Provider/Driver accepts a pending booking
 */
householdRouter.post(
  "/booking/:bookingId/accept",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.acceptServiceBooking),
  ResponseMiddleware,
);

/**
 * Provider/Driver re-opens a booking they're handling (resume from "On Going").
 */
householdRouter.get(
  "/booking/:bookingId/provider-detail",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.getProviderBookingDetail),
  ResponseMiddleware,
);

/**
 * Provider/Driver cancels a booking they're handling.
 */
householdRouter.post(
  "/booking/:bookingId/provider-cancel",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.providerCancelServiceBooking),
  ResponseMiddleware,
);

/**
 * Provider/Driver updates booking status (en-route / arrived / in-progress /
 * completed) while handling a booking.
 */
householdRouter.put(
  "/booking/:bookingId/provider-status",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.updateProviderBookingStatus),
  ResponseMiddleware,
);

/**
 * Provider uploads the start-of-service photos and starts the service
 * (marks the booking IN_PROGRESS).
 */
householdRouter.post(
  "/booking/:bookingId/start",
  DriverAuthMiddleware().verifyDriverToken,
  upload.fields([
    { name: "selfie", maxCount: 1 },
    { name: "devicePhoto", maxCount: 1 },
    { name: "serialPhoto", maxCount: 1 },
    { name: "otherPhoto", maxCount: 1 },
  ]),
  ErrorHandlerMiddleware(HouseholdController.startServiceBooking),
  ResponseMiddleware,
);

/**
 * Provider updates the booking's extra charge while the work is in progress.
 */
householdRouter.put(
  "/booking/:bookingId/extra-amount",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.updateBookingExtraAmount),
  ResponseMiddleware,
);

/**
 * Provider ends the work — uploads the finished-work photo (+ optional extra
 * amount) and marks the booking COMPLETED.
 */
/**
 * Provider/Driver confirms collected payment (cash) → marks booking PAID.
 */
householdRouter.post(
  "/booking/:bookingId/payment-received",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.markServicePaymentReceived),
  ResponseMiddleware,
);

householdRouter.post(
  "/booking/:bookingId/complete",
  DriverAuthMiddleware().verifyDriverToken,
  upload.fields([{ name: "finishedPhoto", maxCount: 1 }]),
  ErrorHandlerMiddleware(HouseholdController.completeServiceBooking),
  ResponseMiddleware,
);

/**
 * Rate service
 */
householdRouter.post(
  "/booking/:bookingId/rate",
  AuthMiddleware().verifyUserToken,
  HouseholdValidator().validateRating,
  ErrorHandlerMiddleware(HouseholdController.rateService),
  ResponseMiddleware,
);

// ============ SERVICE PACKAGES ============

/**
 * Get service packages (1 hr, 1.5 hr, 2 hr) by category
 */
householdRouter.get(
  "/categories/:categoryId/packages",
  ErrorHandlerMiddleware(HouseholdController.getServicePackages),
  ResponseMiddleware,
);

// ============ TIME SLOTS ============

/**
 * Get available time slots for a date
 */
householdRouter.get(
  "/categories/:categoryId/time-slots",
  ErrorHandlerMiddleware(HouseholdController.getAvailableTimeSlots),
  ResponseMiddleware,
);

// ============ SERVICE TYPES (Inclusions/Exclusions) ============

/**
 * Get all service types for a category (Everyday Cleaning, Weekly Cleaning, etc.)
 */
householdRouter.get(
  "/categories/:categoryId/service-types",
  ErrorHandlerMiddleware(HouseholdController.getServiceTypes),
  ResponseMiddleware,
);

/**
 * Get detailed info for a specific service type
 */
householdRouter.get(
  "/categories/:categoryId/service-types/:serviceSlug",
  ErrorHandlerMiddleware(HouseholdController.getServiceTypeDetails),
  ResponseMiddleware,
);

// ============ MULTIPLE BOOKING / PRE-BOOK ============

/**
 * Get available dates for multiple booking
 */
householdRouter.get(
  "/categories/:categoryId/available-dates",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.getAvailableDates),
  ResponseMiddleware,
);

/**
 * Get booking fare estimate
 */
householdRouter.post(
  "/booking/estimate",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.getBookingEstimate),
  ResponseMiddleware,
);

/**
 * Create multiple/recurring booking (Pre-book)
 */
householdRouter.post(
  "/booking/multiple",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(HouseholdController.createMultipleBooking),
  ResponseMiddleware,
);

/**
 * Get starter pack offers for household services
 */
householdRouter.get(
  "/categories/:categoryId/starter-packs",
  ErrorHandlerMiddleware(HouseholdController.getStarterPacks),
  ResponseMiddleware,
);

/**
 * Get household service operating hours + open/closed status (public)
 */
householdRouter.get(
  "/service-hours",
  ErrorHandlerMiddleware(HouseholdController.getServiceHours),
  ResponseMiddleware,
);

/**
 * Get admin-configured pricing for SINGLE / MULTIPLE pre-book booking tiles
 */
householdRouter.get(
  "/booking-types",
  ErrorHandlerMiddleware(HouseholdController.getBookingTypeConfigs),
  ResponseMiddleware,
);

export default householdRouter;
