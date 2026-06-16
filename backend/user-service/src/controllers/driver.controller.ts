import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import * as DriverService from "../services/driver.service";
import { IDriver } from "../interfaces/driver";
import * as DriverLocationService from "../services/driver-location.service";
import * as BookingService from "../services/booking.service";
import * as DriverVehicleService from "../services/driver-vehicle.service";
import * as DriverKycService from "../services/driver-kyc.service";
import { uploadMultipleFilesToAws } from "../utils/s3";
import * as V from "../utils/validators";
import { SupportTicket } from "../models/customer-features.model";
import VehicleType from "../models/vehicle-type.model";
import VehicleCategory from "../models/vehicle-category.model";
import DriverVehicle from "../models/driver-vehicle.model";
import ServiceCategory from "../models/service-category.model";
import * as CommissionService from "../services/commission.service";
import * as MapsService from "../services/maps.service";
import * as NotificationService from "../services/notification.service";
import * as WalletService from "../services/wallet.service";
import User from "../models/Users";
import WalletTransaction from "../models/wallet-transaction.model";

/**
 * Extract the driver-id string from a booking's `driverId` field whether or
 * not mongoose populated it. `getBookingById` populates the ref into a
 * sub-document, so `booking.driverId.toString()` returns "[object Object]"
 * — use this helper for ownership checks instead of comparing directly.
 */
function bookingDriverIdString(driverIdField: unknown): string | undefined {
  if (!driverIdField) return undefined;
  // Populated sub-doc → has _id we can stringify
  if (typeof driverIdField === "object" && driverIdField !== null) {
    const obj = driverIdField as { _id?: { toString(): string }; toString?: () => string };
    if (obj._id) return obj._id.toString();
    // ObjectId itself is an object too — its toString() returns the hex id
    if (driverIdField instanceof Types.ObjectId) return driverIdField.toString();
  }
  return String(driverIdField);
}

/**
 * Get driver dashboard stats
 */
export const getDashboard = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getDashboard");

  const driverId = (req as any).driverId;

  const driver = await DriverService.getDriverById(driverId);

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // Get today's stats
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const todayBookings = await BookingService.getDriverBookings(
    driverId,
    0,
    100,
    undefined,
  );

  const todayStats = todayBookings.reduce(
    (acc, booking) => {
      if (
        new Date((booking as any).createdAt) >= today &&
        booking.status === "COMPLETED"
      ) {
        acc.totalRides++;
        acc.totalEarnings += booking.finalFare;
      }
      return acc;
    },
    { totalRides: 0, totalEarnings: 0 },
  );

  // Get weekly stats
  const weekStart = new Date();
  weekStart.setDate(weekStart.getDate() - 7);
  weekStart.setHours(0, 0, 0, 0);

  const weeklyStats = todayBookings.reduce(
    (acc, booking) => {
      if (
        new Date((booking as any).createdAt) >= weekStart &&
        booking.status === "COMPLETED"
      ) {
        acc.totalRides++;
        acc.totalEarnings += booking.finalFare;
      }
      return acc;
    },
    { totalRides: 0, totalEarnings: 0 },
  );

  // Fetch KYC for licence details
  const kyc = await DriverKycService.getDriverKyc(driver._id as any);

  // Total login (online) hours = accumulated online time + the current
  // session if the driver is online right now.
  let onlineSeconds = driver.totalOnlineSeconds || 0;
  if (driver.isOnline && driver.lastOnlineAt) {
    onlineSeconds += Math.max(
      0,
      Math.floor((Date.now() - new Date(driver.lastOnlineAt).getTime()) / 1000),
    );
  }
  const totalLoginHours = Math.round((onlineSeconds / 3600) * 10) / 10;

  req.rData = {
    driver: {
      _id: driver._id,
      fullName: driver.fullName,
      profileImage: (driver as any).profileImage || "",
      mobileNumber: driver.mobileNumber,
      isOnline: driver.isOnline,
      status: driver.status,
      serviceType: driver.serviceType || "",
      onboardingStep: driver.onboardingStep || 0,
      rating: driver.rating,
      totalRides: driver.totalRides,
      totalLoginHours,
      bloodGroup: driver.bloodGroup || "",
      emergencyContact: driver.emergencyContact || "",
      preferredWorkHours: (driver as any).preferredWorkHours || "",
      createdAt: (driver as any).createdAt,
      licenceNumber: kyc?.drivingLicense?.number || "",
      licenceExpiry: kyc?.drivingLicense?.expiryDate || "",
    },
    today: todayStats,
    weekly: weeklyStats,
    hasActiveBooking: !!driver.currentBookingId,
    activeBookingId: driver.currentBookingId,
  };

  req.msg = "success";
  next();
};

/**
 * Toggle online/offline status
 */
export const toggleOnlineStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => toggleOnlineStatus");

  const driverId = (req as any).driverId;
  const { latitude, longitude } = req.body;

  const driver = await DriverService.getDriverById(driverId);

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // Check if driver is approved
  if (driver.status !== "approved") {
    req.rCode = 0;
    req.msg = "driver_not_approved";
    return next();
  }

  // Toggle: flip current value
  const isOnline = !driver.isOnline;

  // Track login (online) time. Going online starts a session timer; going
  // offline accumulates the elapsed session into totalOnlineSeconds.
  const now = new Date();
  const update: Partial<IDriver> = { isOnline };
  if (isOnline) {
    update.lastOnlineAt = now;
  } else {
    if (driver.lastOnlineAt) {
      const elapsedSec = Math.max(
        0,
        Math.floor((now.getTime() - new Date(driver.lastOnlineAt).getTime()) / 1000),
      );
      update.totalOnlineSeconds = (driver.totalOnlineSeconds || 0) + elapsedSec;
    }
    update.lastOnlineAt = null;
  }

  // Update driver status
  await DriverService.updateDriver(driverId, update);

  // Update location if going online
  if (isOnline && latitude && longitude) {
    await DriverLocationService.updateDriverLocation(
      driverId,
      latitude,
      longitude,
    );
  }

  req.rData = { isOnline };
  req.msg = isOnline ? "driver_online" : "driver_offline";
  next();
};

