import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import * as BookingService from "../services/booking.service";
import * as DriverLocationService from "../services/driver-location.service";
import * as DriverService from "../services/driver.service";
import * as DriverVehicleService from "../services/driver-vehicle.service";
import * as VehicleTypeService from "../services/vehicle-type.service";
import * as MapsService from "../services/maps.service";
import * as NotificationService from "../services/notification.service";
import * as AutomationRuleService from "../services/automation-rule.service";
import * as SubscriptionBenefitsService from "../services/subscription-benefits.service";
import * as PaymentService from "../services/payment.service";
import Offer from "../models/offer.model";
import DriverVehicle from "../models/driver-vehicle.model";
import helpers from "../utils/helpers";

/** Great-circle distance between two lat/lng points, in kilometres. */
const haversineKm = (
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number => {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

/**
 * Get fare estimate
 */
export const getFareEstimate = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => getFareEstimate");

  const userId = (req as any).userId;
  const { pickupLat, pickupLng, dropLat, dropLng, vehicleTypeId } = req.body;

  // Get distance and duration from Maps API
  const routeInfo = await MapsService.getDistanceAndDuration(
    { lat: pickupLat, lng: pickupLng },
    { lat: dropLat, lng: dropLng },
  );

  // Get vehicle type for pricing
  const vehicleType =
    await VehicleTypeService.getVehicleTypeById(vehicleTypeId);

  if (!vehicleType) {
    req.rCode = 0;
    req.msg = "invalid_vehicle_type";
    return next();
  }

  // Calculate fare
  const fare = helpers().calculateFare(
    routeInfo.distanceKm,
    routeInfo.durationMin,
    vehicleType,
  );

  const subtotal = fare.baseFare + fare.distanceFare + fare.timeFare + fare.surgeFare;
  const ruleResult = await AutomationRuleService.applyPromotionRulesToFare({
    userId,
    distanceKm: routeInfo.distanceKm,
    durationMin: routeInfo.durationMin,
    vehicleTypeId,
    baseFare: fare.baseFare,
    distanceFare: fare.distanceFare,
    timeFare: fare.timeFare,
    surgeFare: fare.surgeFare,
    subtotal,
  });

  req.rData = {
    distanceKm: routeInfo.distanceKm,
    durationMin: routeInfo.durationMin,
    ...fare,
    discount: ruleResult.discount,
    finalFare: ruleResult.finalFare,
    appliedRules: ruleResult.appliedRules,
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
 * Get all vehicle types with fare estimate
 */
export const getAllFareEstimates = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => getAllFareEstimates");

  const userId = (req as any).userId;
  const { pickupLat, pickupLng, dropLat, dropLng } = req.body;

  // Get distance and duration from Maps API
  const routeInfo = await MapsService.getDistanceAndDuration(
    { lat: pickupLat, lng: pickupLng },
    { lat: dropLat, lng: dropLng },
  );

  // Get all active vehicle types
  const allVehicleTypes = await VehicleTypeService.getActiveVehicleTypes();

  // Only offer vehicle types that have at least one available driver nearby
  // (online, approved, free, serviceType "cab") within the same 5km radius the
  // booking matcher uses — so the rider never picks a vehicle no one can fulfil.
  const NEARBY_RADIUS_KM = 5;
  const nearbyDrivers = await DriverLocationService.findNearbyDrivers(
    pickupLat,
    pickupLng,
    NEARBY_RADIUS_KM,
    undefined,
    "cab",
  );
  const nearbyDriverIds = nearbyDrivers.map((d) => d.driver._id);

  // Map nearby available drivers → their registered + online vehicle types,
  // tracking distinct drivers per type for the "X nearby" count.
  const availableVehicles = await DriverVehicle.find({
    driverId: { $in: nearbyDriverIds },
    isActive: true,
    isOnline: true,
  }).select("driverId vehicleTypeId");

  const driversByType = new Map<string, Set<string>>();
  for (const v of availableVehicles as any[]) {
    const typeId = v.vehicleTypeId.toString();
    if (!driversByType.has(typeId)) driversByType.set(typeId, new Set());
    driversByType.get(typeId)!.add(v.driverId.toString());
  }

  const vehicleTypes = allVehicleTypes.filter((vt: any) =>
    driversByType.has(vt._id.toString()),
  );

  // Calculate fare for each available vehicle type + apply promotion rules
  const fareEstimates = await Promise.all(vehicleTypes.map(async (vehicleType) => {
    const fare = helpers().calculateFare(
      routeInfo.distanceKm,
      routeInfo.durationMin,
      vehicleType,
    );
    const subtotal = fare.baseFare + fare.distanceFare + fare.timeFare + fare.surgeFare;
    const ruleResult = await AutomationRuleService.applyPromotionRulesToFare({
      userId,
      distanceKm: routeInfo.distanceKm,
      durationMin: routeInfo.durationMin,
      vehicleTypeId: vehicleType._id,
      baseFare: fare.baseFare,
      distanceFare: fare.distanceFare,
      timeFare: fare.timeFare,
      surgeFare: fare.surgeFare,
      subtotal,
    });

    return {
      vehicleType: {
        _id: vehicleType._id,
        name: vehicleType.name,
        image: vehicleType.image,
        categoryId: vehicleType.categoryId,
        maxSeats: vehicleType.maxSeats,
        description: vehicleType.description,
        minimumFare: vehicleType.minimumFare,
      },
      distanceKm: routeInfo.distanceKm,
      durationMin: routeInfo.durationMin,
      ...fare,
      discount: ruleResult.discount,
      finalFare: ruleResult.finalFare,
      appliedRules: ruleResult.appliedRules,
      availableDrivers: driversByType.get(vehicleType._id.toString())?.size ?? 0,
    };
  }));

  req.rData = {
    pickup: { lat: pickupLat, lng: pickupLng },
    drop: { lat: dropLat, lng: dropLng },
    estimates: fareEstimates,
  };

  req.msg = "fare_estimated";
  next();
};

/**
 * Create new booking
 */
export const createBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => createBooking");

  const userId = (req as any).userId;
  const {
    pickupAddress,
    pickupLat,
    pickupLng,
    dropAddress,
    dropLat,
    dropLng,
    vehicleTypeId,
    paymentMethod,
    scheduledAt,
    promoCode,
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature,
  } = req.body;

  // Check for active booking
  const activeBooking = await BookingService.getActiveUserBooking(userId);
  if (activeBooking) {
    req.rCode = 0;
    req.msg = "active_booking_exists";
    req.rData = { bookingId: activeBooking._id };
    return next();
  }

  // Get distance and duration
  const routeInfo = await MapsService.getDistanceAndDuration(
    { lat: pickupLat, lng: pickupLng },
    { lat: dropLat, lng: dropLng },
  );

  // Get vehicle type
  const vehicleType =
    await VehicleTypeService.getVehicleTypeById(vehicleTypeId);
  if (!vehicleType) {
    req.rCode = 0;
    req.msg = "invalid_vehicle_type";
    return next();
  }

  // Calculate fare
  const fareDetails = helpers().calculateFare(
    routeInfo.distanceKm,
    routeInfo.durationMin,
    vehicleType,
  );

  // Apply automation/promotion rules
  const subtotal =
    fareDetails.baseFare +
    fareDetails.distanceFare +
    fareDetails.timeFare +
    fareDetails.surgeFare;
  const ruleResult = await AutomationRuleService.applyPromotionRulesToFare({
    userId,
    distanceKm: routeInfo.distanceKm,
    durationMin: routeInfo.durationMin,
    vehicleTypeId,
    baseFare: fareDetails.baseFare,
    distanceFare: fareDetails.distanceFare,
    timeFare: fareDetails.timeFare,
    surgeFare: fareDetails.surgeFare,
    subtotal,
  });

  // Apply user-entered promo code on top of automation rules
  let totalDiscount = ruleResult.discount;
  let appliedPromo: string | undefined;
  if (promoCode && typeof promoCode === "string") {
    const offer = await Offer.findOne({
      code: promoCode.toUpperCase(),
      isActive: true,
      isDeleted: false,
      $or: [{ applicableOn: "ALL" }, { applicableOn: "CAB" }],
    });

    if (offer) {
      const now = new Date();
      const validWindow =
        (!offer.startDate || offer.startDate <= now) &&
        (!offer.endDate || offer.endDate >= now);
      const meetsMin = !offer.minOrderValue || subtotal >= offer.minOrderValue;
      const remaining = Math.max(subtotal - totalDiscount, 0);

      if (validWindow && meetsMin && remaining > 0) {
        let promoAmount = 0;
        if (offer.type === "PERCENTAGE") {
          promoAmount = (remaining * (offer.value || 0)) / 100;
          if (offer.maxDiscount != null) {
            promoAmount = Math.min(promoAmount, offer.maxDiscount);
          }
        } else if (offer.type === "FLAT") {
          promoAmount = offer.value || 0;
        }
        promoAmount = Math.min(promoAmount, remaining);
        if (promoAmount > 0) {
          totalDiscount += promoAmount;
          appliedPromo = offer.code;
        }
      }
    }
  }

  // Apply subscription (Kebu Pass) percentage discount on top of promo/automation
  const benefits = await SubscriptionBenefitsService.getActiveBenefits(userId);
  const preSubtotal = Math.max(subtotal - totalDiscount, 0);
  const subscriptionDiscount = SubscriptionBenefitsService.computeSubscriptionDiscount(
    preSubtotal,
    benefits,
  );
  if (subscriptionDiscount > 0) {
    totalDiscount += subscriptionDiscount;
  }

  const finalFare = Math.max(
    Math.round((subtotal - totalDiscount) * 100) / 100,
    0,
  );

  // Resolve payment up-front for online (UPI) bookings: the client pays via
  // Razorpay BEFORE the ride is created, then sends the payment proof here.
  // We only create the booking once the signature verifies. Cash bookings are
  // created PENDING and settled when the driver collects on completion.
  const method = paymentMethod || "CASH";
  let paymentStatus: "PENDING" | "PAID" = "PENDING";

  if (method === "UPI") {
    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      req.rCode = 0;
      req.msg = "payment_required";
      req.rData = { error: "Online payment is required before booking" };
      return next();
    }

    const isValid = PaymentService.verifyPayment({
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
    });

    if (!isValid) {
      req.rCode = 0;
      req.msg = "payment_verification_failed";
      req.rData = { error: "Payment could not be verified" };
      return next();
    }

    paymentStatus = "PAID";
  }

  // Generate ride OTP
  const rideOtp = helpers().generateOTP(4).toString();

  // Create booking
  const booking = await BookingService.createBooking({
    userId,
    vehicleTypeId: new Types.ObjectId(vehicleTypeId),
    pickup: {
      address: pickupAddress,
      lat: pickupLat,
      lng: pickupLng,
    },
    drop: {
      address: dropAddress,
      lat: dropLat,
      lng: dropLng,
    },
    distanceKm: routeInfo.distanceKm,
    durationMin: routeInfo.durationMin,
    fare:
      fareDetails.baseFare + fareDetails.distanceFare + fareDetails.timeFare,
    surgeFare: fareDetails.surgeFare,
    discount: Math.round(totalDiscount * 100) / 100,
    subscriptionDiscount: subscriptionDiscount > 0 ? subscriptionDiscount : 0,
    subscriptionPlanName:
      subscriptionDiscount > 0 ? benefits?.planName : undefined,
    finalFare,
    promoCode: appliedPromo,
    paymentMethod: method,
    paymentStatus,
    status: "SEARCHING",
    otp: rideOtp,
    scheduledAt: scheduledAt ? new Date(scheduledAt) : undefined,
  });

  // Record rule triggers so usage limits/counters are respected
  if (ruleResult.appliedRules.length > 0) {
    await AutomationRuleService.recordRuleTrigger(
      ruleResult.appliedRules.map((r) => r.ruleId),
    );
  }

  // Find nearby drivers and notify via Socket.io + MQTT bell + FCM push
  const io = req.app.get("io");
  // Only notify drivers whose registered + online vehicle matches the
  // requested vehicle type — a Bike driver must not receive a Sedan booking.
  const nearbyDrivers = await DriverLocationService.findNearbyDrivers(
    pickupLat,
    pickupLng,
    5, // 5km radius
    new Types.ObjectId(vehicleTypeId),
    "cab",
  );

  const notifiedDriverIds: Types.ObjectId[] = [];

  // Hydrate populated user + vehicle type so the driver app can render the
  // buzzer / on-route screens without a follow-up REST call. Falls back to
  // the raw booking shape when populate fails.
  const populated = await BookingService.getBookingById(booking._id!);
  const userBlock = populated && (populated as any).userId
    ? {
        _id: (populated as any).userId._id,
        fullName: (populated as any).userId.fullName,
        mobileNumber: (populated as any).userId.mobileNumber,
      }
    : undefined;
  const vehicleTypeBlock = populated && (populated as any).vehicleTypeId
    ? {
        _id: (populated as any).vehicleTypeId._id,
        name: (populated as any).vehicleTypeId.name,
      }
    : undefined;

  const rideRequestData = {
    bookingId: booking._id!.toString(),
    pickup: booking.pickup,
    drop: booking.drop,
    fare: booking.finalFare,
    finalFare: booking.finalFare,
    // Surge component of the fare — shown as the "+ ₹x" incentive badge on
    // the driver's take-booking earnings card. Omitted (0) for non-surge rides.
    surgeFare: booking.surgeFare ?? 0,
    distanceKm: booking.distanceKm,
    durationMin: booking.durationMin,
    // Scheduled pickup time (null for immediate rides → driver app shows "now").
    scheduledAt: booking.scheduledAt,
    paymentMethod: booking.paymentMethod,
    user: userBlock,
    userId: userBlock,
    vehicleTypeId: vehicleTypeBlock,
  };

  const driversForMqtt: {
    driverId: string;
    fcmToken?: string;
    isOnline: boolean;
  }[] = [];

  for (const { driver } of nearbyDrivers) {
    notifiedDriverIds.push(driver._id);

    // Socket.io → online drivers (instant)
    if (io) {
      io.to(`driver_${driver._id}`).emit("new_ride_request", rideRequestData);
    }

    // Collect for MQTT bell + FCM push
    driversForMqtt.push({
      driverId: driver._id.toString(),
      fcmToken: (driver as any).fcmToken,
      isOnline: driver.isOnline ?? false,
    });
  }

  // Store notified driver IDs
  if (notifiedDriverIds.length > 0) {
    await BookingService.updateBooking(booking._id!, { notifiedDriverIds });
  }

  // MQTT bell ring + FCM push for offline drivers
  try {
    await NotificationService.notifyDriversNewRide(driversForMqtt, rideRequestData);
  } catch (error) {
    console.error("Error notifying drivers (MQTT/FCM):", error);
  }

  // If no drivers were found nearby, notify the customer immediately so the UI doesn't spin forever
  if (nearbyDrivers.length === 0) {
    await BookingService.updateBooking(booking._id!, { status: "NO_DRIVERS" });
    if (io) {
      io.to(`user_${userId}`).emit("no_drivers_available", {
        bookingId: booking._id!.toString(),
      });
    }
  }

  req.rData = {
    booking,
    nearbyDriversCount: nearbyDrivers.length,
    subscriptionBenefit: benefits
      ? {
          planName: benefits.planName,
          discountPercentage: benefits.discountPercentage,
          subscriptionDiscount,
        }
      : null,
  };

  req.msg = nearbyDrivers.length === 0 ? "no_drivers_available" : "booking_created";
  next();
};

