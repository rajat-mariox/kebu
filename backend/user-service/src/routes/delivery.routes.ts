import { Router } from "express";

import * as DeliveryController from "../controllers/delivery.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";
import DeliveryValidator from "../validators/delivery.validator";

const deliveryRouter = Router();

/**
 * Get available delivery (cargo) vehicle types
 */
deliveryRouter.get(
  "/vehicle-types",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(DeliveryController.getDeliveryVehicleTypes),
  ResponseMiddleware,
);

/**
 * Get fare estimate
 */
deliveryRouter.post(
  "/fare-estimate",
  AuthMiddleware().verifyUserToken,
  DeliveryValidator().validateFareEstimate,
  ErrorHandlerMiddleware(DeliveryController.getFareEstimate),
  ResponseMiddleware,
);

/**
 * Create delivery
 */
deliveryRouter.post(
  "/",
  AuthMiddleware().verifyUserToken,
  DeliveryValidator().validateCreateDelivery,
  ErrorHandlerMiddleware(DeliveryController.createDelivery),
  ResponseMiddleware,
);

/**
 * Get active delivery
 */
deliveryRouter.get(
  "/active",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(DeliveryController.getActiveDelivery),
  ResponseMiddleware,
);

/**
 * Get delivery history
 */
deliveryRouter.get(
  "/history",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(DeliveryController.getUserDeliveries),
  ResponseMiddleware,
);

/**
 * Get delivery details
 */
deliveryRouter.get(
  "/:deliveryId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(DeliveryController.getDeliveryDetails),
  ResponseMiddleware,
);

/**
 * Track delivery
 */
deliveryRouter.get(
  "/:deliveryId/track",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(DeliveryController.trackDelivery),
  ResponseMiddleware,
);

/**
 * Cancel delivery
 */
deliveryRouter.put(
  "/:deliveryId/cancel",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(DeliveryController.cancelDelivery),
  ResponseMiddleware,
);

/**
 * Rate delivery
 */
deliveryRouter.post(
  "/:deliveryId/rate",
  AuthMiddleware().verifyUserToken,
  DeliveryValidator().validateRating,
  ErrorHandlerMiddleware(DeliveryController.rateDelivery),
  ResponseMiddleware,
);

export default deliveryRouter;