/**
 * Update driver location
 */
export const updateLocation = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => updateLocation");

  const driverId = (req as any).driverId;
  const { latitude, longitude, heading, speed } = req.body;

  await DriverLocationService.updateDriverLocation(
    driverId,
    latitude,
    longitude,
    heading,
    speed,
  );

  req.rData = { updated: true };
  req.msg = "success";
  next();
};

/**
 * Get driver's active booking
 */
export const getActiveBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getActiveBooking");

  const driverId = (req as any).driverId;

  const booking = await BookingService.getActiveDriverBooking(
    new Types.ObjectId(driverId),
  );

  req.rData = { booking };
  req.msg = "success";
  next();
};

/**
 * Get driver's booking history
 */
export const getBookingHistory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getBookingHistory");

  const driverId = (req as any).driverId;
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;

  const bookings = await BookingService.getDriverBookings(
    new Types.ObjectId(driverId),
    page,
    limit,
  );

  const total = await BookingService.countBookings({ driverId });

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
 * Get a single booking by id (driver-authenticated). Used by the
 * driver app's ride-detail / cancellation deep-link screens. The driver
 * must own the booking — otherwise we return `unauthorized`.
 */
export const getBookingById = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getBookingById");

  const driverId = (req as any).driverId;
  const { bookingId } = req.params;

  const booking = await BookingService.getBookingById(bookingId);
  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  if (bookingDriverIdString(booking.driverId) !== driverId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  req.rData = { booking };
  req.msg = "success";
  next();
};

/**
 * Get earnings summary
 */
export const getEarnings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getEarnings");

  const driverId = (req as any).driverId;
  const { period } = req.query; // today, week, month, all

  let startDate: Date | undefined;
  const endDate = new Date();

  switch (period) {
    case "today":
      startDate = new Date();
      startDate.setHours(0, 0, 0, 0);
      break;
    case "week":
      startDate = new Date();
      startDate.setDate(startDate.getDate() - 7);
      break;
    case "month":
      startDate = new Date();
      startDate.setMonth(startDate.getMonth() - 1);
      break;
    default:
      startDate = undefined;
  }

  // Get all completed bookings in period
  const query: any = {
    driverId: new Types.ObjectId(driverId),
    status: "COMPLETED",
  };

  if (startDate) {
    query.completedAt = { $gte: startDate, $lte: endDate };
  }

  const Booking = require("../models/booking.model").default;

  const bookings = await Booking.find(query).sort({ completedAt: -1 });

  const totalEarnings = bookings.reduce(
    (sum: number, b: any) => sum + b.finalFare,
    0,
  );
  const totalRides = bookings.length;

  // Get commission/payout data for this driver in the same period
  const { Payout } = require("../models/pricing-config.model");
  const payoutQuery: any = {
    recipientId: new Types.ObjectId(driverId),
  };
  if (startDate) {
    payoutQuery.createdAt = { $gte: startDate, $lte: endDate };
  }
  const payouts = await Payout.find(payoutQuery).lean();
  const totalCommission = payouts.reduce(
    (sum: number, p: any) => sum + (p.totalCommission || 0),
    0,
  );
  const netEarnings = totalEarnings - totalCommission;

  // Group by day for chart data
  const dailyEarnings: Record<string, number> = {};

  bookings.forEach((b: any) => {
    const date = new Date(b.completedAt).toISOString().split("T")[0];
    dailyEarnings[date] = (dailyEarnings[date] || 0) + b.finalFare;
  });

  req.rData = {
    totalEarnings,
    totalCommission: Math.round(totalCommission * 100) / 100,
    netEarnings: Math.round(netEarnings * 100) / 100,
    totalRides,
    averagePerRide: totalRides > 0 ? Math.round(totalEarnings / totalRides) : 0,
    dailyEarnings: Object.entries(dailyEarnings).map(([date, amount]) => ({
      date,
      amount,
    })),
    recentBookings: bookings.slice(0, 10),
  };

  req.msg = "success";
  next();
};

/**
 * Accept ride request
 */
export const acceptRide = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => acceptRide");

  const driverId = (req as any).driverId;
  const { bookingId } = req.params;

  // Only cab vendors can accept cab bookings
  const acceptingDriver = await DriverService.getDriverById(driverId);
  if (!acceptingDriver || acceptingDriver.serviceType !== "cab") {
    req.rCode = 0;
    req.msg = "vendor_type_mismatch";
    return next();
  }

  // Check if driver already has active booking
  const activeBooking = await BookingService.getActiveDriverBooking(
    new Types.ObjectId(driverId),
  );

  if (activeBooking) {
    req.rCode = 0;
    req.msg = "active_booking_exists";
    return next();
  }

  // Get booking
  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  if (booking.status !== "SEARCHING") {
    req.rCode = 0;
    req.msg = "booking_not_available";
    return next();
  }

  // Assign driver
  const updatedBooking = await BookingService.assignDriverToBooking(
    bookingId,
    new Types.ObjectId(driverId),
  );

  // Update driver's current booking
  await DriverService.updateDriver(driverId, {
    currentBookingId: new Types.ObjectId(bookingId),
  });

  // Emit socket event to user
  const io = req.app.get("io");
  if (io && updatedBooking) {
    const driver = await DriverService.getDriverById(driverId);
    const driverLocation = await DriverLocationService.getDriverLocation(
      new Types.ObjectId(driverId),
    );

    io.to(`user_${updatedBooking.userId}`).emit("ride_accepted", {
      booking: updatedBooking,
      driver: {
        _id: driver?._id,
        fullName: driver?.fullName,
        mobileNumber: driver?.mobileNumber,
        rating: driver?.rating,
      },
      driverLocation,
    });
  }

  // Persist for in-app notification list.
  if (updatedBooking) {
    const driverNameForUser = (await DriverService.getDriverById(driverId))?.fullName || "Driver";
    const acceptedTmpl = NotificationService.NotificationTemplates.rideAccepted(driverNameForUser);
    await NotificationService.createNotification({
      userId: updatedBooking.userId as any,
      title: acceptedTmpl.title,
      message: acceptedTmpl.body,
      type: "ORDER",
      data: { bookingId: updatedBooking._id as Types.ObjectId },
    });
  }

  req.rData = { booking: updatedBooking };
  req.msg = "ride_accepted";
  next();
};

