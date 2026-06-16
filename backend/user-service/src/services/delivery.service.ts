import Delivery from "../models/delivery.model";
import { IDelivery, DeliveryStatus } from "../models/delivery.model";
import { Types } from "mongoose";
import * as CommissionService from "./commission.service";

/**
 * Create delivery
 */
export const createDelivery = async (data: Partial<IDelivery>) => {
  return await Delivery.create(data);
};

/**
 * Get delivery by ID
 */
export const getDeliveryById = async (id: string | Types.ObjectId) => {
  return await Delivery.findById(id)
    .populate("userId", "fullName mobileNumber email")
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId")
    .select("-__v");
};

/**
 * Get user deliveries
 */
export const getUserDeliveries = async (
  userId: Types.ObjectId,
  page = 0,
  limit = 10,
  status?: DeliveryStatus,
) => {
  const query: any = { userId };

  if (status) {
    query.status = status;
  }

  return await Delivery.find(query)
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);
};

/**
 * Get driver deliveries
 */
export const getDriverDeliveries = async (
  driverId: Types.ObjectId,
  page = 0,
  limit = 10,
  status?: DeliveryStatus,
) => {
  const query: any = { driverId };

  if (status) {
    query.status = status;
  }

  return await Delivery.find(query)
    .populate("userId", "fullName mobileNumber")
    .populate("vehicleTypeId")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);
};

/**
 * Get active delivery for user
 */
export const getActiveUserDelivery = async (userId: Types.ObjectId) => {
  return await Delivery.findOne({
    userId,
    status: { $in: ["SEARCHING", "ASSIGNED", "PICKED_UP", "IN_TRANSIT"] },
  })
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId")
    .select("-__v")
    .sort({ createdAt: -1 });
};

/**
 * Update delivery status
 */
export const updateDeliveryStatus = async (
  deliveryId: string | Types.ObjectId,
  status: DeliveryStatus,
  additionalData?: any,
) => {
  const updateData: any = { status, ...additionalData };

  switch (status) {
    case "PICKED_UP":
      updateData.pickedUpAt = new Date();
      break;
    case "DELIVERED":
      updateData.deliveredAt = new Date();
      break;
    case "CANCELLED":
      updateData.cancelledAt = new Date();
      break;
  }

  const updated = await Delivery.findByIdAndUpdate(deliveryId, updateData, { new: true })
    .populate("userId", "fullName mobileNumber")
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId");

  // Calculate and record commission on delivery completion
  if (status === "DELIVERED" && updated && updated.driverId) {
    try {
      await CommissionService.processDeliveryCommission({
        _id: updated._id,
        driverId: updated.driverId,
        finalFare: updated.finalFare,
        deliveredAt: updated.deliveredAt,
      });
    } catch (err) {
      console.error("Commission calculation failed for delivery:", updated._id, err);
    }
  }

  return updated;
};

/**
 * Update delivery stop status
 */
export const updateDeliveryStop = async (
  deliveryId: string | Types.ObjectId,
  stopIndex: number,
  status: "COMPLETED" | "SKIPPED",
  proofImage?: string,
) => {
  const updateData: any = {
    [`drops.${stopIndex}.status`]: status,
    [`drops.${stopIndex}.completedAt`]: new Date(),
  };

  if (proofImage) {
    updateData[`drops.${stopIndex}.proofImage`] = proofImage;
  }

  return await Delivery.findByIdAndUpdate(deliveryId, updateData, {
    new: true,
  });
};

/**
 * Assign driver to delivery
 */
export const assignDriverToDelivery = async (
  deliveryId: string | Types.ObjectId,
  driverId: Types.ObjectId,
) => {
  return await updateDeliveryStatus(deliveryId, "ASSIGNED", { driverId });
};

/**
 * Cancel delivery
 */
export const cancelDelivery = async (
  deliveryId: string | Types.ObjectId,
  cancelledBy: "USER" | "DRIVER" | "SYSTEM",
  cancellationReason?: string,
) => {
  return await updateDeliveryStatus(deliveryId, "CANCELLED", {
    cancelledBy,
    cancellationReason,
  });
};

/**
 * Count deliveries
 */
export const countDeliveries = async (query: any) => {
  return await Delivery.countDocuments(query);
};

/**
 * Calculate multi-stop delivery fare
 */
export const calculateMultiStopFare = async (
  vehicleType: any,
  distanceKm: number,
  durationMin: number,
  numberOfStops: number,
) => {
  // Base calculation
  const baseFare = vehicleType.baseFare || 0;
  const distanceFare = distanceKm * (vehicleType.perKmRate || 0);
  const timeFare = durationMin * (vehicleType.perMinuteRate || 0);

  // Additional charges per extra stop (after first drop)
  const extraStopCharge = (numberOfStops - 1) * 20; // ₹20 per extra stop

  // Surge pricing
  const surgeMultiplier = vehicleType.surgeMultiplier || 1;
  const subtotal = baseFare + distanceFare + timeFare + extraStopCharge;
  const surgeFare = surgeMultiplier > 1 ? subtotal * (surgeMultiplier - 1) : 0;

  const finalFare = Math.round(subtotal + surgeFare);

  return {
    baseFare: Math.round(baseFare),
    distanceFare: Math.round(distanceFare),
    timeFare: Math.round(timeFare),
    extraStopCharge,
    surgeFare: Math.round(surgeFare),
    surgeMultiplier,
    discount: 0,
    finalFare,
  };
};
