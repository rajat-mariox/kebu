import { Router } from "express";

import * as BookingController from "../controllers/booking.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";
import BookingValidator from "../validators/booking.validator";

const bookingRouter = Router();

/**
 * Get fare estimate for single vehicle type
 */
bookingRouter.post(
  "/fare-estimate",
  AuthMiddleware().verifyUserToken,
  BookingValidator().validateFareEstimate,
  ErrorHandlerMiddleware(BookingController.getFareEstimate),
  ResponseMiddleware,
);

/**
 * Get fare estimates for all vehicle types
 */
bookingRouter.post(
  "/fare-estimates",
  AuthMiddleware().verifyUserToken,
  BookingValidator().validateFareEstimateAll,
  ErrorHandlerMiddleware(BookingController.getAllFareEstimates),
  ResponseMiddleware,
);

/**
 * Create new booking
 */
bookingRouter.post(
  "/",
  AuthMiddleware().verifyUserToken,
  BookingValidator().validateCreateBooking,
  ErrorHandlerMiddleware(BookingController.createBooking),
  ResponseMiddleware,
);

/**
 * Get user's active booking
 */
bookingRouter.get(
  "/active",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(BookingController.getActiveBooking),
  ResponseMiddleware,
);

/**
 * Get user's booking history
 */
bookingRouter.get(
  "/history",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(BookingController.getUserBookings),
  ResponseMiddleware,
);

/**
 * Get nearby available drivers
 */
bookingRouter.get(
  "/nearby-drivers",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(BookingController.getNearbyDrivers),
  ResponseMiddleware,
);

/**
 * Get booking details
 */
bookingRouter.get(
  "/:bookingId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(BookingController.getBookingDetails),
  ResponseMiddleware,
);

/**
 * Track booking (get driver location, ETA)
 */
bookingRouter.get(
  "/:bookingId/track",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(BookingController.trackBooking),
  ResponseMiddleware,
);

/**
 * Cancel booking
 */
bookingRouter.put(
  "/:bookingId/cancel",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(BookingController.cancelBooking),
  ResponseMiddleware,
);

/**
 * Rate booking
 */
bookingRouter.post(
  "/:bookingId/rate",
  AuthMiddleware().verifyUserToken,
  BookingValidator().validateRating,
  ErrorHandlerMiddleware(BookingController.rateBooking),
  ResponseMiddleware,
);

export default bookingRouter;
