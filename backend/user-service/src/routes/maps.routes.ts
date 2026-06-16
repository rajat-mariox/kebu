import { Router } from "express";

import * as MapsController from "../controllers/maps.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";

const mapsRouter = Router();

/**
 * Search places (autocomplete)
 */
mapsRouter.get(
  "/places/search",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(MapsController.searchPlaces),
  ResponseMiddleware,
);

/**
 * Get place details
 */
mapsRouter.get(
  "/places/:placeId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(MapsController.getPlaceDetails),
  ResponseMiddleware,
);

/**
 * Reverse geocode
 */
mapsRouter.get(
  "/geocode/reverse",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(MapsController.reverseGeocode),
  ResponseMiddleware,
);

/**
 * Get distance and duration
 */
mapsRouter.get(
  "/distance",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(MapsController.getDistanceAndDuration),
  ResponseMiddleware,
);

/**
 * Get directions
 */
mapsRouter.post(
  "/directions",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(MapsController.getDirections),
  ResponseMiddleware,
);

/**
 * Get driving route polyline via query params (customer-authenticated).
 * Used by the live ride-tracking screen to draw the road path.
 */
mapsRouter.get(
  "/route",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(MapsController.getRoute),
  ResponseMiddleware,
);

export default mapsRouter;