/**
 * Update ride status
 */
export const updateRideStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => updateRideStatus");

  const driverId = (req as any).driverId;
  const { bookingId } = req.params;
  const { status, otp } = req.body;

  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  // Verify driver owns this booking
  const bookingDriverId = bookingDriverIdString(booking.driverId);
  if (bookingDriverId !== driverId.toString()) {
    console.warn(
      `[updateRideStatus] DRIVER MISMATCH bookingId=${bookingId} ` +
      `booking.driverId=${bookingDriverId ?? "null"} ` +
      `jwt.driverId=${driverId.toString()} status=${booking.status}`,
    );
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  // Validate status transition
  const validTransitions: Record<string, string[]> = {
    ASSIGNED: ["DRIVER_ARRIVED", "CANCELLED"],
    DRIVER_ARRIVED: ["IN_PROGRESS", "PICKED", "CANCELLED"],
    PICKED: ["IN_PROGRESS"],
    IN_PROGRESS: ["COMPLETED"],
  };

  if (!validTransitions[booking.status]?.includes(status)) {
    req.rCode = 0;
    req.msg = "invalid_status_transition";
    return next();
  }

  // For PICKED status, verify OTP
  if (status === "IN_PROGRESS" && booking.otp !== otp) {
    req.rCode = 0;
    req.msg = "invalid_otp";
    return next();
  }

  // Update booking status
  const updatedBooking = await BookingService.updateBookingStatus(
    bookingId,
    status,
  );

  // Clear driver's current booking if completed
  if (status === "COMPLETED") {
    await DriverService.updateDriver(driverId, {
      currentBookingId: undefined,
    });

    // Increment driver's total rides
    const driver = await DriverService.getDriverById(driverId);
    if (driver) {
      await DriverService.updateDriver(driverId, {
        totalRides: (driver.totalRides || 0) + 1,
      });
    }

    // Calculate and record commission, then credit the driver's net
    // earnings to their wallet so the Send/Received/Statement screens
    // and the home-screen balance reflect the trip immediately.
    if (updatedBooking) {
      try {
        const result = await CommissionService.processCabCommission({
          _id: updatedBooking._id,
          driverId: updatedBooking.driverId!,
          vehicleTypeId: updatedBooking.vehicleTypeId,
          finalFare: updatedBooking.finalFare,
          completedAt: new Date(),
        });

        // Credit the driver wallet with net earnings (after commission).
        // Skip cash bookings — those settle when the driver taps
        // "Collected Cash" on the post-ride screen, which calls
        // markPaymentCollected below and credits the wallet there. Crediting
        // here for cash would double-count.
        const isCash =
          ((updatedBooking as any).paymentMethod || "").toUpperCase() ===
          "CASH";
        const netEarnings =
          result?.netEarnings ?? updatedBooking.finalFare;
        if (!isCash && netEarnings > 0) {
          await WalletService.addToWallet(
            new Types.ObjectId(driverId),
            netEarnings,
            "Your Earning",
            (updatedBooking._id as Types.ObjectId).toString(),
          );
        }
      } catch (err) {
        console.error("Commission calculation failed for cab booking:", updatedBooking._id, err);
      }
    }
  }

  // Emit socket event to user
  const io = req.app.get("io");
  if (io && updatedBooking) {
    const eventMap: Record<string, string> = {
      DRIVER_ARRIVED: "driver_arrived",
      PICKED: "ride_picked",
      IN_PROGRESS: "ride_started",
      COMPLETED: "ride_completed",
    };

    io.to(`user_${updatedBooking.userId}`).emit(eventMap[status], {
      booking: updatedBooking,
    });
  }

  // Persist + FCM push.
  // Both parties get notified on every meaningful state change:
  //   DRIVER_ARRIVED → user only
  //   IN_PROGRESS    → user AND driver (ride start is a milestone for both)
  //   COMPLETED      → user AND driver (settlement-relevant)
  if (updatedBooking) {
    let userTmpl: { title: string; body: string } | null = null;
    let driverTmpl: { title: string; body: string } | null = null;
    const fare = (updatedBooking as any).finalFare || 0;
    switch (status) {
      case "DRIVER_ARRIVED":
        userTmpl = NotificationService.NotificationTemplates.driverArrived();
        break;
      case "IN_PROGRESS":
        userTmpl = NotificationService.NotificationTemplates.rideStarted();
        driverTmpl = NotificationService.NotificationTemplates.rideStartedDriver();
        break;
      case "COMPLETED":
        userTmpl = NotificationService.NotificationTemplates.rideCompleted(fare);
        driverTmpl = NotificationService.NotificationTemplates.rideCompleteDriver(fare);
        break;
    }

    const bookingIdStr = (updatedBooking._id as Types.ObjectId).toString();

    if (userTmpl) {
      await NotificationService.createNotification({
        userId: updatedBooking.userId as any,
        title: userTmpl.title,
        message: userTmpl.body,
        type: "ORDER",
        data: { bookingId: updatedBooking._id as Types.ObjectId },
      });
      // FCM push to user
      try {
        const userDoc = await User.findById(updatedBooking.userId)
          .select("fcmToken")
          .lean();
        if (userDoc && (userDoc as any).fcmToken) {
          await NotificationService.sendRideStatusPush(
            (userDoc as any).fcmToken,
            userTmpl,
            { bookingId: bookingIdStr },
          );
        }
      } catch (err) {
        console.error("user FCM push failed for status", status, err);
      }
    }

    if (driverTmpl) {
      await NotificationService.createNotification({
        driverId: driverId,
        title: driverTmpl.title,
        message: driverTmpl.body,
        type: "ORDER",
        data: { bookingId: updatedBooking._id as Types.ObjectId },
      });
      // FCM push to driver
      try {
        const driverDoc = await DriverService.getDriverById(driverId);
        if (driverDoc && (driverDoc as any).fcmToken) {
          await NotificationService.sendRideStatusPush(
            (driverDoc as any).fcmToken,
            driverTmpl,
            { bookingId: bookingIdStr },
          );
        }
      } catch (err) {
        console.error("driver FCM push failed for status", status, err);
      }
    }
  }

  req.rData = { booking: updatedBooking };
  req.msg = "status_updated";
  next();
};

