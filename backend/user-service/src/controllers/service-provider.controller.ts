import { Request, Response, NextFunction } from "express";
import { v4 as uuidv4 } from "uuid";
import { Types } from "mongoose";

import * as HouseholdService from "../services/household.service";
import helpers from "../utils/helpers";
import redis from "../utils/redis";
import config from "../config";
import ServiceProvider from "../models/service-provider.model";
import ServiceBooking from "../models/service-booking.model";

/**
 * Service Provider Login - Step 1
 */
export const providerLogin = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("ServiceProviderController => providerLogin");

  const { mobileNumber, countryCode = "+91" } = req.body;

  const otp = helpers().generateOTP();

  const provider = await ServiceProvider.findOne({
    mobileNumber,
    countryCode,
    isDeleted: false,
  });

  const newTxnId = uuidv4();

  const otpData = {
    txnId: newTxnId,
    mobileNumber,
    countryCode,
    otp,
    reason: "PROVIDER OTP LOGIN",
    is_active: 1,
    date_created: new Date(),
    date_modified: new Date(),
  };

  await redis().SetRedis(
    `PROVIDER|txnId:${newTxnId}`,
    JSON.stringify(otpData),
    600,
  );
  await redis().SetRedis(
    `PROVIDER|Mob:${mobileNumber}`,
    JSON.stringify(otpData),
    600,
  );

  req.rData = {
    providerRegistered: !!provider,
    txnId: newTxnId,
  };

  req.msg = "otp_sent";
  next();
};

/**
 * Verify OTP - Step 2
 */
export const verifyProviderOtp = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("ServiceProviderController => verifyProviderOtp");

  const { otp, txnId } = req.body;

  const redisKey = `PROVIDER|txnId:${txnId}`;
  const redisKeys = await redis().GetKeys(redisKey);

  if (!redisKeys.length) {
    req.rCode = 0;
    req.msg = "incorrect_otp";
    return next();
  }

  const result = await redis().GetRedis<any>(redisKeys[0]);

  if (!result?.[0]) {
    req.rCode = 0;
    req.msg = "incorrect_otp";
    return next();
  }

  const otpData = result[0];
  const { mobileNumber, countryCode } = JSON.parse(otpData);

  // Master OTP check
  if (otp == config.auth.masterOtp) {
    let provider = await ServiceProvider.findOne({
      mobileNumber,
      countryCode,
      isDeleted: false,
    });

    if (!provider) {
      provider = await ServiceProvider.create({
        mobileNumber,
        countryCode,
        fullName: "",
        email: "",
        serviceCategories: [],
        city: "",
        state: "",
        status: "draft",
      });
    }

    const token = helpers().createJWT({ providerId: provider._id });

    req.rData = {
      token,
      providerId: provider._id,
      status: provider.status,
      isNewProvider: !provider.fullName,
    };
    req.msg = "otp_verified";
    return next();
  }

  // Normal OTP validation. Loose string compare so "881610" (request) and
  // 881610 (Redis number) match.
  if (String(otp) !== String(otpData.otp)) {
    req.rCode = 0;
    req.msg = "incorrect_otp";
    return next();
  }

  let provider = await ServiceProvider.findOne({
    mobileNumber,
    countryCode,
    isDeleted: false,
  });

  if (!provider) {
    provider = await ServiceProvider.create({
      mobileNumber,
      countryCode,
      fullName: "",
      email: "",
      serviceCategories: [],
      city: "",
      state: "",
      status: "draft",
    });
  }

  const token = helpers().createJWT({ providerId: provider._id });

  req.rData = {
    token,
    providerId: provider._id,
    status: provider.status,
    isNewProvider: !provider.fullName,
  };
  req.msg = "otp_verified";
  next();
};

/**
 * Get Provider Details
 */
export const getProviderDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;

  const provider = await ServiceProvider.findById(providerId)
    .populate("serviceCategories")
    .select("-__v");

  req.rData = { provider };
  req.msg = "success";
  next();
};

/**
 * Update Profile
 */
export const updateProfile = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const {
    fullName,
    email,
    serviceCategories,
    experience,
    hourlyRate,
    bio,
    city,
    state,
    address,
  } = req.body;

  const provider = await ServiceProvider.findByIdAndUpdate(
    providerId,
    {
      $set: {
        fullName,
        email,
        serviceCategories: serviceCategories?.map(
          (id: string) => new Types.ObjectId(id),
        ),
        experience,
        hourlyRate,
        bio,
        city,
        state,
        address,
        status: "pending_verification",
      },
    },
    { new: true },
  );

  req.rData = { provider };
  req.msg = "personal_info_updated";
  next();
};

/**
 * Update Location
 */
export const updateLocation = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const { latitude, longitude } = req.body;

  await ServiceProvider.findByIdAndUpdate(providerId, {
    location: {
      type: "Point",
      coordinates: [longitude, latitude],
    },
  });

  req.rData = { latitude, longitude };
  req.msg = "status_updated";
  next();
};

