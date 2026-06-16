import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import * as DeliveryService from "../services/delivery.service";
import * as DriverLocationService from "../services/driver-location.service";
import * as VehicleTypeService from "../services/vehicle-type.service";
import * as MapsService from "../services/maps.service";
import * as SubscriptionBenefitsService from "../services/subscription-benefits.service";
import helpers from "../utils/helpers";

/**
 * Get available delivery (cargo) vehicle types for the customer
 */
export const getDeliveryVehicleTypes = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => getDeliveryVehicleTypes");

  const vehicleTypes =
    await VehicleTypeService.getVehicleTypesByCategoryCodes(["CARGO"]);

  req.rData = { vehicleTypes };
  req.msg = "success";
  next();
};

/**
 * Get delivery fare estimate
 */
export const getFareEstimate = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => getFareEstimate");

  const { pickup, drops, vehicleTypeId } = req.body;

  // Calculate total distance through all stops
  let totalDistanceKm = 0;
  let totalDurationMin = 0;

  // First leg: pickup to first drop
  let currentPoint = pickup;

  for (const drop of drops) {
    const routeInfo = await MapsService.getDistanceAndDuration(
      { lat: currentPoint.lat, lng: currentPoint.lng },
      { lat: drop.lat, lng: drop.lng },
    );

    totalDistanceKm += routeInfo.distanceKm;
    totalDurationMin += routeInfo.durationMin;
    currentPoint = drop;
  }

  // Get vehicle type
  const vehicleType =
    await VehicleTypeService.getVehicleTypeById(vehicleTypeId);

  if (!vehicleType) {
    req.rCode = 0;
    req.msg = "invalid_vehicle_type";
    return next();
  }

  // Calculate fare with multi-stop
  const fare = await DeliveryService.calculateMultiStopFare(
    vehicleType,
    totalDistanceKm,
    totalDurationMin,
    drops.length,
  );

  req.rData = {
    totalDistanceKm: Math.round(totalDistanceKm * 100) / 100,
    totalDurationMin,
    numberOfStops: drops.length,
    ...fare,
    vehicleType: {
      _id: vehicleType._id,
      name: vehicleType.name,
      image: vehicleType.image,
    },
  };

  req.msg = "fare_estimated";
  next();
};

/**
 * Create delivery booking
 */
