import { Request, Response, NextFunction } from "express";

import * as MapsService from "../services/maps.service";

/**
 * Search places (autocomplete)
 */
export const searchPlaces = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("MapsController => searchPlaces");

  const { query, lat, lng } = req.query;

  const location =
    lat && lng ? { lat: Number(lat), lng: Number(lng) } : undefined;

  const predictions = await MapsService.searchPlaces(query as string, location);

  req.rData = { predictions };
  req.msg = "success";
  next();
};

/**
 * Get place details
 */
export const getPlaceDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("MapsController => getPlaceDetails");

  const { placeId } = req.params;

  const place = await MapsService.getPlaceDetails(placeId);

  if (!place) {
    req.rCode = 5;
    req.msg = "place_not_found";
    return next();
  }

  req.rData = { place };
  req.msg = "success";
  next();
};

/**
 * Reverse geocode
 */
export const reverseGeocode = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("MapsController => reverseGeocode");

  const { lat, lng } = req.query;

  const result = await MapsService.reverseGeocode(Number(lat), Number(lng));

  // Support both structured object and plain string
  if (typeof result === 'object' && result !== null) {
    req.rData = {
      address: result.display_name || '',
      houseNo: result.houseNo || '',
      area: result.area || '',
      city: result.city || '',
      state: result.state || '',
      country: result.country || '',
      pinCode: result.pinCode || '',
    };
  } else {
    req.rData = { address: result };
  }

  req.msg = "success";
  next();
};

/**
 * Get distance and duration
 */
export const getDistanceAndDuration = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("MapsController => getDistanceAndDuration");

  const { originLat, originLng, destLat, destLng } = req.query;

  const routeInfo = await MapsService.getDistanceAndDuration(
    { lat: Number(originLat), lng: Number(originLng) },
    { lat: Number(destLat), lng: Number(destLng) },
  );

  req.rData = routeInfo;
  req.msg = "success";
  next();
};

/**
 * Get directions
 */
export const getDirections = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("MapsController => getDirections");

  const { originLat, originLng, destLat, destLng, waypoints } = req.body;

  const directions = await MapsService.getDirections(
    { lat: originLat, lng: originLng },
    { lat: destLat, lng: destLng },
    waypoints,
  );

  if (!directions) {
    req.rCode = 0;
    req.msg = "directions_not_available";
    return next();
  }

  req.rData = directions;
  req.msg = "success";
  next();
};

/**
 * Get driving route via lat/lng query params. Identical payload to
 * getDirections but as a GET so the customer ride-tracking screen can
 * fetch + cache it cheaply during live tracking.
 */
export const getRoute = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("MapsController => getRoute");

  const { originLat, originLng, destLat, destLng } = req.query;

  const o = { lat: Number(originLat), lng: Number(originLng) };
  const d = { lat: Number(destLat), lng: Number(destLng) };

  if (!isFinite(o.lat) || !isFinite(o.lng) || !isFinite(d.lat) || !isFinite(d.lng)) {
    return res.status(400).json({ code: 0, message: "Invalid coordinates", data: {} });
  }

  const directions = await MapsService.getDirections(o, d);
  if (!directions) {
    req.rCode = 0;
    req.msg = "directions_not_available";
    return next();
  }

  const km = directions.totalDistanceKm;
  req.rData = {
    polyline: directions.polyline,
    distanceKm: km,
    distanceMeters: Math.round(km * 1000),
    durationMin: directions.totalDurationMin,
  };
  req.msg = "success";
  next();
};
