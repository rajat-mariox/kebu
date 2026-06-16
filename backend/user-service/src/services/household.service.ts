import ServiceCategory from "../models/service-category.model";
import ServiceProvider from "../models/service-provider.model";
import ServiceBooking from "../models/service-booking.model";
import {
  IServiceBooking,
  ServiceBookingStatus,
} from "../models/service-booking.model";
import HouseholdServiceHours from "../models/household-service-hours.model";
import { Types } from "mongoose";
import * as CommissionService from "./commission.service";

// ========== SERVICE HOURS ==========

export const DEFAULT_SERVICE_HOURS = {
  openTime: "06:00",
  closeTime: "20:00",
  daysActive: [0, 1, 2, 3, 4, 5, 6],
  timezone: "Asia/Kolkata",
  isEnabled: true,
};

export const getServiceHours = async () => {
  let hours = await HouseholdServiceHours.findOne().sort({ updatedAt: -1 });
  if (!hours) {
    hours = await HouseholdServiceHours.create(DEFAULT_SERVICE_HOURS);
    return hours;
  }

  // Self-heal records that predate the current defaults or have bad values
  // (e.g. seeded during an older run with wrong times / empty daysActive).
  let changed = false;
  if (!hours.openTime || !/^([01]\d|2[0-3]):[0-5]\d$/.test(hours.openTime)) {
    hours.openTime = DEFAULT_SERVICE_HOURS.openTime;
    changed = true;
  }
  if (!hours.closeTime || !/^([01]\d|2[0-3]):[0-5]\d$/.test(hours.closeTime)) {
    hours.closeTime = DEFAULT_SERVICE_HOURS.closeTime;
    changed = true;
  }
  if (!Array.isArray(hours.daysActive) || hours.daysActive.length === 0) {
    hours.daysActive = [...DEFAULT_SERVICE_HOURS.daysActive];
    changed = true;
  }
  if (!hours.timezone) {
    hours.timezone = DEFAULT_SERVICE_HOURS.timezone;
    changed = true;
  }
  if (changed) await hours.save();
  return hours;
};

export const updateServiceHours = async (
  data: Partial<{
    openTime: string;
    closeTime: string;
    daysActive: number[];
    timezone: string;
    isEnabled: boolean;
    closedMessage: string;
  }>,
  adminId?: Types.ObjectId,
) => {
  const existing = await HouseholdServiceHours.findOne().sort({ updatedAt: -1 });
  if (!existing) {
    return await HouseholdServiceHours.create({
      ...DEFAULT_SERVICE_HOURS,
      ...data,
      updatedBy: adminId,
    });
  }
  Object.assign(existing, data);
  if (adminId) existing.updatedBy = adminId;
  return await existing.save();
};

const toMinutes = (t: string) => {
  const [h, m] = t.split(":").map(Number);
  return h * 60 + m;
};

export const computeOpenStatus = (
  hours: {
    openTime: string;
    closeTime: string;
    daysActive: number[];
    timezone: string;
    isEnabled: boolean;
  },
  now: Date = new Date(),
) => {
  if (!hours.isEnabled) {
    return { isOpen: false, reason: "disabled" as const };
  }

  // Use Intl.DateTimeFormat.formatToParts() for reliable TZ-aware extraction
  // (avoids locale-dependent string formats from toLocaleString).
  let currentDay: number;
  let currentMinutes: number;
  try {
    const fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: hours.timezone || "Asia/Kolkata",
      hour12: false,
      weekday: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
    const parts = fmt.formatToParts(now);
    const weekdayShort =
      parts.find((p) => p.type === "weekday")?.value ?? "Sun";
    const hourStr = parts.find((p) => p.type === "hour")?.value ?? "00";
    const minuteStr = parts.find((p) => p.type === "minute")?.value ?? "00";
    const dayMap: Record<string, number> = {
      Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
    };
    currentDay = dayMap[weekdayShort] ?? now.getDay();
    // Node's hour12:false sometimes yields "24" at midnight — normalize to 0.
    const hh = Number(hourStr) % 24;
    const mm = Number(minuteStr);
    currentMinutes = hh * 60 + mm;
  } catch {
    currentDay = now.getDay();
    currentMinutes = now.getHours() * 60 + now.getMinutes();
  }

  if (!hours.daysActive || hours.daysActive.length === 0) {
    return { isOpen: false, reason: "day_off" as const };
  }
  if (!hours.daysActive.includes(currentDay)) {
    return { isOpen: false, reason: "day_off" as const };
  }
  const openM = toMinutes(hours.openTime);
  const closeM = toMinutes(hours.closeTime);
  const isOpen =
    closeM > openM
      ? currentMinutes >= openM && currentMinutes < closeM
      : currentMinutes >= openM || currentMinutes < closeM;
  return {
    isOpen,
    reason: isOpen ? ("open" as const) : ("outside_hours" as const),
  };
};