export const createDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => createDelivery");

  const userId = (req as any).userId;
  const {
    pickup,
    drops,
    vehicleTypeId,
    deliveryType,
    deliveryMode,
    workers,
    packageDescription,
    packageWeight,
    packageSize,
    paymentMethod,
    proofOfDelivery,
    scheduledAt,
  } = req.body;

  // A scheduled delivery must carry a pickup date/time.
  if (deliveryMode === "SCHEDULED" && !scheduledAt) {
    req.rCode = 0;
    req.msg = "scheduled_at_required";
    return next();
  }

  // Check for active delivery
  const activeDelivery = await DeliveryService.getActiveUserDelivery(userId);
  if (activeDelivery) {
    req.rCode = 0;
    req.msg = "active_delivery_exists";
    return next();
  }

  // Calculate total distance
  let totalDistanceKm = 0;
  let totalDurationMin = 0;
  let currentPoint = pickup;

  for (const drop of drops) {
    const routeInfo = await MapsService.getDistanceAndDuration(
      { lat: currentPoint.lat, lng: currentPoint.lng },
      { lat: drop.lat, lng: drop.lng },
    );

    totalDistanceKm += routeInfo.distanceKm;
    totalDurationMin += routeInfo.durationMin;
    currentPoint = drop;
  }

  // Get vehicle type
  const vehicleType =
    await VehicleTypeService.getVehicleTypeById(vehicleTypeId);
  if (!vehicleType) {
    req.rCode = 0;
    req.msg = "invalid_vehicle_type";
    return next();
  }

  // Calculate fare
  const fareDetails = await DeliveryService.calculateMultiStopFare(
    vehicleType,
    totalDistanceKm,
    totalDurationMin,
    drops.length,
  );

  // Apply Kebu Pass benefits: free delivery first (atomic counter), else %-discount
  const benefits = await SubscriptionBenefitsService.getActiveBenefits(userId);
  let freeDeliveryApplied = false;
  let subscriptionDiscount = 0;
  let appliedFinalFare = fareDetails.finalFare;
  let appliedDiscount = fareDetails.discount;

  if (
    benefits &&
    (benefits.unlimitedDeliveries || benefits.freeDeliveriesRemaining > 0)
  ) {
    const claimed = await SubscriptionBenefitsService.consumeFreeDelivery(benefits);
    if (claimed) {
      freeDeliveryApplied = true;
      subscriptionDiscount = Math.max(0, fareDetails.finalFare);
      appliedDiscount = fareDetails.discount + subscriptionDiscount;
      appliedFinalFare = 0;
    }
  }

  if (!freeDeliveryApplied) {
    const extraDiscount = SubscriptionBenefitsService.computeSubscriptionDiscount(
      fareDetails.finalFare,
      benefits,
    );
    if (extraDiscount > 0) {
      subscriptionDiscount = extraDiscount;
      appliedDiscount = fareDetails.discount + extraDiscount;
      appliedFinalFare = Math.max(fareDetails.finalFare - extraDiscount, 0);
    }
  }

  // Generate delivery OTP
  const deliveryOtp = helpers().generateOTP(4).toString();

  // Format drops
  const formattedDrops = drops.map((drop: any) => ({
    address: drop.address,
    lat: drop.lat,
    lng: drop.lng,
    contactName: drop.contactName,
    contactPhone: drop.contactPhone,
    instructions: drop.instructions,
    status: "PENDING",
  }));

  // Create delivery
  const delivery = await DeliveryService.createDelivery({
    userId,
    vehicleTypeId: new Types.ObjectId(vehicleTypeId),
    deliveryType: deliveryType || "PARCEL",
    deliveryMode: deliveryMode || "INSTANT",
    workers: typeof workers === "number" ? workers : 0,
    packageDescription,
    packageWeight,
    packageSize,
    pickup: {
      address: pickup.address,
      lat: pickup.lat,
      lng: pickup.lng,
      contactName: pickup.contactName,
      contactPhone: pickup.contactPhone,
      instructions: pickup.instructions,
    },
    drops: formattedDrops,
    totalDistanceKm,
    totalDurationMin,
    fare:
      fareDetails.baseFare +
      fareDetails.distanceFare +
      fareDetails.timeFare +
      fareDetails.extraStopCharge,
    surgeFare: fareDetails.surgeFare,
    discount: appliedDiscount,
    subscriptionDiscount: subscriptionDiscount > 0 ? subscriptionDiscount : 0,
    subscriptionPlanName:
      subscriptionDiscount > 0 || freeDeliveryApplied
        ? benefits?.planName
        : undefined,
    freeDeliveryApplied,
    finalFare: appliedFinalFare,
    paymentMethod: paymentMethod || "CASH",
    proofOfDelivery: proofOfDelivery || "OTP",
    otp: deliveryOtp,
    status: "SEARCHING",
    scheduledAt: scheduledAt ? new Date(scheduledAt) : undefined,
  });

  // Find nearby drivers
  const io = req.app.get("io");
  if (io) {
    const nearbyDrivers = await DriverLocationService.findNearbyDrivers(
      pickup.lat,
      pickup.lng,
      5,
      undefined,
      "parcel",
    );

    nearbyDrivers.forEach(({ driver }) => {
      io.to(`driver_${driver._id}`).emit("new_delivery_request", {
        deliveryId: delivery._id,
        pickup: delivery.pickup,
        drops: delivery.drops,
        fare: delivery.finalFare,
        deliveryType: delivery.deliveryType,
      });
    });
  }

  req.rData = {
    delivery,
    subscriptionBenefit: benefits
      ? {
          planName: benefits.planName,
          freeDeliveryApplied,
          subscriptionDiscount,
          discountPercentage: benefits.discountPercentage,
          freeDeliveriesRemaining: benefits.unlimitedDeliveries
            ? null
            : Math.max(
                benefits.freeDeliveriesRemaining - (freeDeliveryApplied ? 1 : 0),
                0,
              ),
          unlimitedDeliveries: benefits.unlimitedDeliveries,
        }
      : null,
  };
  req.msg = "delivery_created";
  next();
};

