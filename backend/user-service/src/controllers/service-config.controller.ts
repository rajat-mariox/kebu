import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";
import {
  SurgeConfig,
  CommissionConfig,
  CancellationPolicy,
  DeliveryPackageType,
  Payout,
} from "../models/pricing-config.model";
import Booking from "../models/booking.model";
import Delivery from "../models/delivery.model";
import ServiceBooking from "../models/service-booking.model";
import ServiceProvider from "../models/service-provider.model";
import Driver from "../models/driver.model";

// ========== SURGE CONFIG ==========

export const getSurgeConfigs = async (req: Request, res: Response, next: NextFunction) => {
  const filter: any = {};
  if (req.query.serviceType) filter.serviceType = req.query.serviceType;
  const configs = await SurgeConfig.find(filter).sort({ serviceType: 1, createdAt: -1 });
  req.rData = { configs };
  next();
};

export const createSurgeConfig = async (req: Request, res: Response, next: NextFunction) => {
  const config = await SurgeConfig.create(req.body);
  req.rData = { config };
  next();
};

export const updateSurgeConfig = async (req: Request, res: Response, next: NextFunction) => {
  const config = await SurgeConfig.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!config) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { config };
  next();
};

export const deleteSurgeConfig = async (req: Request, res: Response, next: NextFunction) => {
  await SurgeConfig.findByIdAndDelete(req.params.id);
  req.rData = { message: "Deleted" };
  next();
};

// ========== COMMISSION CONFIG ==========

export const getCommissionConfigs = async (req: Request, res: Response, next: NextFunction) => {
  const filter: any = {};
  if (req.query.serviceType) filter.serviceType = req.query.serviceType;
  const configs = await CommissionConfig.find(filter).sort({ serviceType: 1 });
  req.rData = { configs };
  next();
};

export const createCommissionConfig = async (req: Request, res: Response, next: NextFunction) => {
  const config = await CommissionConfig.create(req.body);
  req.rData = { config };
  next();
};

export const updateCommissionConfig = async (req: Request, res: Response, next: NextFunction) => {
  const config = await CommissionConfig.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!config) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { config };
  next();
};

export const deleteCommissionConfig = async (req: Request, res: Response, next: NextFunction) => {
  await CommissionConfig.findByIdAndDelete(req.params.id);
  req.rData = { message: "Deleted" };
  next();
};

// ========== CANCELLATION POLICY ==========

export const getCancellationPolicies = async (req: Request, res: Response, next: NextFunction) => {
  const filter: any = {};
  if (req.query.serviceType) filter.serviceType = req.query.serviceType;
  const policies = await CancellationPolicy.find(filter).sort({ serviceType: 1 });
  req.rData = { policies };
  next();
};

export const createCancellationPolicy = async (req: Request, res: Response, next: NextFunction) => {
  const policy = await CancellationPolicy.create(req.body);
  req.rData = { policy };
  next();
};

export const updateCancellationPolicy = async (req: Request, res: Response, next: NextFunction) => {
  const policy = await CancellationPolicy.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!policy) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { policy };
  next();
};

export const deleteCancellationPolicy = async (req: Request, res: Response, next: NextFunction) => {
  await CancellationPolicy.findByIdAndDelete(req.params.id);
  req.rData = { message: "Deleted" };
  next();
};

// ========== DELIVERY PACKAGE TYPES ==========

export const getDeliveryPackageTypes = async (req: Request, res: Response, next: NextFunction) => {
  const types = await DeliveryPackageType.find().sort({ displayOrder: 1 });
  req.rData = { packageTypes: types };
  next();
};

export const createDeliveryPackageType = async (req: Request, res: Response, next: NextFunction) => {
  const type = await DeliveryPackageType.create(req.body);
  req.rData = { packageType: type };
  next();
};

export const updateDeliveryPackageType = async (req: Request, res: Response, next: NextFunction) => {
  const type = await DeliveryPackageType.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!type) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { packageType: type };
  next();
};

export const deleteDeliveryPackageType = async (req: Request, res: Response, next: NextFunction) => {
  await DeliveryPackageType.findByIdAndDelete(req.params.id);
  req.rData = { message: "Deleted" };
  next();
};

// ========== DELIVERY ANALYTICS ==========