/**
 * Get booking details
 */
export const getBookingDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => getBookingDetails");

  const { bookingId } = req.params;

  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  req.rData = { booking };
  req.msg = "success";
  next();
};

/**
 * Get user bookings
 */
export const getUserBookings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => getUserBookings");

  const userId = (req as any).userId;
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;
  const status = req.query.status as string;

  const bookings = await BookingService.getUserBookings(
    userId,
    page,
    limit,
    status as any,
  );

  const total = await BookingService.countBookings({ userId });

  req.rData = {
    bookings,
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
 * Get active booking
 */
export const getActiveBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => getActiveBooking");

  const userId = (req as any).userId;

  const booking = await BookingService.getActiveUserBooking(userId);

  // Attach the assigned driver's vehicle registration number so a resumed
  // session shows the real vehicle plate (the booking itself only stores the
  // vehicle type, not the specific vehicle). Name/image come from the
  // populated vehicleTypeId already.
  let responseBooking: any = booking;
  if (booking && (booking as any).driverId) {
    const driverId = (booking as any).driverId?._id ?? (booking as any).driverId;
    const activeVehicle =
      await DriverVehicleService.getActiveDriverVehicle(driverId);
    responseBooking = (booking as any).toObject();
    responseBooking.vehicleNumber =
      (activeVehicle as any)?.registrationNumber ?? "";
  }

  req.rData = { booking: responseBooking };
  req.msg = "success";
  next();
};

