import Booking from "../models/booking.model";
import { IBooking, BookingStatus } from "../interfaces/booking";
import { Types } from "mongoose";

/**
 * Create booking
 */
export const createBooking = async (data: Partial<IBooking>) => {
  return await Booking.create(data);
};

/**
 * Get booking by ID
 */
export const getBookingById = async (id: string | Types.ObjectId) => {
  return await Booking.findById(id)
    .populate("userId", "fullName mobileNumber email profileImage")
    .populate(
      "driverId",
      "fullName mobileNumber rating profileImage totalRides"
    )
    .populate("vehicleTypeId")
    .populate("riderId")
    .select("-__v");
};

/**
 * Get user bookings
 */
export const getUserBookings = async (
  userId: Types.ObjectId,
  page = 0,
  limit = 10,
  status?: BookingStatus
) => {
  const query: any = { userId };

  if (status) {
    query.status = status;
  }

  return await Booking.find(query)
    .populate(
      "driverId",
      "fullName mobileNumber rating profileImage totalRides"
    )
    .populate("vehicleTypeId")
    .populate("riderId")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);
};

/**
 * Get driver bookings
 */
export const getDriverBookings = async (
  driverId: Types.ObjectId,
  page = 0,
  limit = 10,
  status?: BookingStatus
) => {
  const query: any = { driverId };

  if (status) {
    query.status = status;
  }

  return await Booking.find(query)
    .populate("userId", "fullName mobileNumber")
    .populate("vehicleTypeId")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);
};

/**
 * Get active booking for user
 */
export const getActiveUserBooking = async (userId: Types.ObjectId) => {
  return await Booking.findOne({
    userId,
    status: {
      $in: ["SEARCHING", "ASSIGNED", "DRIVER_ARRIVED", "PICKED", "IN_PROGRESS"],
    },
  })
    .populate(
      "driverId",
      "fullName mobileNumber rating profileImage totalRides"
    )
    .populate("vehicleTypeId")
    .populate("riderId")
    .select("-__v")
    .sort({ createdAt: -1 });
};

/**
 * Get active booking for driver
 */
export const getActiveDriverBooking = async (driverId: Types.ObjectId) => {
  return await Booking.findOne({
    driverId,
    status: {
      $in: ["ASSIGNED", "DRIVER_ARRIVED", "PICKED", "IN_PROGRESS"],
    },
  })
    .populate("userId", "fullName mobileNumber")
    .populate("vehicleTypeId")
    .select("-__v");
};

/**
 * Update booking
 */
export const updateBooking = async (
  bookingId: string | Types.ObjectId,
  updateData: Partial<IBooking>
) => {
  return await Booking.findByIdAndUpdate(bookingId, updateData, { new: true });
};

/**
 * Update booking status
 */
export const updateBookingStatus = async (
  bookingId: string | Types.ObjectId,
  status: BookingStatus,
  additionalData?: any
) => {
  const updateData: any = { status, ...additionalData };

  // Set timestamps based on status
  switch (status) {
    case "ASSIGNED":
      updateData.assignedAt = new Date();
      break;
    case "DRIVER_ARRIVED":
      updateData.driverArrivedAt = new Date();
      break;
    case "PICKED":
      updateData.pickedAt = new Date();
      break;
    case "COMPLETED":
      updateData.completedAt = new Date();
      break;
    case "CANCELLED":
      updateData.cancelledAt = new Date();
      break;
  }

  return await Booking.findByIdAndUpdate(bookingId, updateData, { new: true })
    .populate("userId", "fullName mobileNumber")
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId");
};

/**
 * Assign driver to booking (atomic — prevents race condition)
 * Returns null if booking was already taken by another driver.
 */
export const assignDriverToBooking = async (
  bookingId: string | Types.ObjectId,
  driverId: Types.ObjectId
) => {
  const result = await Booking.findOneAndUpdate(
    { _id: bookingId, status: "SEARCHING" },
    {
      $set: {
        driverId,
        status: "ASSIGNED",
        assignedAt: new Date(),
      },
    },
    { new: true }
  )
    .populate("userId", "fullName mobileNumber")
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId");

  return result;
};

/**
 * Cancel booking
 */
export const cancelBooking = async (
  bookingId: string | Types.ObjectId,
  cancelledBy: "USER" | "DRIVER" | "SYSTEM",
  cancellationReason?: string
) => {
  return await updateBookingStatus(bookingId, "CANCELLED", {
    cancelledBy,
    cancellationReason,
    cancelledAt: new Date(),
  });
};

/**
 * Rate booking
 */
export const rateBooking = async (
  bookingId: string | Types.ObjectId,
  rating: number,
  feedback?: string
) => {
  const booking = await Booking.findByIdAndUpdate(
    bookingId,
    { rating, feedback },
    { new: true }
  );

  // Reflect the new rating on the driver's profile by recomputing their
  // average across all rated bookings.
  if (booking && booking.driverId) {
    await recomputeDriverRating(booking.driverId);
  }

  return booking;
};

/**
 * Recompute a driver's average rating from all their rated bookings and
 * persist it on the driver record (so it shows on the driver profile).
 */
export const recomputeDriverRating = async (
  driverId: string | Types.ObjectId
) => {
  const id = new Types.ObjectId(String(driverId));
  const result = await Booking.aggregate([
    { $match: { driverId: id, rating: { $gt: 0 } } },
    {
      $group: {
        _id: "$driverId",
        avg: { $avg: "$rating" },
        count: { $sum: 1 },
      },
    },
  ]);

  const avg = result[0]?.avg ?? 0;
  // Round to 1 decimal place (e.g. 4.3).
  const rounded = Math.round(avg * 10) / 10;

  const Driver = (await import("../models/driver.model")).default;
  await Driver.findByIdAndUpdate(id, { rating: rounded });
  return rounded;
};

/**
 * Count bookings
 */
export const countBookings = async (query: any) => {
  return await Booking.countDocuments(query);
};

/**
 * Get bookings statistics
 */
export const getBookingStats = async (startDate?: Date, endDate?: Date) => {
  const matchQuery: any = {};

  if (startDate || endDate) {
    matchQuery.createdAt = {};
    if (startDate) matchQuery.createdAt.$gte = startDate;
    if (endDate) matchQuery.createdAt.$lte = endDate;
  }

  const stats = await Booking.aggregate([
    { $match: matchQuery },
    {
      $group: {
        _id: "$status",
        count: { $sum: 1 },
        totalRevenue: { $sum: "$finalFare" },
      },
    },
  ]);

  return stats;
};