/**
 * Cancel ride (by driver)
 */
export const cancelRide = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => cancelRide");

  const driverId = (req as any).driverId;
  const { bookingId } = req.params;
  const { reason } = req.body;

  const booking = await BookingService.getBookingById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  if (bookingDriverIdString(booking.driverId) !== driverId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  const cancellableStatuses = ["ASSIGNED", "DRIVER_ARRIVED"];
  if (!cancellableStatuses.includes(booking.status)) {
    req.rCode = 0;
    req.msg = "booking_cannot_be_cancelled";
    return next();
  }

  const updatedBooking = await BookingService.cancelBooking(
    bookingId,
    "DRIVER",
    reason,
  );

  // Clear driver's current booking
  await DriverService.updateDriver(driverId, {
    currentBookingId: undefined,
  });

  // Notify user
  const io = req.app.get("io");
  if (io && updatedBooking) {
    io.to(`user_${updatedBooking.userId}`).emit("ride_cancelled", {
      booking: updatedBooking,
      cancelledBy: "DRIVER",
      reason,
    });
  }

  // Persist for in-app notification list (both sides).
  if (updatedBooking) {
    const cancelledByDriverTmpl = NotificationService.NotificationTemplates.rideCancelled("driver");
    await NotificationService.createNotification({
      userId: updatedBooking.userId as any,
      title: cancelledByDriverTmpl.title,
      message: cancelledByDriverTmpl.body,
      type: "ORDER",
      data: { bookingId: updatedBooking._id as Types.ObjectId },
    });
    await NotificationService.createNotification({
      driverId: driverId,
      title: cancelledByDriverTmpl.title,
      message: cancelledByDriverTmpl.body,
      type: "ORDER",
      data: { bookingId: updatedBooking._id as Types.ObjectId },
    });
  }

  req.rData = { booking: updatedBooking };
  req.msg = "ride_cancelled";
  next();
};

/**
 * Get vehicle details
 */
export const getVehicle = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getVehicle");

  const driverId = (req as any).driverId;

  const vehicle = await DriverVehicleService.getActiveDriverVehicle(
    new Types.ObjectId(driverId),
  );

  req.rData = { vehicle };
  req.msg = "success";
  next();
};

/**
 * Onboarding - Save basic details
 */
export const saveBasicDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveBasicDetails");

  const driverId = (req as any).driverId;
  const { name, email, dateOfBirth, gender, bloodGroup, emergencyContact, serviceType } =
    req.body;

  // Validations
  const errors: string[] = [];
  const nameErr = V.validateName(name);
  if (nameErr) errors.push(nameErr);
  const emailErr = V.validateEmail(email);
  if (emailErr) errors.push(emailErr);
  const dobErr = V.validateDOB(dateOfBirth);
  if (dobErr) errors.push(dobErr);
  if (!gender || !["Male", "Female", "Other"].includes(gender))
    errors.push("Please select a valid gender.");
  const phoneErr = V.validatePhone(emergencyContact);
  if (phoneErr) errors.push("Emergency contact: " + phoneErr);

  if (errors.length > 0) {
    req.rCode = 0;
    req.msg = undefined as any;
    return res.status(400).json({ code: 0, message: errors[0], data: {} });
  }

  const updateData: any = {
    fullName: name.trim(),
    email: email.trim(),
    dob: dateOfBirth.trim(),
    gender,
    bloodGroup: bloodGroup || "",
    emergencyContact: emergencyContact.trim(),
  };

  if (serviceType && ["cab", "cleaning", "parcel"].includes(serviceType)) {
    updateData.serviceType = serviceType;
  }

  // Also update onboardingStep if this is the first step or re-submitting
  updateData.onboardingStep = Math.max(1, (await DriverService.getDriverById(driverId))?.onboardingStep || 0);

  await DriverService.updateDriver(driverId, updateData);

  req.rData = { saved: true, onboardingStep: updateData.onboardingStep };
  req.msg = "success";
  next();
};

/**
 * Onboarding - Save driving licence
 */
export const saveDrivingLicence = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveDrivingLicence");

  const driverId = (req as any).driverId;
  const { licenceNumber, issueDate, expiryDate } = req.body;

  // Validations
  const dlErr = V.validateDrivingLicence(licenceNumber);
  if (dlErr) return res.status(400).json({ code: 0, message: dlErr, data: {} });
  const issueErr = V.validateDate(issueDate, "Issue date");
  if (issueErr) return res.status(400).json({ code: 0, message: issueErr, data: {} });
  const expiryErr = V.validateDate(expiryDate, "Expiry date");
  if (expiryErr) return res.status(400).json({ code: 0, message: expiryErr, data: {} });

  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  if (!files?.frontImage || !files?.backImage) {
    return res.status(400).json({ code: 0, message: "Both front and back images are required.", data: {} });
  }

  let frontImageUrl = "";
  let backImageUrl = "";

  if (files?.frontImage) {
    const result = await uploadMultipleFilesToAws(files.frontImage);
    frontImageUrl = Array.isArray(result.images)
      ? result.images[0]
      : result.images;
  }

  if (files?.backImage) {
    const result = await uploadMultipleFilesToAws(files.backImage);
    backImageUrl = Array.isArray(result.images)
      ? result.images[0]
      : result.images;
  }

  await DriverKycService.upsertDriverKyc(new Types.ObjectId(driverId), {
    drivingLicense: {
      number: licenceNumber,
      frontImage: frontImageUrl,
      backImage: backImageUrl,
      issueDate,
      expiryDate,
    },
  });

  // Update onboarding step to 2
  const driver = await DriverService.getDriverById(driverId);
  const newStep = Math.max(2, driver?.onboardingStep || 0);
  await DriverService.updateDriver(driverId, { onboardingStep: newStep });

  req.rData = { saved: true, onboardingStep: newStep };
  req.msg = "success";
  next();
};