// ========== CATEGORY SERVICES ==========

export const getAllCategories = async (activeOnly = true) => {
  const query: any = {};
  if (activeOnly) query.isActive = true;

  return await ServiceCategory.find(query)
    .sort({ displayOrder: 1, name: 1 })
    .select("-__v");
};

export const getCategoryById = async (id: string | Types.ObjectId) => {
  return await ServiceCategory.findById(id).select("-__v");
};

export const getSubCategories = async (parentId: Types.ObjectId) => {
  return await ServiceCategory.find({ parentId, isActive: true })
    .sort({ displayOrder: 1 })
    .select("-__v");
};

// ========== PROVIDER SERVICES ==========

export const findNearbyProviders = async (
  lat: number,
  lng: number,
  categoryId: Types.ObjectId,
  maxDistanceKm = 10,
) => {
  return await ServiceProvider.find({
    location: {
      $near: {
        $geometry: { type: "Point", coordinates: [lng, lat] },
        $maxDistance: maxDistanceKm * 1000,
      },
    },
    serviceCategories: categoryId,
    isOnline: true,
    status: "approved",
    isActive: true,
    isDeleted: false,
  })
    .select("fullName profileImage rating totalJobs hourlyRate minimumCharge")
    .limit(20);
};

/**
 * Count online, approved, active service providers near a location.
 * Used by the household home screen ("N experts currently active around you").
 * categoryId is optional — when omitted, counts experts across all categories.
 */
export const countNearbyActiveProviders = async (
  lat: number,
  lng: number,
  maxDistanceKm = 10,
  categoryId?: Types.ObjectId,
) => {
  const query: any = {
    location: {
      $near: {
        $geometry: { type: "Point", coordinates: [lng, lat] },
        $maxDistance: maxDistanceKm * 1000,
      },
    },
    isOnline: true,
    status: "approved",
    isActive: true,
    isDeleted: false,
  };
  if (categoryId) query.serviceCategories = categoryId;
  return await ServiceProvider.countDocuments(query);
};

export const getProviderById = async (id: string | Types.ObjectId) => {
  return await ServiceProvider.findById(id)
    .populate("serviceCategories", "name icon")
    .select("-__v");
};

export const getProvidersByCategory = async (
  categoryId: Types.ObjectId,
  page = 0,
  limit = 20,
) => {
  return await ServiceProvider.find({
    serviceCategories: categoryId,
    status: "approved",
    isActive: true,
    isDeleted: false,
  })
    .select(
      "fullName profileImage rating totalJobs hourlyRate minimumCharge city",
    )
    .sort({ rating: -1, totalJobs: -1 })
    .skip(page * limit)
    .limit(limit);
};

// ========== BOOKING SERVICES ==========

export const createServiceBooking = async (data: Partial<IServiceBooking>) => {
  return await ServiceBooking.create(data);
};

export const getServiceBookingById = async (id: string | Types.ObjectId) => {
  return await ServiceBooking.findById(id)
    .populate("userId", "fullName mobileNumber email")
    .populate("providerId", "fullName mobileNumber profileImage rating")
    .populate("categoryId", "name icon")
    .select("-__v");
};

export const getUserServiceBookings = async (
  userId: Types.ObjectId,
  page = 0,
  limit = 10,
  status?: ServiceBookingStatus,
) => {
  const query: any = { userId };
  if (status) query.status = status;

  return await ServiceBooking.find(query)
    .populate("providerId", "fullName mobileNumber profileImage rating")
    .populate("categoryId", "name icon")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);
};

export const getProviderServiceBookings = async (
  providerId: Types.ObjectId,
  page = 0,
  limit = 10,
  status?: ServiceBookingStatus,
) => {
  const query: any = { providerId };
  if (status) query.status = status;

  return await ServiceBooking.find(query)
    .populate("userId", "fullName mobileNumber")
    .populate("categoryId", "name icon")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);
};