export const getDeliveryAnalytics = async (req: Request, res: Response, next: NextFunction) => {
  const { startDate, endDate, range } = req.query;
  let start: Date;
  let end: Date = new Date();

  if (startDate && endDate) {
    start = new Date(startDate as string);
    end = new Date(endDate as string);
    end.setHours(23, 59, 59, 999);
  } else {
    switch (range) {
      case "7d": start = new Date(Date.now() - 7 * 86400000); break;
      case "30d": start = new Date(Date.now() - 30 * 86400000); break;
      default: start = new Date(); start.setHours(0, 0, 0, 0);
    }
  }

  const dateFilter = { $gte: start, $lte: end };

  const [stats, byType, byStatus, trend] = await Promise.all([
    Delivery.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          completed: { $sum: { $cond: [{ $eq: ["$status", "DELIVERED"] }, 1, 0] } },
          cancelled: { $sum: { $cond: [{ $eq: ["$status", "CANCELLED"] }, 1, 0] } },
          totalRevenue: { $sum: { $cond: [{ $eq: ["$status", "DELIVERED"] }, "$finalFare", 0] } },
          avgFare: { $avg: { $cond: [{ $eq: ["$status", "DELIVERED"] }, "$finalFare", null] } },
        },
      },
    ]),
    Delivery.aggregate([
      { $match: { createdAt: dateFilter } },
      { $group: { _id: "$deliveryType", count: { $sum: 1 }, revenue: { $sum: "$finalFare" } } },
      { $sort: { count: -1 } },
    ]),
    Delivery.aggregate([
      { $match: { createdAt: dateFilter } },
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]),
    Delivery.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $group: {
          _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
          orders: { $sum: 1 },
          revenue: { $sum: { $cond: [{ $eq: ["$status", "DELIVERED"] }, "$finalFare", 0] } },
        },
      },
      { $sort: { _id: 1 } },
    ]),
  ]);

  req.rData = {
    stats: stats[0] || { totalOrders: 0, completed: 0, cancelled: 0, totalRevenue: 0, avgFare: 0 },
    byType,
    byStatus,
    trend: trend.map((t: any) => ({ date: t._id, orders: t.orders, revenue: t.revenue })),
  };
  next();
};

// ========== HOUSEHOLD ANALYTICS ==========

export const getHouseholdAnalytics = async (req: Request, res: Response, next: NextFunction) => {
  const { startDate, endDate, range } = req.query;
  let start: Date;
  let end: Date = new Date();

  if (startDate && endDate) {
    start = new Date(startDate as string);
    end = new Date(endDate as string);
    end.setHours(23, 59, 59, 999);
  } else {
    switch (range) {
      case "7d": start = new Date(Date.now() - 7 * 86400000); break;
      case "30d": start = new Date(Date.now() - 30 * 86400000); break;
      default: start = new Date(); start.setHours(0, 0, 0, 0);
    }
  }

  const dateFilter = { $gte: start, $lte: end };

  const [stats, byCategory, byStatus, trend, topProviders] = await Promise.all([
    ServiceBooking.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $group: {
          _id: null,
          totalBookings: { $sum: 1 },
          completed: { $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, 1, 0] } },
          cancelled: { $sum: { $cond: [{ $eq: ["$status", "CANCELLED"] }, 1, 0] } },
          totalRevenue: { $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, "$finalCost", 0] } },
          avgCost: { $avg: { $cond: [{ $eq: ["$status", "COMPLETED"] }, "$finalCost", null] } },
        },
      },
    ]),
    ServiceBooking.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $lookup: {
          from: "servicecategories",
          localField: "categoryId",
          foreignField: "_id",
          as: "category",
        },
      },
      { $unwind: { path: "$category", preserveNullAndEmptyArrays: true } },
      {
        $group: {
          _id: "$category.name",
          count: { $sum: 1 },
          revenue: { $sum: "$finalCost" },
        },
      },
      { $sort: { revenue: -1 } },
    ]),
    ServiceBooking.aggregate([
      { $match: { createdAt: dateFilter } },
      { $group: { _id: "$status", count: { $sum: 1 } } },
    ]),
    ServiceBooking.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $group: {
          _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
          bookings: { $sum: 1 },
          revenue: { $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, "$finalCost", 0] } },
        },
      },
      { $sort: { _id: 1 } },
    ]),
    ServiceBooking.aggregate([
      { $match: { createdAt: dateFilter, providerId: { $ne: null } } },
      {
        $group: {
          _id: "$providerId",
          bookings: { $sum: 1 },
          revenue: { $sum: "$finalCost" },
          avgRating: { $avg: "$providerRating" },
        },
      },
      { $sort: { revenue: -1 } },
      { $limit: 10 },
      {
        $lookup: {
          from: "serviceproviders",
          localField: "_id",
          foreignField: "_id",
          as: "provider",
        },
      },
      { $unwind: { path: "$provider", preserveNullAndEmptyArrays: true } },
      {
        $project: {
          name: "$provider.fullName",
          bookings: 1,
          revenue: 1,
          avgRating: 1,
        },
      },
    ]),
  ]);

  req.rData = {
    stats: stats[0] || { totalBookings: 0, completed: 0, cancelled: 0, totalRevenue: 0, avgCost: 0 },
    byCategory,
    byStatus,
    trend: trend.map((t: any) => ({ date: t._id, bookings: t.bookings, revenue: t.revenue })),
    topProviders,
  };
  next();
};

