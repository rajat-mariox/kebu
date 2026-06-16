import { Types } from "mongoose";
import Driver from "../models/driver.model";
import Booking from "../models/booking.model";
import { IDriver, DriverStatus } from "../interfaces/driver";

/**
 * Create driver
 */
export const createDriver = async (data: Partial<IDriver>) => {
  return await Driver.create(data);
};

/**
 * Fetch driver by ID
 */
export const getDriverById = async (id: string | Types.ObjectId) => {
  return await Driver.findById(id).select("-__v");
};

/**
 * Fetch driver by query
 */
export const getDriverByQuery = async (query: any) => {
  return await Driver.findOne(query).select("-__v");
};

/**
 * Fetch driver by mobile number
 */
export const getDriverByMobile = async (
  mobileNumber: string,
  countryCode: string = "+91"
) => {
  return await Driver.findOne({
    mobileNumber,
    countryCode,
    isDeleted: false,
  });
};

/**
 * Update driver.
 *
 * Mongoose silently drops fields whose value is `undefined` from `$set`,
 * which historically caused `currentBookingId: undefined` clears to no-op
 * — leaving drivers stuck "busy" after cancellation/completion and hiding
 * them from the customer's nearby-drivers query (`currentBookingId: null`).
 * Translate any explicit `undefined` into `$unset` so the field is actually
 * removed from the document.
 */
export const updateDriver = async (
  driverId: string | Types.ObjectId,
  data: Partial<IDriver>
) => {
  const set: Record<string, unknown> = {};
  const unset: Record<string, ""> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined) {
      unset[key] = "";
    } else {
      set[key] = value;
    }
  }

  const update: Record<string, unknown> = {};
  if (Object.keys(set).length > 0) update.$set = set;
  if (Object.keys(unset).length > 0) update.$unset = unset;

  return await Driver.findByIdAndUpdate(driverId, update, {
    new: true,
    runValidators: true,
  });
};

/**
 * Clear `currentBookingId` on any driver whose pointer references a booking
 * that is no longer active (CANCELLED / COMPLETED / non-existent). Self-heals
 * stale state from past bugs or crashed processes that didn't release the
 * driver after a ride ended. Safe to run at every boot.
 *
 * Returns number of drivers patched.
 */
export const clearStaleDriverBookings = async (): Promise<number> => {
  // Active = anything that should legitimately keep a driver "busy"
  const activeStatuses = ["ASSIGNED", "DRIVER_ARRIVED", "PICKED", "IN_PROGRESS"];

  const activeBookings = await Booking.find(
    { status: { $in: activeStatuses } },
    { _id: 1 },
  ).lean();
  const activeIds = activeBookings.map((b) => b._id);

  const filter: Record<string, unknown> =
    activeIds.length > 0
      ? { currentBookingId: { $ne: null, $nin: activeIds } }
      : { currentBookingId: { $ne: null } };

  const result = await Driver.updateMany(filter, {
    $set: { currentBookingId: null },
  });

  return result.modifiedCount ?? 0;
};

/**
 * Update driver status
 */
export const updateDriverStatus = async (
  driverId: string | Types.ObjectId,
  status: DriverStatus,
  reason?: string
) => {
  const updateData: any = { status };

  if (status === "rejected" && reason) {
    updateData.rejectionReason = reason;
  }

  if (status === "suspended" && reason) {
    updateData.suspensionReason = reason;
  }

  return await Driver.findByIdAndUpdate(driverId, updateData, { new: true });
};