/**
 * Onboarding - Save documents (Aadhar + PAN)
 */
export const saveDocuments = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveDocuments");

  const driverId = (req as any).driverId;
  const { aadharNumber, panNumber } = req.body;

  // Validations
  const aadharErr = V.validateAadhar(aadharNumber);
  if (aadharErr) return res.status(400).json({ code: 0, message: aadharErr, data: {} });
  const panErr = V.validatePAN(panNumber);
  if (panErr) return res.status(400).json({ code: 0, message: panErr, data: {} });

  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  if (!files?.aadharFrontImage || !files?.aadharBackImage) {
    return res.status(400).json({ code: 0, message: "Both front and back images of Aadhar card are required.", data: {} });
  }
  if (!files?.panFrontImage) {
    return res.status(400).json({ code: 0, message: "Front image of PAN card is required.", data: {} });
  }

  let aadharFrontUrl = "";
  let aadharBackUrl = "";
  let panFrontUrl = "";

  if (files?.aadharFrontImage) {
    const result = await uploadMultipleFilesToAws(files.aadharFrontImage);
    aadharFrontUrl = Array.isArray(result.images) ? result.images[0] : result.images;
  }
  if (files?.aadharBackImage) {
    const result = await uploadMultipleFilesToAws(files.aadharBackImage);
    aadharBackUrl = Array.isArray(result.images) ? result.images[0] : result.images;
  }
  if (files?.panFrontImage) {
    const result = await uploadMultipleFilesToAws(files.panFrontImage);
    panFrontUrl = Array.isArray(result.images) ? result.images[0] : result.images;
  }

  await DriverKycService.upsertDriverKyc(new Types.ObjectId(driverId), {
    aadhaar: {
      number: aadharNumber,
      frontImage: aadharFrontUrl,
      backImage: aadharBackUrl,
    },
    pan: {
      number: panNumber,
      frontImage: panFrontUrl,
    },
  });

  // Update onboarding step to 3
  const driver = await DriverService.getDriverById(driverId);
  const newStep = Math.max(3, driver?.onboardingStep || 0);
  await DriverService.updateDriver(driverId, { onboardingStep: newStep });

  req.rData = { saved: true, onboardingStep: newStep };
  req.msg = "success";
  next();
};

/**
 * Onboarding - Save address
 */
export const saveAddress = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveAddress");

  const driverId = (req as any).driverId;
  const { address, apartment, state, city, country, zipCode } = req.body;

  // Validations
  const addrErr = V.validateAddress(address);
  if (addrErr) return res.status(400).json({ code: 0, message: addrErr, data: {} });
  if (!state || state.trim().length === 0)
    return res.status(400).json({ code: 0, message: "State is required.", data: {} });
  if (!city || city.trim().length === 0)
    return res.status(400).json({ code: 0, message: "City is required.", data: {} });
  const zipErr = V.validateZipCode(zipCode);
  if (zipErr) return res.status(400).json({ code: 0, message: zipErr, data: {} });

  // Update onboarding step to 4
  const driver = await DriverService.getDriverById(driverId);
  const newStep = Math.max(4, driver?.onboardingStep || 0);

  await DriverService.updateDriver(driverId, {
    address,
    apartment,
    state,
    city,
    country,
    zipCode,
    onboardingStep: newStep,
  });

  req.rData = { saved: true, onboardingStep: newStep };
  req.msg = "success";
  next();
};

/**
 * Onboarding - Save bank details
 */
export const saveBankDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveBankDetails");

  const driverId = (req as any).driverId;
  const { bank, accountNumber, ifscCode } = req.body;

  // Validations
  if (!bank || bank.trim().length === 0)
    return res.status(400).json({ code: 0, message: "Please select a bank.", data: {} });
  const accErr = V.validateAccountNumber(accountNumber);
  if (accErr) return res.status(400).json({ code: 0, message: accErr, data: {} });
  const ifscErr = V.validateIFSC(ifscCode);
  if (ifscErr) return res.status(400).json({ code: 0, message: ifscErr, data: {} });

  const driver = await DriverService.getDriverById(driverId);
  await DriverService.updateDriver(driverId, {
    bankName: bank,
    accountNumber,
    ifscCode,
    onboardingStep: Math.max(5, driver?.onboardingStep || 0),
  });

  req.rData = { saved: true, onboardingStep: 5 };
  req.msg = "success";
  next();
};

// ============ VEHICLE TYPES & VEHICLE DETAILS ============

/**
 * Get all active vehicle types (for driver to select during onboarding)
 */
export const getVehicleTypes = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getVehicleTypes");

  const vehicleTypes = await VehicleType.find({ isActive: true })
    .populate("categoryId", "name code icon")
    .select("name description image maxSeats categoryId")
    .sort({ name: 1 });

  req.rData = { vehicleTypes };
  req.msg = "success";
  next();
};

/**
 * Save vehicle details (onboarding step 6)
 */