/**
 * Cancel booking
 */
export const cancelBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => cancelBooking");

  const userId = (req as any).userId;
  const { bookingId } = req.params;
  const { reason } = req.body;

  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  // Check if user owns the booking
  if (booking.userId._id.toString() !== userId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  // Check if booking can be cancelled
  const cancellableStatuses = ["SEARCHING", "ASSIGNED", "DRIVER_ARRIVED"];
  if (!cancellableStatuses.includes(booking.status)) {
    req.rCode = 0;
    req.msg = "booking_cannot_be_cancelled";
    return next();
  }

  const updatedBooking = await BookingService.cancelBooking(
    bookingId,
    "USER",
    reason,
  );

  // If a driver was assigned, free them and tell them the ride was cancelled.
  // Driver app listens for "ride_cancelled" (not "booking_cancelled").
  const io = req.app.get("io");
  if (booking.driverId) {
    try {
      await DriverService.updateDriver(booking.driverId, {
        currentBookingId: undefined,
      });
    } catch (err) {
      console.error(
        "[cancelBooking] Failed to clear driver.currentBookingId for",
        booking.driverId.toString(),
        err,
      );
    }

    if (io) {
      io.to(`driver_${booking.driverId}`).emit("ride_cancelled", {
        booking: updatedBooking,
        bookingId: booking._id,
        cancelledBy: "USER",
        reason,
      });
    }

    // Persist for in-app notification list (driver + the cancelling user).
    const cancelledByUserTmpl = NotificationService.NotificationTemplates.rideCancelled("user");
    await NotificationService.createNotification({
      driverId: booking.driverId,
      title: cancelledByUserTmpl.title,
      message: cancelledByUserTmpl.body,
      type: "ORDER",
      data: { bookingId: booking._id as Types.ObjectId },
    });
    await NotificationService.createNotification({
      userId: booking.userId as any,
      title: cancelledByUserTmpl.title,
      message: cancelledByUserTmpl.body,
      type: "ORDER",
      data: { bookingId: booking._id as Types.ObjectId },
    });
  } else {
    // No driver assigned — still persist for the user.
    const cancelledByUserTmpl = NotificationService.NotificationTemplates.rideCancelled("user");
    await NotificationService.createNotification({
      userId: booking.userId as any,
      title: cancelledByUserTmpl.title,
      message: cancelledByUserTmpl.body,
      type: "ORDER",
      data: { bookingId: booking._id as Types.ObjectId },
    });
  }

  // Clear the pending request from every driver that was offered this ride
  // (while it was still SEARCHING) so the request card disappears from their
  // app instantly. The assigned driver — if any — was already notified above.
  if (io && Array.isArray(booking.notifiedDriverIds)) {
    const assignedId = booking.driverId?.toString();
    for (const driverId of booking.notifiedDriverIds) {
      if (assignedId && driverId.toString() === assignedId) continue;
      io.to(`driver_${driverId}`).emit("ride_cancelled", {
        bookingId: booking._id,
        cancelledBy: "USER",
        reason,
      });
    }
  }

  req.rData = { booking: updatedBooking };
  req.msg = "booking_cancelled";
  next();
};