/**
 * Toggle Online Status
 */
export const toggleOnlineStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;

  const provider = await ServiceProvider.findById(providerId);

  if (!provider) {
    req.rCode = 0;
    req.msg = "provider_not_found";
    return next();
  }

  if (provider.status !== "approved") {
    req.rCode = 0;
    req.msg = "driver_not_approved";
    return next();
  }

  const newStatus = !provider.isOnline;
  await ServiceProvider.findByIdAndUpdate(providerId, { isOnline: newStatus });

  req.rData = { isOnline: newStatus };
  req.msg = newStatus ? "driver_online" : "driver_offline";
  next();
};

/**
 * Get Dashboard
 */
export const getDashboard = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;

  const provider = await ServiceProvider.findById(providerId);

  // Today's stats
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const todayBookings = await ServiceBooking.countDocuments({
    providerId: new Types.ObjectId(providerId),
    createdAt: { $gte: today },
  });

  const todayCompleted = await ServiceBooking.countDocuments({
    providerId: new Types.ObjectId(providerId),
    status: "COMPLETED",
    createdAt: { $gte: today },
  });

  const todayEarnings = await ServiceBooking.aggregate([
    {
      $match: {
        providerId: new Types.ObjectId(providerId),
        status: "COMPLETED",
        createdAt: { $gte: today },
      },
    },
    {
      $group: {
        _id: null,
        total: { $sum: "$finalAmount" },
      },
    },
  ]);

  req.rData = {
    isOnline: provider?.isOnline || false,
    status: provider?.status,
    rating: provider?.rating || 0,
    totalBookings: provider?.totalBookings || 0,
    todayBookings,
    todayCompleted,
    todayEarnings: todayEarnings[0]?.total || 0,
  };
  req.msg = "success";
  next();
};

/**
 * Get Active Booking
 */
export const getActiveBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;

  const activeBooking = await ServiceBooking.findOne({
    providerId: new Types.ObjectId(providerId),
    status: { $in: ["CONFIRMED", "PROVIDER_ASSIGNED", "IN_PROGRESS"] },
  })
    .populate("userId", "fullName mobileNumber profileImage")
    .populate("categoryId", "name icon")
    .sort({ createdAt: -1 });

  req.rData = { booking: activeBooking };
  req.msg = "success";
  next();
};

/**
 * Get Booking History
 */
export const getBookingHistory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const { page = 1, limit = 20 } = req.query;

  const bookings = await ServiceBooking.find({
    providerId: new Types.ObjectId(providerId),
    status: { $in: ["COMPLETED", "CANCELLED"] },
  })
    .populate("userId", "fullName mobileNumber profileImage")
    .populate("categoryId", "name icon")
    .sort({ createdAt: -1 })
    .skip((Number(page) - 1) * Number(limit))
    .limit(Number(limit));

  const total = await ServiceBooking.countDocuments({
    providerId: new Types.ObjectId(providerId),
    status: { $in: ["COMPLETED", "CANCELLED"] },
  });

  req.rData = {
    bookings,
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
 * Accept Booking
 */
export const acceptBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const { bookingId } = req.params;

  const booking = await ServiceBooking.findById(bookingId);

  if (!booking) {
    req.rCode = 0;
    req.msg = "booking_not_found";
    return next();
  }

  if (booking.status !== "PENDING") {
    req.rCode = 0;
    req.msg = "booking_not_available";
    return next();
  }

  const updatedBooking = await ServiceBooking.findByIdAndUpdate(
    bookingId,
    {
      providerId: new Types.ObjectId(providerId),
      status: "CONFIRMED",
    },
    { new: true },
  );

  // Notify user via socket
  const io = req.app.get("io");
  if (io && updatedBooking) {
    io.to(`user_${updatedBooking.userId}`).emit("service_confirmed", {
      booking: updatedBooking,
    });
  }

  req.rData = { booking: updatedBooking };
  req.msg = "booking_created";
  next();
};

/**
 * Update Booking Status
 */