export const saveVehicleDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveVehicleDetails");

  const driverId = (req as any).driverId;
  const { vehicleTypeId, registrationNumber } = req.body;

  if (!vehicleTypeId) {
    return res.status(400).json({ code: 0, message: "Please select a vehicle type.", data: {} });
  }

  if (!registrationNumber || registrationNumber.trim().length < 4) {
    return res.status(400).json({ code: 0, message: "Please enter a valid registration number.", data: {} });
  }

  // Verify vehicle type exists
  const vehicleType = await VehicleType.findById(vehicleTypeId);
  if (!vehicleType) {
    return res.status(400).json({ code: 0, message: "Invalid vehicle type.", data: {} });
  }

  // Check if registration number already exists for another driver
  const regNum = registrationNumber.trim().toUpperCase();
  const existingVehicle = await DriverVehicle.findOne({
    registrationNumber: regNum,
    isDeleted: false,
  });

  if (existingVehicle && existingVehicle.driverId.toString() !== driverId.toString()) {
    return res.status(400).json({ code: 0, message: "This registration number is already registered.", data: {} });
  }

  // Upsert driver vehicle
  if (existingVehicle && existingVehicle.driverId.toString() === driverId.toString()) {
    existingVehicle.vehicleTypeId = new Types.ObjectId(vehicleTypeId);
    existingVehicle.registrationNumber = regNum;
    await existingVehicle.save();
  } else {
    // Check if driver already has a vehicle, update it
    const driverVehicle = await DriverVehicle.findOne({ driverId, isDeleted: false });
    if (driverVehicle) {
      driverVehicle.vehicleTypeId = new Types.ObjectId(vehicleTypeId);
      driverVehicle.registrationNumber = regNum;
      await driverVehicle.save();
    } else {
      await DriverVehicle.create({
        driverId: new Types.ObjectId(driverId),
        vehicleTypeId: new Types.ObjectId(vehicleTypeId),
        registrationNumber: regNum,
      });
    }
  }

  // Update driver step and status
  await DriverService.updateDriver(driverId, {
    status: "documents_uploaded",
    onboardingStep: Math.max(6, ((await DriverService.getDriverById(driverId))?.onboardingStep || 0)),
  });

  req.rData = { saved: true, onboardingStep: 6 };
  req.msg = "success";
  next();
};

/**
 * Upload vehicle images (selfie, front, right, left, back)
 */
export const uploadVehicleImages = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => uploadVehicleImages");

  const driverId = (req as any).driverId;

  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  if (!files || Object.keys(files).length === 0) {
    return res.status(400).json({ code: 0, message: "At least one image is required.", data: {} });
  }

  // Find driver's vehicle
  const vehicle = await DriverVehicle.findOne({ driverId, isDeleted: false });
  if (!vehicle) {
    return res.status(400).json({ code: 0, message: "Please add vehicle details first.", data: {} });
  }

  const imageFields = ["selfieImage", "frontImage", "rightImage", "leftImage", "backImage"];

  for (const field of imageFields) {
    if (files[field]) {
      const result = await uploadMultipleFilesToAws(files[field]);
      const url = Array.isArray(result.images) ? result.images[0] : result.images;
      (vehicle as any)[field] = url;
    }
  }

  await vehicle.save();

  // Update driver onboarding step to 7 and status
  const driver = await DriverService.getDriverById(driverId);
  const newStep = Math.max(7, driver?.onboardingStep || 0);
  await DriverService.updateDriver(driverId, {
    onboardingStep: newStep,
    status: "documents_uploaded",
  });

  req.rData = {
    saved: true,
    onboardingStep: newStep,
    images: {
      selfieImage: vehicle.selfieImage || "",
      frontImage: vehicle.frontImage || "",
      rightImage: vehicle.rightImage || "",
      leftImage: vehicle.leftImage || "",
      backImage: vehicle.backImage || "",
    },
  };
  req.msg = "success";
  next();
};

/**
 * Upload profile image
 */
export const uploadProfileImage = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => uploadProfileImage");

  const driverId = (req as any).driverId;
  const files = req.files as { [fieldname: string]: Express.Multer.File[] };

  if (!files?.profileImage) {
    return res.status(400).json({ code: 0, message: "Profile image is required.", data: {} });
  }

  const result = await uploadMultipleFilesToAws(files.profileImage);
  const imageUrl = Array.isArray(result.images) ? result.images[0] : result.images;

  await DriverService.updateDriver(driverId, { profileImage: imageUrl });

  req.rData = { profileImage: imageUrl };
  req.msg = "success";
  next();
};

// ============ CLEANING VENDOR ONBOARDING ============

/**
 * Get household service category tree (parents + their sub-categories).
 * Used by the cleaning-vendor onboarding flow to let the partner pick the
 * services they want to receive bookings for.
 */
export const getOnboardingServiceCategories = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getOnboardingServiceCategories");

  const categories = await ServiceCategory.find({ isActive: true })
    .select("-__v")
    .sort({ displayOrder: 1, name: 1 });

  // Build parent -> sub-categories tree (mirrors household.controller behavior).
  const parents = categories.filter((c) => !c.parentId);
  const tree = parents.map((parent) => ({
    ...parent.toObject(),
    subCategories: categories.filter(
      (c) => c.parentId?.toString() === parent._id?.toString(),
    ),
  }));

  req.rData = { categories: tree };
  req.msg = "success";
  next();
};

/**
 * Onboarding (cleaning vendor) — save the service categories + sub-categories
 * the partner is offering. Marks onboarding complete and moves the driver to
 * `under_verification` so admin can review.
 */