// ========== SERVICE PROVIDER ACTIONS ==========

export const rejectServiceProvider = async (req: Request, res: Response, next: NextFunction) => {
  const { reason } = req.body;
  const provider = await ServiceProvider.findByIdAndUpdate(
    req.params.providerId,
    { status: "rejected", rejectionReason: reason },
    { new: true },
  );
  if (!provider) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { provider };
  next();
};

export const suspendServiceProvider = async (req: Request, res: Response, next: NextFunction) => {
  const { reason } = req.body;
  const provider = await ServiceProvider.findByIdAndUpdate(
    req.params.providerId,
    { status: "suspended", suspensionReason: reason, isActive: false },
    { new: true },
  );
  if (!provider) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { provider };
  next();
};

export const activateServiceProvider = async (req: Request, res: Response, next: NextFunction) => {
  const provider = await ServiceProvider.findByIdAndUpdate(
    req.params.providerId,
    { status: "approved", isActive: true },
    { new: true },
  );
  if (!provider) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { provider };
  next();
};

// ========== SERVICE PACKAGES ==========

export const getServicePackages = async (req: Request, res: Response, next: NextFunction) => {
  const ServicePackage = (await import("../models/service-package.model")).default;
  const filter: any = {};
  const categoryId = req.query.categoryId as string | undefined;
  const serviceId = req.query.serviceId as string | undefined;
  if (categoryId && Types.ObjectId.isValid(categoryId)) {
    filter.categoryId = new Types.ObjectId(categoryId);
  }
  if (serviceId && Types.ObjectId.isValid(serviceId)) {
    filter.serviceId = new Types.ObjectId(serviceId);
  } else if (serviceId === "null" || serviceId === "none") {
    // Explicit request for category-level (no serviceId) fallbacks.
    filter.$or = [{ serviceId: { $exists: false } }, { serviceId: null }];
  }
  const packages = await ServicePackage.find(filter)
    .populate("categoryId", "name")
    .populate("serviceId", "serviceType slug")
    .sort({ displayOrder: 1 });
  req.rData = { packages };
  next();
};

export const createServicePackage = async (req: Request, res: Response, next: NextFunction) => {
  const ServicePackage = (await import("../models/service-package.model")).default;
  const pkg = await ServicePackage.create(req.body);
  req.rData = { package: pkg };
  next();
};

export const updateServicePackage = async (req: Request, res: Response, next: NextFunction) => {
  const ServicePackage = (await import("../models/service-package.model")).default;
  const pkg = await ServicePackage.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!pkg) { req.rCode = 5; req.msg = "not_found"; return next(); }
  req.rData = { package: pkg };
  next();
};

export const deleteServicePackage = async (req: Request, res: Response, next: NextFunction) => {
  const ServicePackage = (await import("../models/service-package.model")).default;
  await ServicePackage.findByIdAndDelete(req.params.id);
  req.rData = { message: "Deleted" };
  next();
};

// ========== PAYOUTS ==========

export const getPayouts = async (req: Request, res: Response, next: NextFunction) => {
  const { page = 1, limit = 20, serviceType, status, recipientType } = req.query;
  const filter: any = {};
  if (serviceType) filter.serviceType = serviceType;
  if (status) filter.status = status;
  if (recipientType) filter.recipientType = recipientType;

  const skip = (Number(page) - 1) * Number(limit);
  const [items, total] = await Promise.all([
    Payout.find(filter).sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
    Payout.countDocuments(filter),
  ]);

  req.rData = { items, total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) };
  next();
};

export const getPayoutSummary = async (req: Request, res: Response, next: NextFunction) => {
  const summary = await Payout.aggregate([
    {
      $group: {
        _id: { serviceType: "$serviceType", status: "$status" },
        total: { $sum: "$netPayout" },
        count: { $sum: 1 },
      },
    },
  ]);

  req.rData = { summary };
  next();
};