export const updateBookingStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const { bookingId } = req.params;
  const { status, otp } = req.body;

  const booking = await ServiceBooking.findById(bookingId);

  if (!booking) {
    req.rCode = 0;
    req.msg = "booking_not_found";
    return next();
  }

  if (booking.providerId?.toString() !== providerId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  // Validate status transition
  const validTransitions: Record<string, string[]> = {
    CONFIRMED: ["PROVIDER_ASSIGNED", "CANCELLED"],
    PROVIDER_ASSIGNED: ["IN_PROGRESS", "CANCELLED"],
    IN_PROGRESS: ["COMPLETED", "CANCELLED"],
  };

  if (!validTransitions[booking.status]?.includes(status)) {
    req.rCode = 0;
    req.msg = "invalid_status_transition";
    return next();
  }

  // Verify OTP for starting service
  if (status === "IN_PROGRESS" && booking.otp !== otp) {
    req.rCode = 0;
    req.msg = "invalid_otp";
    return next();
  }

  const updateData: any = { status };

  if (status === "COMPLETED") {
    updateData.completedAt = new Date();

    // Update provider's total bookings
    await ServiceProvider.findByIdAndUpdate(providerId, {
      $inc: { totalBookings: 1 },
    });
  }

  const updatedBooking = await ServiceBooking.findByIdAndUpdate(
    bookingId,
    { $set: updateData },
    { new: true },
  );

  // Notify user
  const io = req.app.get("io");
  if (io && updatedBooking) {
    const eventMap: Record<string, string> = {
      PROVIDER_ASSIGNED: "provider_on_way",
      IN_PROGRESS: "service_started",
      COMPLETED: "service_completed",
    };

    const event = eventMap[status];
    if (event) {
      io.to(`user_${updatedBooking.userId}`).emit(event, {
        booking: updatedBooking,
      });
    }
  }

  req.rData = { booking: updatedBooking };
  req.msg = "status_updated";
  next();
};

/**
 * Cancel Booking
 */
export const cancelBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const { bookingId } = req.params;
  const { reason } = req.body;

  const booking = await ServiceBooking.findById(bookingId);

  if (!booking) {
    req.rCode = 0;
    req.msg = "booking_not_found";
    return next();
  }

  if (booking.providerId?.toString() !== providerId.toString()) {
    req.rCode = 4;
    req.msg = "unauthorized";
    return next();
  }

  const cancellableStatuses = ["CONFIRMED", "PROVIDER_ASSIGNED"];
  if (!cancellableStatuses.includes(booking.status)) {
    req.rCode = 0;
    req.msg = "booking_cannot_be_cancelled";
    return next();
  }

  const updatedBooking = await ServiceBooking.findByIdAndUpdate(
    bookingId,
    {
      status: "CANCELLED",
      cancellationReason: reason,
      cancelledBy: "PROVIDER",
      cancelledAt: new Date(),
    },
    { new: true },
  );

  // Notify user
  const io = req.app.get("io");
  if (io && updatedBooking) {
    io.to(`user_${updatedBooking.userId}`).emit("service_cancelled", {
      booking: updatedBooking,
      cancelledBy: "PROVIDER",
      reason,
    });
  }

  req.rData = { booking: updatedBooking };
  req.msg = "booking_cancelled";
  next();
};

/**
 * Get Earnings
 */
export const getEarnings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;
  const { period = "week" } = req.query;

  let startDate = new Date();
  if (period === "week") {
    startDate.setDate(startDate.getDate() - 7);
  } else if (period === "month") {
    startDate.setMonth(startDate.getMonth() - 1);
  } else if (period === "year") {
    startDate.setFullYear(startDate.getFullYear() - 1);
  }

  const earnings = await ServiceBooking.aggregate([
    {
      $match: {
        providerId: new Types.ObjectId(providerId),
        status: "COMPLETED",
        completedAt: { $gte: startDate },
      },
    },
    {
      $group: {
        _id: {
          $dateToString: { format: "%Y-%m-%d", date: "$completedAt" },
        },
        amount: { $sum: "$finalAmount" },
        bookings: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  const totalEarnings = earnings.reduce((sum, e) => sum + e.amount, 0);
  const totalBookings = earnings.reduce((sum, e) => sum + e.bookings, 0);

  req.rData = {
    period,
    totalEarnings,
    totalBookings,
    daily: earnings,
  };
  req.msg = "success";
  next();
};

/**
 * Resend OTP
 */
export const resendProviderOtp = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { mobileNumber, countryCode = "+91" } = req.body;

  const otp = helpers().generateOTP();
  const newTxnId = uuidv4();

  const otpData = {
    txnId: newTxnId,
    mobileNumber,
    countryCode,
    otp,
    reason: "PROVIDER OTP RESEND",
    is_active: 1,
    date_created: new Date(),
    date_modified: new Date(),
  };

  await redis().SetRedis(
    `PROVIDER|txnId:${newTxnId}`,
    JSON.stringify(otpData),
    600,
  );
  await redis().SetRedis(
    `PROVIDER|Mob:${mobileNumber}`,
    JSON.stringify(otpData),
    600,
  );

  const provider = await ServiceProvider.findOne({
    mobileNumber,
    countryCode,
    isDeleted: false,
  });

  req.rData = {
    providerRegistered: !!provider,
    txnId: newTxnId,
  };

  req.msg = "otp_sent";
  next();
};

/**
 * Logout
 */
export const providerLogout = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const providerId = (req as any).providerId;

  await ServiceProvider.findByIdAndUpdate(providerId, {
    isOnline: false,
  });

  req.msg = "logout_success";
  next();
};
