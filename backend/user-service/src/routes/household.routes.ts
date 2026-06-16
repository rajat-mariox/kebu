import { Router } from "express";

import * as HouseholdController from "../controllers/household.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";
import DriverAuthMiddleware from "../middlewares/driver-auth.middleware";
import HouseholdValidator from "../validators/household.validator";

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
 * Provider/Driver accepts a pending booking
 */
householdRouter.post(
  "/booking/:bookingId/accept",
  DriverAuthMiddleware().verifyDriverToken,
  ErrorHandlerMiddleware(HouseholdController.acceptServiceBooking),
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