export const saveOnboardingServiceCategories = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveOnboardingServiceCategories");

  const driverId = (req as any).driverId;
  const rawIds = (req.body?.categoryIds ??
    req.body?.categories ??
    []) as unknown;

  if (!Array.isArray(rawIds) || rawIds.length === 0) {
    return res.status(400).json({
      code: 0,
      message: "Please select at least one service to continue.",
      data: {},
    });
  }

  // Validate IDs and ensure each refers to an active ServiceCategory
  const validIds: Types.ObjectId[] = [];
  for (const raw of rawIds) {
    const idStr = String(raw || "").trim();
    if (!Types.ObjectId.isValid(idStr)) continue;
    validIds.push(new Types.ObjectId(idStr));
  }

  if (validIds.length === 0) {
    return res.status(400).json({
      code: 0,
      message: "Invalid service categories selected.",
      data: {},
    });
  }

  const matched = await ServiceCategory.find({
    _id: { $in: validIds },
    isActive: true,
  }).select("_id");
  const matchedIds = matched.map((m) => m._id);

  if (matchedIds.length === 0) {
    return res.status(400).json({
      code: 0,
      message: "Selected services are no longer available.",
      data: {},
    });
  }

  const driver = await DriverService.getDriverById(driverId);
  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // For cleaning vendors the bank step is 5, so this is step 6 and onboarding
  // is considered complete (status -> documents_uploaded for admin review).
  const newStep = Math.max(7, driver.onboardingStep || 0);

  await DriverService.updateDriver(driverId, {
    householdCategories: matchedIds as any,
    serviceType: "cleaning",
    status: "documents_uploaded",
    onboardingStep: newStep,
  });

  req.rData = {
    saved: true,
    onboardingStep: newStep,
    categoryIds: matchedIds,
  };
  req.msg = "success";
  next();
};

/**
 * Save preferred work hours
 */
export const saveWorkHours = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => saveWorkHours");

  const driverId = (req as any).driverId;
  const { preferredWorkHours } = req.body;

  if (!preferredWorkHours) {
    req.rCode = 0;
    req.msg = "Please select work hours.";
    return next();
  }

  await DriverService.updateDriver(driverId, { preferredWorkHours });

  req.rData = { preferredWorkHours };
  req.msg = "success";
  next();
};

// ============ DRIVER SUPPORT CHAT ============

/**
 * Create or get existing support ticket for driver
 */
export const createSupportTicket = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => createSupportTicket");

  const driverId = (req as any).driverId;
  const { subject, description, category } = req.body;

  // Check if driver already has an open ticket
  let ticket = await SupportTicket.findOne({
    driverId: new Types.ObjectId(driverId),
    status: { $in: ["OPEN", "IN_PROGRESS"] },
  });

  if (!ticket) {
    ticket = await SupportTicket.create({
      driverId: new Types.ObjectId(driverId),
      subject: subject || "Driver Support",
      description: description || "Driver needs assistance",
      category: category || "OTHER",
      messages: [
        {
          senderId: new Types.ObjectId(driverId),
          senderType: "DRIVER",
          message: description || "Hello, I need help with my onboarding.",
        },
      ],
    });
  }

  req.rData = { ticket };
  req.msg = "success";
  next();
};

/**
 * Get driver's support tickets
 */
export const getSupportTickets = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getSupportTickets");

  const driverId = (req as any).driverId;

  const tickets = await SupportTicket.find({
    driverId: new Types.ObjectId(driverId),
  })
    .sort({ updatedAt: -1 })
    .limit(20);

  req.rData = { tickets };
  req.msg = "success";
  next();
};

/**
 * Add message to a support ticket
 */
export const addTicketMessage = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => addTicketMessage");

  const driverId = (req as any).driverId;
  const { ticketId } = req.params;
  const { message } = req.body;

  if (!message || message.trim().length === 0) {
    return res.status(400).json({ code: 0, message: "Message is required.", data: {} });
  }

  const ticket = await SupportTicket.findOneAndUpdate(
    { _id: ticketId, driverId: new Types.ObjectId(driverId) },
    {
      $push: {
        messages: {
          senderId: new Types.ObjectId(driverId),
          senderType: "DRIVER",
          message: message.trim(),
        },
      },
    },
    { new: true },
  );

  if (!ticket) {
    return res.status(404).json({ code: 0, message: "Ticket not found.", data: {} });
  }

  req.rData = { ticket };
  req.msg = "success";
  next();
};

/**
 * Driver: get road distance + duration via Google Distance Matrix
 * Used by the active-ride screen for "distance to pickup/drop" and the
 * distance-based arrival gate.
 */
export const getDistanceAndDuration = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getDistanceAndDuration");

  const { originLat, originLng, destLat, destLng } = req.query;

  const o = { lat: Number(originLat), lng: Number(originLng) };
  const d = { lat: Number(destLat), lng: Number(destLng) };

  if (!isFinite(o.lat) || !isFinite(o.lng) || !isFinite(d.lat) || !isFinite(d.lng)) {
    return res.status(400).json({ code: 0, message: "Invalid coordinates", data: {} });
  }

  const routeInfo = await MapsService.getDistanceAndDuration(o, d);

  req.rData = {
    distanceKm: routeInfo.distanceKm,
    distanceMeters: Math.round(routeInfo.distanceKm * 1000),
    durationMin: routeInfo.durationMin,
    distanceText: routeInfo.distanceText,
    durationText: routeInfo.durationText,
  };
  req.msg = "success";
  next();
};

/**
 * Mark cash payment as collected by the driver. Called from the
 * post-ride collect-cash screen — booking is already COMPLETED at this
 * point, this only flips the payment status from PENDING → PAID so
 * settlement reports treat the fare as received.
 */
export const markPaymentCollected = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => markPaymentCollected");

  const driverId = (req as any).driverId;
  const { bookingId } = req.params;

  const booking = await BookingService.getBookingById(bookingId);
  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  if (bookingDriverIdString(booking.driverId) !== driverId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  // Only allow flipping for cash bookings that are already complete.
  if (booking.status !== "COMPLETED") {
    req.rCode = 0;
    req.msg = "booking_not_completed";
    return next();
  }

  const updated = await BookingService.updateBooking(bookingId, {
    paymentStatus: "PAID",
  } as any);

  // Credit the driver wallet with their net earnings (fare minus
  // commission) now that the cash is in hand. Idempotent: WalletTransaction
  // uses the booking id as referenceId so a second call would create a
  // duplicate row — guard against that by checking for an existing entry.
  try {
    const bookingIdStr = (booking._id as Types.ObjectId).toString();
    const already = await WalletTransaction.findOne({
      userId: driverId,
      referenceId: bookingIdStr,
      type: "CREDIT",
    }).lean();

    if (!already) {
      // Recompute net earnings from the active commission config so the
      // wallet credit matches the Payout row created at completion.
      const config = await CommissionService.findMatchingConfig("cab", {
        vehicleTypeId: booking.vehicleTypeId,
      });
      let netEarnings = booking.finalFare;
      if (config) {
        const commission = CommissionService.calculateCommission(
          booking.finalFare,
          config,
        );
        netEarnings =
          Math.round((booking.finalFare - commission) * 100) / 100;
      }
      if (netEarnings > 0) {
        await WalletService.addToWallet(
          new Types.ObjectId(driverId),
          netEarnings,
          "Your Earning",
          bookingIdStr,
        );
      }
    }
  } catch (err) {
    console.error("Wallet credit failed for cash booking:", bookingId, err);
  }

  req.rData = { booking: updated };
  req.msg = "success";
  next();
};

