import { Types } from "mongoose";
import {
  CommissionConfig,
  ICommissionConfig,
  Payout,
} from "../models/pricing-config.model";

export interface CommissionResult {
  commissionAmount: number;
  netEarnings: number;
  configId: Types.ObjectId;
  configName: string;
  commissionType: "percentage" | "flat";
  commissionValue: number;
}

/**
 * Find the best matching commission config for a service type.
 * Priority: vehicleTypeId/serviceCategoryId-specific > generic active config.
 */
export const findMatchingConfig = async (
  serviceType: "cab" | "delivery" | "household",
  options?: {
    vehicleTypeId?: Types.ObjectId | string;
    serviceCategoryId?: Types.ObjectId | string;
  },
): Promise<ICommissionConfig | null> => {
  const baseQuery = { serviceType, isActive: true };

  // First try to find a specific config (matching vehicle type or service category)
  if (options?.vehicleTypeId) {
    const specific = await CommissionConfig.findOne({
      ...baseQuery,
      vehicleTypeId: options.vehicleTypeId,
    }).lean();
    if (specific) return specific;
  }

  if (options?.serviceCategoryId) {
    const specific = await CommissionConfig.findOne({
      ...baseQuery,
      serviceCategoryId: options.serviceCategoryId,
    }).lean();
    if (specific) return specific;
  }

  // Fall back to a generic config (no vehicleTypeId and no serviceCategoryId)
  return CommissionConfig.findOne({
    ...baseQuery,
    vehicleTypeId: { $exists: false },
    serviceCategoryId: { $exists: false },
  })
    .sort({ createdAt: -1 })
    .lean();
};

/**
 * Calculate commission amount based on config rules.
 */
export const calculateCommission = (
  fare: number,
  config: ICommissionConfig,
): number => {
  let commission: number;

  if (config.commissionType === "percentage") {
    commission = (fare * config.value) / 100;
  } else {
    // flat
    commission = config.value;
  }

  // Apply min/max bounds
  if (config.minCommission && commission < config.minCommission) {
    commission = config.minCommission;
  }
  if (config.maxCommission && commission > config.maxCommission) {
    commission = config.maxCommission;
  }

  // Commission cannot exceed fare
  commission = Math.min(commission, fare);

  return Math.round(commission * 100) / 100; // round to 2 decimals
};

/**
 * Process commission for a completed cab booking.
 */
export const processCabCommission = async (booking: {
  _id: Types.ObjectId | string;
  driverId: Types.ObjectId | string;
  vehicleTypeId?: Types.ObjectId | string;
  finalFare: number;
  completedAt?: Date;
}): Promise<CommissionResult | null> => {
  const config = await findMatchingConfig("cab", {
    vehicleTypeId: booking.vehicleTypeId,
  });

  if (!config || !config._id) return null;

  const commission = calculateCommission(booking.finalFare, config);
  const net = Math.round((booking.finalFare - commission) * 100) / 100;

  // Get driver name
  const Driver = (await import("../models/driver.model")).default;
  const driver = await Driver.findById(booking.driverId)
    .select("fullName")
    .lean();

  const now = new Date();
  const dayStart = new Date(now);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(now);
  dayEnd.setHours(23, 59, 59, 999);

  await Payout.create({
    recipientType: "driver",
    recipientId: booking.driverId,
    recipientName: driver?.fullName || "Unknown Driver",
    serviceType: "cab",
    period: { start: dayStart, end: dayEnd },
    totalEarnings: booking.finalFare,
    totalCommission: commission,
    totalDeductions: 0,
    netPayout: net,
    bookingCount: 1,
    status: "pending",
  });

  return {
    commissionAmount: commission,
    netEarnings: net,
    configId: config._id,
    configName: config.name,
    commissionType: config.commissionType,
    commissionValue: config.value,
  };
};

/**
 * Process commission for a completed delivery.
 */
export const processDeliveryCommission = async (delivery: {
  _id: Types.ObjectId | string;
  driverId: Types.ObjectId | string;
  finalFare: number;
  deliveredAt?: Date;
}): Promise<CommissionResult | null> => {
  const config = await findMatchingConfig("delivery");

  if (!config || !config._id) return null;

  const commission = calculateCommission(delivery.finalFare, config);
  const net = Math.round((delivery.finalFare - commission) * 100) / 100;

  const Driver = (await import("../models/driver.model")).default;
  const driver = await Driver.findById(delivery.driverId)
    .select("fullName")
    .lean();

  const now = new Date();
  const dayStart = new Date(now);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(now);
  dayEnd.setHours(23, 59, 59, 999);

  await Payout.create({
    recipientType: "driver",
    recipientId: delivery.driverId,
    recipientName: driver?.fullName || "Unknown Driver",
    serviceType: "delivery",
    period: { start: dayStart, end: dayEnd },
    totalEarnings: delivery.finalFare,
    totalCommission: commission,
    totalDeductions: 0,
    netPayout: net,
    bookingCount: 1,
    status: "pending",
  });

  return {
    commissionAmount: commission,
    netEarnings: net,
    configId: config._id,
    configName: config.name,
    commissionType: config.commissionType,
    commissionValue: config.value,
  };
};

/**
 * Process commission for a completed household service booking.
 */
export const processHouseholdCommission = async (booking: {
  _id: Types.ObjectId | string;
  providerId: Types.ObjectId | string;
  categoryId?: Types.ObjectId | string;
  finalCost: number;
  completedAt?: Date;
}): Promise<CommissionResult | null> => {
  const config = await findMatchingConfig("household", {
    serviceCategoryId: booking.categoryId,
  });

  if (!config || !config._id) return null;

  const commission = calculateCommission(booking.finalCost, config);
  const net = Math.round((booking.finalCost - commission) * 100) / 100;

  const Driver = (await import("../models/driver.model")).default;
  const provider = await Driver.findById(booking.providerId)
    .select("fullName")
    .lean();

  const now = new Date();
  const dayStart = new Date(now);
  dayStart.setHours(0, 0, 0, 0);
  const dayEnd = new Date(now);
  dayEnd.setHours(23, 59, 59, 999);

  await Payout.create({
    recipientType: "provider",
    recipientId: booking.providerId,
    recipientName: provider?.fullName || "Unknown Provider",
    serviceType: "household",
    period: { start: dayStart, end: dayEnd },
    totalEarnings: booking.finalCost,
    totalCommission: commission,
    totalDeductions: 0,
    netPayout: net,
    bookingCount: 1,
    status: "pending",
  });

  return {
    commissionAmount: commission,
    netEarnings: net,
    configId: config._id,
    configName: config.name,
    commissionType: config.commissionType,
    commissionValue: config.value,
  };
};
