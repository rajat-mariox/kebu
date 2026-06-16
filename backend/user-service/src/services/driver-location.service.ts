import DriverLocation from "../models/driver-location.model";
import Driver from "../models/driver.model";
import { IDriverLocation } from "../interfaces/driver-location";
import { Types } from "mongoose";

/**
 * Update driver location
 */
export const updateDriverLocation = async (
  driverId: Types.ObjectId,
  latitude: number,
  longitude: number,
  heading?: number,
  speed?: number
) => {
  // Guard: skip if coordinates are invalid
  if (latitude == null || longitude == null || isNaN(latitude) || isNaN(longitude)) {
    console.warn(`[DriverLocation] Invalid coordinates for driver ${driverId}: lat=${latitude}, lng=${longitude}`);
    return null;
  }

  try {
    return await DriverLocation.findOneAndUpdate(
      { driverId },
      {
        location: {
          type: "Point",
          coordinates: [longitude, latitude], // [lng, lat] for GeoJSON
        },
        latitude,
        longitude,
        heading,
        speed,
      },
      { upsert: true, new: true }
    );
  } catch (err: any) {
    // If existing doc has corrupted coordinates, delete and retry
    if (err.code === 16755) {
      console.warn(`[DriverLocation] Removing corrupted location doc for driver ${driverId}`);
      await DriverLocation.deleteOne({ driverId });
      return await DriverLocation.create({
        driverId,
        location: { type: "Point", coordinates: [longitude, latitude] },
        latitude,
        longitude,
        heading,
        speed,
      });
    }
    throw err;
  }
};

/**
 * Get driver location
 */
export const getDriverLocation = async (driverId: Types.ObjectId) => {
  return await DriverLocation.findOne({ driverId }).select("-__v");
};

/**
 * Find nearby drivers
 * @param latitude - Center latitude
 * @param longitude - Center longitude
 * @param maxDistanceKm - Maximum distance in kilometers
 * @param vehicleTypeId - Optional vehicle type filter
 * @param serviceType - Optional vendor type filter ("cab" | "cleaning" | "parcel")
 * @param householdCategoryId - Optional household service category filter (only meaningful when serviceType === "cleaning")
 */
export const findNearbyDrivers = async (
  latitude: number,
  longitude: number,
  maxDistanceKm: number = 5,
  vehicleTypeId?: Types.ObjectId,
  serviceType?: "cab" | "cleaning" | "parcel",
  householdCategoryId?: Types.ObjectId
) => {
  // Drivers ping location every 5 min; hide ones whose last update is older than this threshold
  const LOCATION_FRESHNESS_MS = 10 * 60 * 1000;
  const freshnessCutoff = new Date(Date.now() - LOCATION_FRESHNESS_MS);

  // First get nearby driver locations using geospatial query
  const nearbyLocations = await DriverLocation.find({
    location: {
      $near: {
        $geometry: {
          type: "Point",
          coordinates: [longitude, latitude],
        },
        $maxDistance: maxDistanceKm * 1000, // Convert km to meters
      },
    },
    updatedAt: { $gte: freshnessCutoff },
  }).limit(50);

  const driverIds = nearbyLocations.map((loc) => loc.driverId);

  // Get available drivers from the nearby list
  const query: any = {
    _id: { $in: driverIds },
    isOnline: true,
    status: "approved",
    isActive: true,
    isDeleted: false,
    currentBookingId: null,
  };

  if (serviceType) {
    query.serviceType = serviceType;
  }

  if (householdCategoryId) {
    query.householdCategories = householdCategoryId;
  }

  // If vehicle type is specified, filter by it
  if (vehicleTypeId) {
    const DriverVehicle = require("../models/driver-vehicle.model").default;
    const vehicles = await DriverVehicle.find({
      driverId: { $in: driverIds },
      vehicleTypeId,
      isActive: true,
      isOnline: true,
    });

    const vehicleDriverIds = vehicles.map((v: any) => v.driverId);
    query._id = { $in: vehicleDriverIds };
  }

  const drivers = await Driver.find(query).select("-__v").limit(20);

  // Combine driver data with location data
  return drivers.map((driver) => {
    const location = nearbyLocations.find(
      (loc) => loc.driverId.toString() === driver._id.toString()
    );

    return {
      driver,
      location: location
        ? {
            latitude: location.latitude,
            longitude: location.longitude,
            heading: location.heading,
            speed: location.speed,
          }
        : null,
    };
  });
};

/**
 * Delete driver location
 */
export const deleteDriverLocation = async (driverId: Types.ObjectId) => {
  return await DriverLocation.deleteOne({ driverId });
};