/**
 * Driver: get driving route (encoded polyline + distance + duration).
 * Used by the active-ride map to draw the road path between origin and
 * destination instead of a straight-line approximation.
 */
export const getRoute = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getRoute");

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
  const minutes = directions.totalDurationMin;
  req.rData = {
    polyline: directions.polyline,
    distanceKm: km,
    distanceMeters: Math.round(km * 1000),
    durationMin: minutes,
  };
  req.msg = "success";
  next();
};

/**
 * Driver: list in-app notifications (paginated).
 */
export const getNotifications = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getNotifications");

  const driverId = (req as any).driverId;
  const { page = 1, limit = 20 } = req.query;

  const { Notification } = await import("../models/customer-features.model");

  const query = { driverId };
  const notifications = await Notification.find(query)
    .sort({ createdAt: -1 })
    .skip((Number(page) - 1) * Number(limit))
    .limit(Number(limit));

  const total = await Notification.countDocuments(query);
  const unreadCount = await Notification.countDocuments({
    ...query,
    isRead: false,
  });

  req.rData = {
    notifications,
    unreadCount,
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      pages: Math.ceil(total / Number(limit)),
    },
  };
  req.msg = "success";
  next();
};

/**
 * Driver: mark a single notification (or all) as read.
 * Pass `notificationId = "all"` to mark every unread notification read.
 */
export const markNotificationRead = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => markNotificationRead");

  const driverId = (req as any).driverId;
  const { notificationId } = req.params;

  const { Notification } = await import("../models/customer-features.model");

  if (notificationId === "all") {
    await Notification.updateMany(
      { driverId, isRead: false },
      { isRead: true, readAt: new Date() },
    );
  } else {
    await Notification.findOneAndUpdate(
      { _id: notificationId, driverId },
      { isRead: true, readAt: new Date() },
    );
  }

  req.rData = {};
  req.msg = "success";
  next();
};

// ============ DRIVER WALLET ============

/**
 * Get driver wallet balance + recent transactions.
 * GET /driver/app/wallet
 */
export const getWallet = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getWallet");
  const driverId = (req as any).driverId;
  const data = await WalletService.getWallet(new Types.ObjectId(driverId));
  req.rData = data;
  req.msg = "success";
  next();
};

/**
 * Get driver wallet transactions (paginated). Used by the Received /
 * Send / Statement screens to render a full grouped history.
 * GET /driver/app/wallet/transactions?type=CREDIT|DEBIT&page=0&limit=50
 */
export const getWalletTransactions = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => getWalletTransactions");
  const driverId = (req as any).driverId;
  const { type } = req.query as { type?: "CREDIT" | "DEBIT" };
  const page = Math.max(0, parseInt((req.query.page as string) || "0", 10));
  const limit = Math.min(
    100,
    Math.max(1, parseInt((req.query.limit as string) || "50", 10)),
  );

  const filter: Record<string, unknown> = { userId: driverId };
  if (type === "CREDIT" || type === "DEBIT") filter.type = type;

  const [transactions, total] = await Promise.all([
    WalletTransaction.find(filter)
      .sort({ createdAt: -1 })
      .skip(page * limit)
      .limit(limit),
    WalletTransaction.countDocuments(filter),
  ]);

  req.rData = { transactions, total, page, limit };
  req.msg = "success";
  next();
};

/**
 * Recharge the driver wallet. In production this would create a payment
 * order with Razorpay and the success webhook would credit the wallet —
 * for now we credit immediately so the flow is end-to-end testable.
 * POST /driver/app/wallet/recharge  body: { amount: number }
 */
export const rechargeWallet = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => rechargeWallet");
  const driverId = (req as any).driverId;
  const amount = Number(req.body?.amount);

  if (!Number.isFinite(amount) || amount <= 0) {
    req.rCode = 4;
    req.msg = "invalid_amount";
    return next();
  }

  const wallet = await WalletService.addToWallet(
    new Types.ObjectId(driverId),
    amount,
    "Wallet Recharge",
    `recharge-${Date.now()}`,
  );

  req.rData = { balance: wallet?.balance ?? 0 };
  req.msg = "wallet_recharged";
  next();
};

/**
 * Debit the driver wallet (Send Amount flow). The destination/payee is
 * not yet wired — this just records the debit so the Send Amount history
 * has data to show. When payouts are wired, the payee transfer should
 * happen here too.
 * POST /driver/app/wallet/send  body: { amount: number, description?: string }
 */
export const sendFromWallet = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("DriverController => sendFromWallet");
  const driverId = (req as any).driverId;
  const amount = Number(req.body?.amount);
  const description = (req.body?.description as string) || "Send Amount";

  if (!Number.isFinite(amount) || amount <= 0) {
    req.rCode = 4;
    req.msg = "invalid_amount";
    return next();
  }

  const wallet = await WalletService.deductFromWallet(
    new Types.ObjectId(driverId),
    amount,
    description,
    `send-${Date.now()}`,
  );

  if (!wallet) {
    req.rCode = 4;
    req.msg = "insufficient_balance";
    return next();
  }

  req.rData = { balance: wallet.balance };
  req.msg = "amount_sent";
  next();
};