export const getActiveUserServiceBooking = async (userId: Types.ObjectId) => {
  return await ServiceBooking.findOne({
    userId,
    status: {
      $in: [
        "PENDING",
        "ACCEPTED",
        "PROVIDER_ASSIGNED",
        "PROVIDER_EN_ROUTE",
        "PROVIDER_ARRIVED",
        "IN_PROGRESS",
      ],
    },
  })
    .populate("providerId", "fullName mobileNumber profileImage rating")
    .populate("categoryId", "name icon")
    .select("-__v")
    .sort({ createdAt: -1 });
};

export const getActiveProviderServiceBooking = async (
  providerId: Types.ObjectId,
) => {
  return await ServiceBooking.findOne({
    providerId,
    status: {
      $in: [
        "PROVIDER_ASSIGNED",
        "PROVIDER_EN_ROUTE",
        "PROVIDER_ARRIVED",
        "IN_PROGRESS",
      ],
    },
  })
    .select("_id userId status")
    .sort({ createdAt: -1 });
};

export const updateServiceBookingStatus = async (
  bookingId: string | Types.ObjectId,
  status: ServiceBookingStatus,
  additionalData?: any,
) => {
  const updateData: any = { status, ...additionalData };

  switch (status) {
    case "ACCEPTED":
      updateData.acceptedAt = new Date();
      break;
    case "PROVIDER_ARRIVED":
      updateData.providerArrivedAt = new Date();
      break;
    case "IN_PROGRESS":
      updateData.startedAt = new Date();
      break;
    case "COMPLETED":
      updateData.completedAt = new Date();
      break;
    case "CANCELLED":
      updateData.cancelledAt = new Date();
      break;
  }

  const updated = await ServiceBooking.findByIdAndUpdate(bookingId, updateData, {
    new: true,
  })
    .populate("userId", "fullName mobileNumber")
    .populate("providerId", "fullName mobileNumber profileImage rating")
    .populate("categoryId", "name icon");

  // Calculate and record commission on service completion
  if (status === "COMPLETED" && updated && updated.providerId && updated.finalCost) {
    try {
      await CommissionService.processHouseholdCommission({
        _id: updated._id,
        providerId: updated.providerId,
        categoryId: updated.categoryId,
        finalCost: updated.finalCost,
        completedAt: updated.completedAt,
      });
    } catch (err) {
      console.error("Commission calculation failed for household booking:", updated._id, err);
    }
  }

  return updated;
};

export const assignProviderToBooking = async (
  bookingId: string | Types.ObjectId,
  providerId: Types.ObjectId,
) => {
  return await updateServiceBookingStatus(bookingId, "PROVIDER_ASSIGNED", {
    providerId,
  });
};

export const cancelServiceBooking = async (
  bookingId: string | Types.ObjectId,
  cancelledBy: "USER" | "PROVIDER" | "SYSTEM",
  cancellationReason?: string,
) => {
  return await updateServiceBookingStatus(bookingId, "CANCELLED", {
    cancelledBy,
    cancellationReason,
  });
};

export const countServiceBookings = async (query: any) => {
  return await ServiceBooking.countDocuments(query);
};

export const rateServiceBooking = async (
  bookingId: string | Types.ObjectId,
  ratingBy: "user" | "provider",
  rating: number,
  feedback?: string,
) => {
  const updateData: any =
    ratingBy === "user"
      ? { userRating: rating, userFeedback: feedback }
      : { providerRating: rating, providerFeedback: feedback };

  const booking = await ServiceBooking.findByIdAndUpdate(
    bookingId,
    updateData,
    {
      new: true,
    },
  );

  // Update provider's overall rating
  if (ratingBy === "user" && booking?.providerId) {
    const provider = await ServiceProvider.findById(booking.providerId);
    if (provider) {
      const newTotalRatings = provider.totalRatings + 1;
      const newRating =
        (provider.rating * provider.totalRatings + rating) / newTotalRatings;

      await ServiceProvider.findByIdAndUpdate(booking.providerId, {
        rating: Math.round(newRating * 10) / 10,
        totalRatings: newTotalRatings,
      });
    }
  }

  return booking;
};