export const processPayouts = async (req: Request, res: Response, next: NextFunction) => {
  const { payoutIds } = req.body;
  const adminId = (req as any).adminId;

  const result = await Payout.updateMany(
    { _id: { $in: payoutIds }, status: "pending" },
    { status: "processing", processedBy: adminId, processedAt: new Date() },
  );

  req.rData = { updated: result.modifiedCount };
  next();
};

export const completePayouts = async (req: Request, res: Response, next: NextFunction) => {
  const { payoutIds, transactionRef } = req.body;

  const result = await Payout.updateMany(
    { _id: { $in: payoutIds }, status: "processing" },
    { status: "completed", transactionRef },
  );

  req.rData = { updated: result.modifiedCount };
  next();
};

// ========== PER-SERVICE ANALYTICS ==========

export const getCabAnalytics = async (req: Request, res: Response, next: NextFunction) => {
  const { startDate, endDate, range } = req.query;
  let start: Date;
  let end: Date = new Date();

  if (startDate && endDate) {
    start = new Date(startDate as string);
    end = new Date(endDate as string);
    end.setHours(23, 59, 59, 999);
  } else {
    switch (range) {
      case "7d": start = new Date(Date.now() - 7 * 86400000); break;
      case "30d": start = new Date(Date.now() - 30 * 86400000); break;
      default: start = new Date(); start.setHours(0, 0, 0, 0);
    }
  }

  const dateFilter = { $gte: start, $lte: end };

  const [stats, byVehicleType, byPayment, trend, avgMetrics] = await Promise.all([
    Booking.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $group: {
          _id: null,
          totalRides: { $sum: 1 },
          completed: { $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, 1, 0] } },
          cancelled: { $sum: { $cond: [{ $eq: ["$status", "CANCELLED"] }, 1, 0] } },
          totalRevenue: { $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, "$finalFare", 0] } },
          totalSurge: { $sum: "$surgeFare" },
          totalDiscount: { $sum: "$discount" },
          totalTips: { $sum: "$tip" },
          avgFare: { $avg: { $cond: [{ $eq: ["$status", "COMPLETED"] }, "$finalFare", null] } },
          avgDistance: { $avg: "$distanceKm" },
          avgDuration: { $avg: "$durationMin" },
        },
      },
    ]),
    Booking.aggregate([
      { $match: { createdAt: dateFilter, status: "COMPLETED" } },
      {
        $lookup: { from: "vehicletypes", localField: "vehicleTypeId", foreignField: "_id", as: "vt" },
      },
      { $unwind: { path: "$vt", preserveNullAndEmptyArrays: true } },
      {
        $group: {
          _id: "$vt.name",
          rides: { $sum: 1 },
          revenue: { $sum: "$finalFare" },
          avgFare: { $avg: "$finalFare" },
        },
      },
      { $sort: { revenue: -1 } },
    ]),
    Booking.aggregate([
      { $match: { createdAt: dateFilter, status: "COMPLETED" } },
      { $group: { _id: "$paymentMethod", count: { $sum: 1 }, total: { $sum: "$finalFare" } } },
    ]),
    Booking.aggregate([
      { $match: { createdAt: dateFilter } },
      {
        $group: {
          _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
          rides: { $sum: 1 },
          revenue: { $sum: { $cond: [{ $eq: ["$status", "COMPLETED"] }, "$finalFare", 0] } },
          cancellations: { $sum: { $cond: [{ $eq: ["$status", "CANCELLED"] }, 1, 0] } },
        },
      },
      { $sort: { _id: 1 } },
    ]),
    Booking.aggregate([
      { $match: { createdAt: dateFilter, status: "COMPLETED" } },
      {
        $group: {
          _id: null,
          avgRating: { $avg: "$rating" },
          avgWaitTime: {
            $avg: {
              $cond: [
                { $and: [{ $ifNull: ["$assignedAt", false] }, { $ifNull: ["$createdAt", false] }] },
                { $divide: [{ $subtract: ["$assignedAt", "$createdAt"] }, 60000] },
                null,
              ],
            },
          },
        },
      },
    ]),
  ]);

  req.rData = {
    stats: stats[0] || {},
    byVehicleType,
    byPayment,
    trend: trend.map((t: any) => ({ date: t._id, rides: t.rides, revenue: t.revenue, cancellations: t.cancellations })),
    avgRating: avgMetrics[0]?.avgRating || 0,
    avgWaitTime: Math.round(avgMetrics[0]?.avgWaitTime || 0),
  };
  next();
};