/**
 * Get delivery details
 */
export const getDeliveryDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => getDeliveryDetails");

  const { deliveryId } = req.params;

  const delivery = await DeliveryService.getDeliveryById(deliveryId);

  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  req.rData = { delivery };
  req.msg = "success";
  next();
};

/**
 * Get user's delivery history
 */
export const getUserDeliveries = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => getUserDeliveries");

  const userId = (req as any).userId;
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;

  const deliveries = await DeliveryService.getUserDeliveries(
    userId,
    page,
    limit,
  );
  const total = await DeliveryService.countDeliveries({ userId });

  req.rData = {
    deliveries,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };

  req.msg = "success";
  next();
};

/**
 * Get active delivery
 */
export const getActiveDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => getActiveDelivery");

  const userId = (req as any).userId;

  const delivery = await DeliveryService.getActiveUserDelivery(userId);

  req.rData = { delivery };
  req.msg = "success";
  next();
};

/**
 * Track delivery
 */
export const trackDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => trackDelivery");

  const { deliveryId } = req.params;

  const delivery = await DeliveryService.getDeliveryById(deliveryId);

  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  let driverLocation = null;
  let eta = null;

  if (delivery.driverId) {
    driverLocation = await DriverLocationService.getDriverLocation(
      delivery.driverId._id || delivery.driverId,
    );

    if (driverLocation) {
      // Find next pending stop
      const nextStop = delivery.drops.find((d) => d.status === "PENDING");
      const destination =
        delivery.status === "SEARCHING" || delivery.status === "ASSIGNED"
          ? delivery.pickup
          : nextStop || delivery.drops[delivery.drops.length - 1];

      const routeInfo = await MapsService.getDistanceAndDuration(
        { lat: driverLocation.latitude, lng: driverLocation.longitude },
        { lat: destination.lat, lng: destination.lng },
      );

      eta = routeInfo.durationMin;
    }
  }

  // Calculate completed stops
  const completedStops = delivery.drops.filter(
    (d) => d.status === "COMPLETED",
  ).length;

  req.rData = {
    delivery,
    driverLocation,
    eta,
    progress: {
      completedStops,
      totalStops: delivery.drops.length,
      percentage: Math.round((completedStops / delivery.drops.length) * 100),
    },
  };

  req.msg = "success";
  next();
};

/**
 * Cancel delivery
 */
export const cancelDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => cancelDelivery");

  const userId = (req as any).userId;
  const { deliveryId } = req.params;
  const { reason } = req.body;

  const delivery = await DeliveryService.getDeliveryById(deliveryId);

  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  if (delivery.userId._id.toString() !== userId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  const cancellableStatuses = ["SEARCHING", "ASSIGNED"];
  if (!cancellableStatuses.includes(delivery.status)) {
    req.rCode = 0;
    req.msg = "delivery_cannot_be_cancelled";
    return next();
  }

  const updatedDelivery = await DeliveryService.cancelDelivery(
    deliveryId,
    "USER",
    reason,
  );

  // Notify driver
  const io = req.app.get("io");
  if (io && delivery.driverId) {
    io.to(`driver_${delivery.driverId}`).emit("delivery_cancelled", {
      deliveryId: delivery._id,
      cancelledBy: "USER",
      reason,
    });
  }

  req.rData = { delivery: updatedDelivery };
  req.msg = "delivery_cancelled";
  next();
};

/**
 * Rate delivery
 */
export const rateDelivery = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DeliveryController => rateDelivery");

  const userId = (req as any).userId;
  const { deliveryId } = req.params;
  const { rating, feedback } = req.body;

  const delivery = await DeliveryService.getDeliveryById(deliveryId);

  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  if (delivery.userId._id.toString() !== userId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  if (delivery.status !== "DELIVERED") {
    req.rCode = 0;
    req.msg = "delivery_not_completed";
    return next();
  }

  const Delivery = require("../models/delivery.model").default;
  const updatedDelivery = await Delivery.findByIdAndUpdate(
    deliveryId,
    { rating, feedback },
    { new: true },
  );

  req.rData = { delivery: updatedDelivery };
  req.msg = "rating_submitted";
  next();
};