/**
 * Rate booking
 */
export const rateBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => rateBooking");

  const userId = (req as any).userId;
  const { bookingId } = req.params;
  const { rating, feedback } = req.body;

  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  if (booking.userId._id.toString() !== userId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  if (booking.status !== "COMPLETED") {
    req.rCode = 0;
    req.msg = "booking_not_completed";
    return next();
  }

  const updatedBooking = await BookingService.rateBooking(
    bookingId,
    rating,
    feedback,
  );

  req.rData = { booking: updatedBooking };
  req.msg = "rating_submitted";
  next();
};

/**
 * Get booking tracking info
 */
export const trackBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => trackBooking");

  const { bookingId } = req.params;

  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  let driverLocation = null;
  let eta = null;

  if (booking.driverId) {
    driverLocation = await DriverLocationService.getDriverLocation(
      booking.driverId._id || booking.driverId,
    );

    if (driverLocation) {
      // Calculate ETA based on status
      const destination =
        booking.status === "ASSIGNED" || booking.status === "DRIVER_ARRIVED"
          ? booking.pickup
          : booking.drop;

      const routeInfo = await MapsService.getDistanceAndDuration(
        { lat: driverLocation.latitude, lng: driverLocation.longitude },
        { lat: destination.lat, lng: destination.lng },
      );

      eta = routeInfo.durationMin;
    }
  }

  req.rData = {
    booking,
    driverLocation,
    eta,
  };

  req.msg = "success";
  next();
};

/**
 * Get nearby available drivers
 */
export const getNearbyDrivers = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("BookingController => getNearbyDrivers");

  const lat = parseFloat(req.query.lat as string);
  const lng = parseFloat(req.query.lng as string);
  const maxDistance = parseFloat((req.query.maxDistance as string) || "5");

  if (isNaN(lat) || isNaN(lng)) {
    req.rCode = 5;
    req.msg = "lat_lng_required";
    return next();
  }

  const nearbyDrivers = await DriverLocationService.findNearbyDrivers(
    lat,
    lng,
    maxDistance,
    undefined,
    "cab",
  );

  // Resolve each available driver's vehicle image (vehicle type icon) so the
  // map can render the real vehicle PNG instead of a generic marker.
  const driverIds = nearbyDrivers.map((d) => d.driver._id);
  const vehicles = await DriverVehicle.find({
    driverId: { $in: driverIds },
    isActive: true,
    isOnline: true,
  }).populate("vehicleTypeId", "image name");

  const imageByDriver = new Map<string, string>();
  const typeByDriver = new Map<string, string>();
  for (const v of vehicles as any[]) {
    const vt = v.vehicleTypeId;
    if (vt && typeof vt === "object") {
      if (vt.image) imageByDriver.set(v.driverId.toString(), vt.image);
      if (vt.name) typeByDriver.set(v.driverId.toString(), vt.name);
    }
  }

  // "Get a cab in X mins" = nearest available driver's straight-line distance
  // to the pickup ÷ an assumed average city speed (no extra Maps API cost).
  const AVG_SPEED_KMH = 20;
  let nearestKm = Infinity;

  const drivers = nearbyDrivers.map(({ driver, location }) => {
    const dLat = location?.latitude ?? 0;
    const dLng = location?.longitude ?? 0;
    const km = haversineKm(lat, lng, dLat, dLng);
    if (km < nearestKm) nearestKm = km;
    return {
      id: driver._id,
      latitude: dLat,
      longitude: dLng,
      heading: location?.heading ?? 0,
      vehicleImage: imageByDriver.get(driver._id.toString()) ?? "",
      vehicleType: typeByDriver.get(driver._id.toString()) ?? "",
    };
  });

  const etaMinutes =
    drivers.length > 0 && Number.isFinite(nearestKm)
      ? Math.max(1, Math.ceil((nearestKm / AVG_SPEED_KMH) * 60))
      : null;

  req.rData = { drivers, etaMinutes };

  req.msg = "success";
  next();
};
