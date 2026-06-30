import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";
import jwt from "jsonwebtoken";

import User from "../models/Users";
import Driver from "../models/driver.model";
import Booking from "../models/booking.model";
import Delivery from "../models/delivery.model";
import DriverVehicle from "../models/driver-vehicle.model";
import ServiceBooking from "../models/service-booking.model";
import ServiceProvider from "../models/service-provider.model";
import Admin from "../models/admin.model";
import VehicleCategory from "../models/vehicle-category.model";
import VehicleType from "../models/vehicle-type.model";
import ServiceCategory from "../models/service-category.model";
import DriverLocation from "../models/driver-location.model";
import AppSettings from "../models/app-settings.model";
import config from "../config";
import helpers from "../utils/helpers";
import { uploadFileToAws, uploadMultipleFilesToAws } from "../utils/s3";
import { sendToDevice } from "../services/notification.service";
import { SupportTicket, FAQ, Notification } from "../models/customer-features.model";
import { SubscriptionPlan, UserSubscription } from "../models/subscription.model";
import Wallet from "../models/wallet.model";
import WalletTransaction from "../models/wallet-transaction.model";
import { createAuditLog } from "../services/audit-log.service";
import DriverKyc from "../models/driver-kyc.model";

// ========== AUTH ==========

export const adminLogin = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => adminLogin");

  const { email, password } = req.body;

  const admin = await Admin.findOne({ email, isActive: true });

  if (!admin) {
    req.rCode = 0;
    req.msg = "invalid_credentials";
    return next();
  }

  const isValidPassword = await helpers().checkPassword(
    password,
    admin.password,
  );

  if (!isValidPassword) {
    req.rCode = 0;
    req.msg = "invalid_credentials";
    return next();
  }

  // Update last login
  admin.lastLogin = new Date();
  await admin.save();

  const token = jwt.sign(
    { adminId: admin._id, role: admin.role },
    config.auth.jwtSecret,
    { expiresIn: "7d" },
  );

  // Audit log for login
  (req as any).admin = admin;
  await createAuditLog(req, {
    actionType: "LOGIN",
    entity: "Admin",
    entityId: admin._id?.toString(),
    description: `Admin ${admin.name} logged in`,
  });

  req.rData = {
    token,
    admin: {
      _id: admin._id,
      name: admin.name,
      email: admin.email,
      role: admin.role,
      permissions: admin.permissions,
      lastLogin: admin.lastLogin,
    },
  };

  req.msg = "login_success";
  next();
};

// ========== DASHBOARD ==========

export const getDashboardStats = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getDashboardStats");

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const thisMonth = new Date();
  thisMonth.setDate(1);
  thisMonth.setHours(0, 0, 0, 0);

  // User stats
  const totalUsers = await User.countDocuments({ isDeleted: false });
  const newUsersToday = await User.countDocuments({
    createdAt: { $gte: today },
    isDeleted: false,
  });

  // Driver stats
  const totalDrivers = await Driver.countDocuments({ isDeleted: false });
  const activeDrivers = await Driver.countDocuments({
    isOnline: true,
    status: "approved",
    isDeleted: false,
  });
  const pendingApprovals = await Driver.countDocuments({
    status: "under_verification",
  });

  // Booking stats
  const totalBookings = await Booking.countDocuments();
  const todayBookings = await Booking.countDocuments({
    createdAt: { $gte: today },
  });
  const completedToday = await Booking.countDocuments({
    status: "COMPLETED",
    completedAt: { $gte: today },
  });

  // Revenue stats
  const todayRevenue = await Booking.aggregate([
    { $match: { status: "COMPLETED", completedAt: { $gte: today } } },
    { $group: { _id: null, total: { $sum: "$finalFare" } } },
  ]);

  const monthlyRevenue = await Booking.aggregate([
    { $match: { status: "COMPLETED", completedAt: { $gte: thisMonth } } },
    { $group: { _id: null, total: { $sum: "$finalFare" } } },
  ]);

  // Delivery stats
  const totalDeliveries = await Delivery.countDocuments();
  const todayDeliveries = await Delivery.countDocuments({
    createdAt: { $gte: today },
  });

  // Service bookings
  const totalServiceBookings = await ServiceBooking.countDocuments();
  const todayServiceBookings = await ServiceBooking.countDocuments({
    createdAt: { $gte: today },
  });

  req.rData = {
    users: {
      total: totalUsers,
      newToday: newUsersToday,
    },
    drivers: {
      total: totalDrivers,
      active: activeDrivers,
      pendingApprovals,
    },
    bookings: {
      total: totalBookings,
      today: todayBookings,
      completedToday,
    },
    deliveries: {
      total: totalDeliveries,
      today: todayDeliveries,
    },
    services: {
      total: totalServiceBookings,
      today: todayServiceBookings,
    },
    revenue: {
      today: todayRevenue[0]?.total || 0,
      monthly: monthlyRevenue[0]?.total || 0,
    },
  };

  req.msg = "success";
  next();
};

// ========== USERS ==========

export const getUsers = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getUsers");

  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;
  const search = req.query.search as string;
  const status = req.query.status as string;
  const sortBy = (req.query.sortBy as string) || "createdAt";
  const sortOrder = req.query.sortOrder === "desc" ? -1 : 1;

  const query: any = { isDeleted: false };

  if (search) {
    query.$or = [
      { fullName: { $regex: search, $options: "i" } },
      { mobileNumber: { $regex: search, $options: "i" } },
      { email: { $regex: search, $options: "i" } },
    ];
  }

  if (status === "active") query.isActive = true;
  if (status === "inactive") query.isActive = false;

  const users = await User.find(query)
    .select("-__v")
    .sort({ [sortBy]: sortOrder })
    .skip(page * limit)
    .limit(limit);

  const total = await User.countDocuments(query);

  req.rData = {
    users,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };

  req.msg = "success";
  next();
};

export const getUserDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getUserDetails");

  const { userId } = req.params;

  const user = await User.findById(userId).select("-__v");

  if (!user) {
    req.rCode = 5;
    req.msg = "user_not_found";
    return next();
  }

  // Get user's bookings count
  const bookingsCount = await Booking.countDocuments({ userId });
  const deliveriesCount = await Delivery.countDocuments({ userId });
  const servicesCount = await ServiceBooking.countDocuments({ userId });

  req.rData = {
    user,
    stats: {
      bookings: bookingsCount,
      deliveries: deliveriesCount,
      services: servicesCount,
    },
  };

  req.msg = "success";
  next();
};

export const updateUserStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateUserStatus");

  const { userId } = req.params;
  const { isActive } = req.body;

  const user = await User.findByIdAndUpdate(
    userId,
    { isActive },
    { new: true },
  ).select("-__v");

  if (!user) {
    req.rCode = 5;
    req.msg = "user_not_found";
    return next();
  }

  req.rData = { user };
  req.msg = isActive ? "user_activated" : "user_deactivated";
  next();
};

// ========== DRIVERS ==========

export const getDrivers = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getDrivers");

  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;
  const search = req.query.search as string;
  const status = req.query.status as string;
  const sortBy = (req.query.sortBy as string) || "createdAt";
  const sortOrder = req.query.sortOrder === "desc" ? -1 : 1;

  const query: any = { isDeleted: false };

  if (search) {
    query.$or = [
      { fullName: { $regex: search, $options: "i" } },
      { mobileNumber: { $regex: search, $options: "i" } },
      { email: { $regex: search, $options: "i" } },
    ];
  }

  if (status) query.status = status;

  const drivers = await Driver.find(query)
    .select("-__v")
    .sort({ [sortBy]: sortOrder })
    .skip(page * limit)
    .limit(limit);

  const total = await Driver.countDocuments(query);

  req.rData = {
    drivers,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };

  req.msg = "success";
  next();
};

export const getDriverDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getDriverDetails");

  const { driverId } = req.params;

  const driver = await Driver.findById(driverId).select("-__v");

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // Get KYC documents
  const DriverKyc = require("../models/driver-kyc.model").default;
  const kyc = await DriverKyc.findOne({ driverId });

  // Get vehicle info
  const DriverVehicle = require("../models/driver-vehicle.model").default;
  const vehicle = await DriverVehicle.findOne({ driverId });

  // Get stats
  const bookingsCount = await Booking.countDocuments({ driverId });
  const completedBookings = await Booking.countDocuments({
    driverId,
    status: "COMPLETED",
  });

  const earnings = await Booking.aggregate([
    {
      $match: {
        driverId: new Types.ObjectId(driverId),
        status: "COMPLETED",
      },
    },
    { $group: { _id: null, total: { $sum: "$finalFare" } } },
  ]);

  req.rData = {
    driver,
    kyc,
    vehicle,
    stats: {
      totalBookings: bookingsCount,
      completedBookings,
      totalEarnings: earnings[0]?.total || 0,
    },
  };

  req.msg = "success";
  next();
};

export const createDriver = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createDriver");

  const {
    mobileNumber,
    countryCode,
    fullName,
    email,
    serviceType,
    city,
    state,
    address,
  } = req.body || {};

  if (!mobileNumber || !/^[6-9]\d{9}$/.test(String(mobileNumber))) {
    req.rCode = 0;
    req.msg = "invalid_mobile_number";
    return next();
  }

  const existing = await Driver.findOne({
    mobileNumber,
    countryCode: countryCode || "+91",
    isDeleted: { $ne: true },
  });
  if (existing) {
    req.rCode = 0;
    req.msg = "driver_already_exists";
    return next();
  }

  const driver = await Driver.create({
    mobileNumber,
    countryCode: countryCode || "+91",
    fullName: fullName || "",
    email: email || "",
    serviceType: serviceType || "",
    city: city || "",
    state: state || "",
    address: address || "",
    status: "draft",
    onboardingStep: 0,
  });

  req.rData = { driver };
  req.msg = "driver_created";
  next();
};

export const approveDriver = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => approveDriver");

  const { driverId } = req.params;

  const driver = await Driver.findByIdAndUpdate(
    driverId,
    { status: "approved" },
    { new: true },
  );

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // Send notification to driver
  if (driver.fcmToken) {
    await sendToDevice(driver.fcmToken, {
      title: "Congratulations! 🎉",
      body: "Your account has been approved. You can now start accepting rides!",
      data: { type: "driver_approved", driverId: driver._id.toString() },
    });
  }

  req.rData = { driver };
  req.msg = "driver_approved";
  next();
};

export const rejectDriver = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => rejectDriver");

  const { driverId } = req.params;
  const { reason } = req.body;

  const driver = await Driver.findByIdAndUpdate(
    driverId,
    { status: "rejected", rejectionReason: reason },
    { new: true },
  );

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  // Send notification to driver
  if (driver.fcmToken) {
    await sendToDevice(driver.fcmToken, {
      title: "Account Rejected ❌",
      body: reason || "Your account verification was rejected. Please contact support for more information.",
      data: { type: "driver_rejected", driverId: driver._id.toString() },
    });
  }

  req.rData = { driver };
  req.msg = "driver_rejected";
  next();
};

export const suspendDriver = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => suspendDriver");

  const { driverId } = req.params;
  const { reason } = req.body;

  const driver = await Driver.findByIdAndUpdate(
    driverId,
    { status: "suspended", suspensionReason: reason, isOnline: false },
    { new: true },
  );

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  req.rData = { driver };
  req.msg = "driver_suspended";
  next();
};

// ========== BOOKINGS ==========

export const getBookings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getBookings");

  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;
  const status = req.query.status as string;
  const startDate = req.query.startDate as string;
  const endDate = req.query.endDate as string;

  const query: any = {};

  if (status) query.status = status;

  if (startDate || endDate) {
    query.createdAt = {};
    if (startDate) query.createdAt.$gte = new Date(startDate);
    if (endDate) query.createdAt.$lte = new Date(endDate);
  }

  const bookings = await Booking.find(query)
    .populate("userId", "fullName mobileNumber")
    .populate("driverId", "fullName mobileNumber")
    .populate("vehicleTypeId", "name")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);

  const total = await Booking.countDocuments(query);

  req.rData = {
    bookings,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };

  req.msg = "success";
  next();
};

export const getBookingDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getBookingDetails");

  const { bookingId } = req.params;

  const booking = await Booking.findById(bookingId)
    .populate("userId", "fullName mobileNumber email")
    .populate("driverId", "fullName mobileNumber rating")
    .populate("vehicleTypeId")
    .select("-__v");

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  req.rData = { booking };
  req.msg = "success";
  next();
};

// ========== VEHICLE MANAGEMENT ==========

export const getVehicleCategories = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getVehicleCategories");

  const categories = await VehicleCategory.find()
    .select("-__v")
    .sort({ name: 1 });

  req.rData = { categories };
  req.msg = "success";
  next();
};

export const createVehicleCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createVehicleCategory");

  const { name, code, icon, isActive } = req.body;

  const category = await VehicleCategory.create({
    name,
    code,
    icon,
    isActive: isActive !== false,
  });

  req.rData = { category };
  req.msg = "category_created";
  next();
};

export const getVehicleTypes = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getVehicleTypes");

  const { categoryId } = req.query;

  const query: any = {};
  if (categoryId) query.categoryId = categoryId;

  const vehicleTypes = await VehicleType.find(query)
    .populate("categoryId", "name code")
    .select("-__v")
    .sort({ name: 1 });

  req.rData = { vehicleTypes };
  req.msg = "success";
  next();
};

export const createVehicleType = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createVehicleType");

  const {
    categoryId,
    name,
    maxWeightKg,
    maxSeats,
    description,
    minimumFare,
    baseFare,
    perKmRate,
    perMinuteRate,
    minDistanceKm,
    surgeMultiplier,
    cancellationFee,
    image,
  } = req.body;

  const vehicleType = await VehicleType.create({
    categoryId,
    name,
    maxWeightKg: maxWeightKg || 0,
    maxSeats: maxSeats || 4,
    description,
    minimumFare: minimumFare || 0,
    baseFare,
    perKmRate,
    perMinuteRate,
    minDistanceKm: minDistanceKm || 1,
    surgeMultiplier: surgeMultiplier || 1,
    cancellationFee: cancellationFee || 0,
    image,
    isActive: true,
  });

  req.rData = { vehicleType };
  req.msg = "vehicle_type_created";
  next();
};

export const updateVehicleType = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateVehicleType");

  const { typeId } = req.params;
  const updateData = req.body;

  const vehicleType = await VehicleType.findByIdAndUpdate(typeId, updateData, {
    new: true,
  }).populate("categoryId");

  if (!vehicleType) {
    req.rCode = 5;
    req.msg = "vehicle_type_not_found";
    return next();
  }

  req.rData = { vehicleType };
  req.msg = "vehicle_type_updated";
  next();
};

// ========== SERVICE CATEGORIES ==========

export const getServiceCategories = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getServiceCategories");

  const categories = await ServiceCategory.find()
    .select("-__v")
    .sort({ displayOrder: 1, name: 1 });

  req.rData = { categories };
  req.msg = "success";
  next();
};

export const createServiceCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createServiceCategory");

  const { name, slug, description, icon, image, parentId, displayOrder } =
    req.body;

  const category = await ServiceCategory.create({
    name,
    slug: slug || name.toLowerCase().replace(/\s+/g, "-"),
    description,
    icon,
    image,
    parentId,
    displayOrder: displayOrder || 0,
    isActive: true,
  });

  req.rData = { category };
  req.msg = "category_created";
  next();
};

// ========== SERVICE PROVIDERS ==========

export const getServiceProviders = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getServiceProviders");

  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;
  const status = req.query.status as string;
  const categoryId = req.query.categoryId as string;

  const query: any = { isDeleted: false };

  if (status) query.status = status;
  if (categoryId) query.serviceCategories = categoryId;

  const providers = await ServiceProvider.find(query)
    .populate("serviceCategories", "name")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);

  const total = await ServiceProvider.countDocuments(query);

  req.rData = {
    providers,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };

  req.msg = "success";
  next();
};

export const approveServiceProvider = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => approveServiceProvider");

  const { providerId } = req.params;

  const provider = await ServiceProvider.findByIdAndUpdate(
    providerId,
    { status: "approved" },
    { new: true },
  );

  if (!provider) {
    req.rCode = 5;
    req.msg = "provider_not_found";
    return next();
  }

  req.rData = { provider };
  req.msg = "provider_approved";
  next();
};

/**
 * Set the household service categories a cleaning-type Driver is approved for.
 * Body: { categoryIds: string[] }
 */
export const setDriverHouseholdCategories = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => setDriverHouseholdCategories");

  const { driverId } = req.params;
  const { categoryIds } = req.body || {};

  if (!Array.isArray(categoryIds) || !categoryIds.every((id) => Types.ObjectId.isValid(id))) {
    req.rCode = 5;
    req.msg = "invalid_category_ids";
    return next();
  }

  const driver = await Driver.findById(driverId);
  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  if (driver.serviceType !== "cleaning") {
    req.rCode = 0;
    req.msg = "driver_not_household_vendor";
    return next();
  }

  driver.householdCategories = categoryIds.map((id) => new Types.ObjectId(id));
  await driver.save();

  req.rData = { driver };
  req.msg = "categories_updated";
  next();
};

// ========== ANALYTICS ==========

export const getRevenueAnalytics = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getRevenueAnalytics");

  const { period } = req.query; // day, week, month
  const days = period === "month" ? 30 : period === "week" ? 7 : 1;

  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const revenueByDay = await Booking.aggregate([
    {
      $match: {
        status: "COMPLETED",
        completedAt: { $gte: startDate },
      },
    },
    {
      $group: {
        _id: { $dateToString: { format: "%Y-%m-%d", date: "$completedAt" } },
        revenue: { $sum: "$finalFare" },
        bookings: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  const revenueByVehicleType = await Booking.aggregate([
    {
      $match: {
        status: "COMPLETED",
        completedAt: { $gte: startDate },
      },
    },
    {
      $group: {
        _id: "$vehicleTypeId",
        revenue: { $sum: "$finalFare" },
        bookings: { $sum: 1 },
      },
    },
    {
      $lookup: {
        from: "vehicletypes",
        localField: "_id",
        foreignField: "_id",
        as: "vehicleType",
      },
    },
    { $unwind: "$vehicleType" },
    {
      $project: {
        name: "$vehicleType.name",
        revenue: 1,
        bookings: 1,
      },
    },
  ]);

  req.rData = {
    byDay: revenueByDay,
    byVehicleType: revenueByVehicleType,
  };

  req.msg = "success";
  next();
};

export const getBookingAnalytics = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getBookingAnalytics");

  const { period } = req.query;
  const days = period === "month" ? 30 : period === "week" ? 7 : 1;

  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const bookingsByStatus = await Booking.aggregate([
    { $match: { createdAt: { $gte: startDate } } },
    { $group: { _id: "$status", count: { $sum: 1 } } },
  ]);

  const bookingsByHour = await Booking.aggregate([
    { $match: { createdAt: { $gte: startDate } } },
    {
      $group: {
        _id: { $hour: "$createdAt" },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  const cancellationRate = await Booking.aggregate([
    { $match: { createdAt: { $gte: startDate } } },
    {
      $group: {
        _id: null,
        total: { $sum: 1 },
        cancelled: {
          $sum: { $cond: [{ $eq: ["$status", "CANCELLED"] }, 1, 0] },
        },
      },
    },
  ]);

  req.rData = {
    byStatus: bookingsByStatus,
    byHour: bookingsByHour,
    cancellationRate:
      cancellationRate.length > 0
        ? (cancellationRate[0].cancelled / cancellationRate[0].total) * 100
        : 0,
  };

  req.msg = "success";
  next();
};

// ========== ADMIN MANAGEMENT ==========

export const getAdmins = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getAdmins");

  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;
  const search = req.query.search as string;

  const query: any = {};

  if (search) {
    query.$or = [
      { name: { $regex: search, $options: "i" } },
      { email: { $regex: search, $options: "i" } },
    ];
  }

  const admins = await Admin.find(query)
    .select("-password -__v")
    .populate("roleId", "name permissions")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit);

  const total = await Admin.countDocuments(query);

  req.rData = {
    items: admins,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };

  req.msg = "success";
  next();
};

export const getAdminById = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getAdminById");

  const { adminId } = req.params;

  const admin = await Admin.findById(adminId)
    .select("-password -__v")
    .populate("roleId", "name permissions");

  if (!admin) {
    req.rCode = 5;
    req.msg = "admin_not_found";
    return next();
  }

  req.rData = { admin };
  req.msg = "success";
  next();
};

export const createAdmin = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createAdmin");

  const { name, email, password, mobileNumber, role, roleId, permissions } =
    req.body;

  // Check if email already exists
  const existingAdmin = await Admin.findOne({ email });
  if (existingAdmin) {
    req.rCode = 0;
    req.msg = "email_already_exists";
    return next();
  }

  const hashedPassword = await helpers().hashPassword(password);

  // Validate roleId — if provided, look up the role to get proper role type
  let resolvedRole = role || "admin";
  let resolvedRoleId = undefined;
  if (roleId) {
    // Check if roleId is a valid ObjectId
    if (Types.ObjectId.isValid(roleId)) {
      resolvedRoleId = roleId;
      // Look up role to set the role type
      const Role = (await import("../models/role.model")).default;
      const foundRole = await Role.findById(roleId);
      if (foundRole) {
        resolvedRole = role || "admin";
      }
    }
    // If roleId is not a valid ObjectId (e.g. a role name was sent), skip it
  }

  const admin = await Admin.create({
    name,
    email,
    password: hashedPassword,
    mobileNumber,
    role: resolvedRole,
    roleId: resolvedRoleId,
    permissions: permissions || [],
    isActive: true,
  });

  const adminData = admin.toObject();
  delete (adminData as any).password;

  req.rData = { admin: adminData };
  req.msg = "admin_created";
  next();
};

export const updateAdmin = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateAdmin");

  const { adminId } = req.params;
  const { name, email, mobileNumber, role, roleId, permissions } = req.body;

  // Check if email is taken by another admin
  if (email) {
    const existingAdmin = await Admin.findOne({
      email,
      _id: { $ne: adminId },
    });
    if (existingAdmin) {
      req.rCode = 0;
      req.msg = "email_already_exists";
      return next();
    }
  }

  const updateData: any = {};
  if (name) updateData.name = name;
  if (email) updateData.email = email;
  if (mobileNumber) updateData.mobileNumber = mobileNumber;
  if (role) updateData.role = role;
  if (roleId) updateData.roleId = roleId;
  if (permissions) updateData.permissions = permissions;

  const admin = await Admin.findByIdAndUpdate(adminId, updateData, {
    new: true,
  })
    .select("-password -__v")
    .populate("roleId", "name permissions");

  if (!admin) {
    req.rCode = 5;
    req.msg = "admin_not_found";
    return next();
  }

  req.rData = { admin };
  req.msg = "admin_updated";
  next();
};

export const deleteAdmin = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteAdmin");

  const { adminId } = req.params;

  // Prevent deleting yourself
  if (req.adminId === adminId) {
    req.rCode = 0;
    req.msg = "cannot_delete_self";
    return next();
  }

  const admin = await Admin.findByIdAndDelete(adminId);

  if (!admin) {
    req.rCode = 5;
    req.msg = "admin_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "admin_deleted";
  next();
};

export const toggleAdminStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => toggleAdminStatus");

  const { adminId } = req.params;

  // Prevent deactivating yourself
  if (req.adminId === adminId) {
    req.rCode = 0;
    req.msg = "cannot_deactivate_self";
    return next();
  }

  const admin = await Admin.findById(adminId);

  if (!admin) {
    req.rCode = 5;
    req.msg = "admin_not_found";
    return next();
  }

  admin.isActive = !admin.isActive;
  await admin.save();

  req.rData = { admin: { _id: admin._id, isActive: admin.isActive } };
  req.msg = admin.isActive ? "admin_activated" : "admin_deactivated";
  next();
};

export const resetAdminPassword = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => resetAdminPassword");

  const { adminId } = req.params;
  const { newPassword } = req.body;

  const hashedPassword = await helpers().hashPassword(newPassword);

  const admin = await Admin.findByIdAndUpdate(adminId, {
    password: hashedPassword,
  });

  if (!admin) {
    req.rCode = 5;
    req.msg = "admin_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "password_reset_success";
  next();
};

// ========== ROLE MANAGEMENT ==========

const Role = require("../models/role.model").default;

export const getRoles = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getRoles");

  const roles = await Role.find().select("-__v").sort({ name: 1 });

  req.rData = { roles };
  req.msg = "success";
  next();
};

export const getRoleById = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getRoleById");

  const { roleId } = req.params;

  const role = await Role.findById(roleId).select("-__v");

  if (!role) {
    req.rCode = 5;
    req.msg = "role_not_found";
    return next();
  }

  req.rData = { role };
  req.msg = "success";
  next();
};

export const createRole = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createRole");

  const { name, description, permissions } = req.body;

  // Check if role name exists
  const existingRole = await Role.findOne({
    name: { $regex: new RegExp(`^${name}$`, "i") },
  });
  if (existingRole) {
    req.rCode = 0;
    req.msg = "role_name_exists";
    return next();
  }

  const role = await Role.create({
    name,
    description,
    permissions: permissions || [],
    isActive: true,
  });

  req.rData = { role };
  req.msg = "role_created";
  next();
};

export const updateRole = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateRole");

  const { roleId } = req.params;
  const { name, description, permissions } = req.body;

  const role = await Role.findById(roleId);

  if (!role) {
    req.rCode = 5;
    req.msg = "role_not_found";
    return next();
  }

  // Prevent editing system roles
  if (role.isSystem) {
    req.rCode = 0;
    req.msg = "cannot_edit_system_role";
    return next();
  }

  if (name) role.name = name;
  if (description !== undefined) role.description = description;
  if (permissions) role.permissions = permissions;

  await role.save();

  req.rData = { role };
  req.msg = "role_updated";
  next();
};

export const deleteRole = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteRole");

  const { roleId } = req.params;

  const role = await Role.findById(roleId);

  if (!role) {
    req.rCode = 5;
    req.msg = "role_not_found";
    return next();
  }

  // Prevent deleting system roles
  if (role.isSystem) {
    req.rCode = 0;
    req.msg = "cannot_delete_system_role";
    return next();
  }

  // Check if any admins are using this role
  const adminsUsingRole = await Admin.countDocuments({ roleId });
  if (adminsUsingRole > 0) {
    req.rCode = 0;
    req.msg = "role_in_use";
    return next();
  }

  await Role.findByIdAndDelete(roleId);

  req.rData = {};
  req.msg = "role_deleted";
  next();
};

// ========== CMS MANAGEMENT ==========

const CmsPage = require("../models/cms.model").default;

export const getCmsPages = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getCmsPages");

  const pages = await CmsPage.find()
    .select("-__v")
    .populate("lastUpdatedBy", "name")
    .sort({ title: 1 });

  req.rData = { pages };
  req.msg = "success";
  next();
};

export const getCmsPageBySlug = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getCmsPageBySlug");

  const { slug } = req.params;

  const page = await CmsPage.findOne({ slug })
    .select("-__v")
    .populate("lastUpdatedBy", "name");

  if (!page) {
    req.rCode = 5;
    req.msg = "page_not_found";
    return next();
  }

  req.rData = { page };
  req.msg = "success";
  next();
};

export const createCmsPage = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createCmsPage");

  const { slug, title, content, metaTitle, metaDescription } = req.body;

  // Check if slug exists
  const existingPage = await CmsPage.findOne({ slug });
  if (existingPage) {
    req.rCode = 0;
    req.msg = "slug_already_exists";
    return next();
  }

  const page = await CmsPage.create({
    slug,
    title,
    content,
    metaTitle,
    metaDescription,
    lastUpdatedBy: req.adminId,
    isActive: true,
  });

  req.rData = { page };
  req.msg = "page_created";
  next();
};

export const updateCmsPage = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateCmsPage");

  const { slug } = req.params;
  const { title, content, metaTitle, metaDescription, isActive } = req.body;

  const page = await CmsPage.findOne({ slug });

  if (!page) {
    req.rCode = 5;
    req.msg = "page_not_found";
    return next();
  }

  if (title !== undefined) page.title = title;
  if (content !== undefined) page.content = content;
  if (metaTitle !== undefined) page.metaTitle = metaTitle;
  if (metaDescription !== undefined) page.metaDescription = metaDescription;
  if (isActive !== undefined) page.isActive = isActive;
  page.lastUpdatedBy = req.adminId;

  await page.save();

  req.rData = { page };
  req.msg = "page_updated";
  next();
};

export const deleteCmsPage = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteCmsPage");

  const { slug } = req.params;

  const page = await CmsPage.findOneAndDelete({ slug });

  if (!page) {
    req.rCode = 5;
    req.msg = "page_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "page_deleted";
  next();
};

// ========== SERVICE BOOKINGS ==========

export const getServiceBookings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getServiceBookings");

  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;
  const status = req.query.status as string;
  const categoryId = req.query.categoryId as string;
  const startDate = req.query.startDate as string;
  const endDate = req.query.endDate as string;

  const query: any = {};

  if (status) query.status = status;
  if (categoryId) query.categoryId = categoryId;

  if (startDate || endDate) {
    query.createdAt = {};
    if (startDate) query.createdAt.$gte = new Date(startDate);
    if (endDate) query.createdAt.$lte = new Date(endDate);
  }

  // NOTE: the ServiceBooking schema has `serviceType` (string) — not a
  // `serviceId` ref — and `providerId` actually stores a Driver id. Populating
  // a non-existent `serviceId` path threw a StrictPopulateError, which is why
  // the admin list came back empty.
  const docs = await ServiceBooking.find(query)
    .populate("userId", "fullName mobileNumber email")
    .populate({
      path: "providerId",
      model: "Driver",
      select: "fullName mobileNumber",
    })
    .populate("categoryId", "name")
    .select("-__v")
    .sort({ createdAt: -1 })
    .skip(page * limit)
    .limit(limit)
    .lean();

  // Shape each booking to the field names the admin Bookings table reads.
  const items = (docs as any[]).map((b) => {
    const provider = b.providerId;
    // actualCost (base + extra) is the real charged total once completed.
    const total = b.actualCost ?? b.finalCost ?? b.estimatedCost ?? 0;
    return {
      ...b,
      serviceId: { name: b.serviceType || "" },
      providerId: provider
        ? {
            _id: provider._id,
            name: provider.fullName || "",
            phone: provider.mobileNumber || "",
          }
        : null,
      address: {
        ...(b.address || {}),
        address: b.address?.fullAddress || "",
      },
      scheduledDate: b.preferredDate,
      scheduledTime: b.preferredTimeSlot || "",
      totalAmount: total,
      finalAmount: total,
      extraAmount: b.extraAmount ?? 0,
    };
  });

  const total = await ServiceBooking.countDocuments(query);

  req.rData = {
    items,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };

  req.msg = "success";
  next();
};

export const getServiceBookingDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getServiceBookingDetails");

  const { bookingId } = req.params;

  const booking = await ServiceBooking.findById(bookingId)
    .populate("userId", "fullName mobileNumber email")
    .populate({
      path: "providerId",
      model: "Driver",
      select: "fullName mobileNumber rating",
    })
    .populate("categoryId", "name")
    .select("-__v");

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  req.rData = { booking };
  req.msg = "success";
  next();
};

export const updateServiceBookingStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateServiceBookingStatus");

  const { bookingId } = req.params;
  const { status, notes } = req.body;

  const booking = await ServiceBooking.findById(bookingId);

  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  booking.status = status;
  if (notes && status === "CANCELLED") {
    booking.cancellationReason = notes;
    booking.cancelledBy = "SYSTEM";
  }

  if (status === "COMPLETED") {
    booking.completedAt = new Date();
  } else if (status === "CANCELLED") {
    booking.cancelledAt = new Date();
  }

  await booking.save();

  req.rData = { booking };
  req.msg = "booking_status_updated";
  next();
};

// ========== SERVICE DETAILS MANAGEMENT ==========

const ServiceDetails = require("../models/service-details.model").default;

export const getServices = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getServices");

  const categoryId = req.query.categoryId as string;
  const query: any = {};

  if (categoryId) query.categoryId = categoryId;

  const services = await ServiceDetails.find(query)
    .populate("categoryId", "name")
    .select("-__v")
    .sort({ displayOrder: 1, name: 1 });

  req.rData = { services };
  req.msg = "success";
  next();
};

// "Everyday Cleaning" -> "everyday-cleaning". The (categoryId, slug) pair is
// unique, so the admin can't create two services with the same name in a
// category — the duplicate insert simply fails and surfaces as an error.
const slugifyServiceName = (value: string): string =>
  (value || "")
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

export const createService = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => createService");

  const {
    categoryId,
    name,
    description,
    icon,
    image,
    basePrice,
    duration,
    displayOrder,
  } = req.body;

  // The model stores the label as `serviceType` (with a required `slug`); the
  // admin panel sends it as `name`, so map it across here.
  const service = await ServiceDetails.create({
    categoryId,
    serviceType: name,
    slug: slugifyServiceName(name),
    description,
    icon,
    image,
    basePrice: basePrice || 0,
    duration: duration || 60,
    displayOrder: displayOrder || 0,
    isActive: true,
  });

  req.rData = { service };
  req.msg = "service_created";
  next();
};

export const updateService = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateService");

  const { serviceId } = req.params;
  // Strip admin-only aliases and re-map `name` onto the stored `serviceType`
  // (regenerating the slug) so an edited name actually persists.
  const { name, shortDescription, unit, price, ...rest } = req.body;
  const updateData: any = { ...rest };
  if (name !== undefined) {
    updateData.serviceType = name;
    updateData.slug = slugifyServiceName(name);
  }

  const service = await ServiceDetails.findByIdAndUpdate(
    serviceId,
    updateData,
    {
      new: true,
    },
  ).populate("categoryId", "name");

  if (!service) {
    req.rCode = 5;
    req.msg = "service_not_found";
    return next();
  }

  req.rData = { service };
  req.msg = "service_updated";
  next();
};

export const deleteService = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteService");

  const { serviceId } = req.params;

  const service = await ServiceDetails.findByIdAndDelete(serviceId);

  if (!service) {
    req.rCode = 5;
    req.msg = "service_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "service_deleted";
  next();
};

export const updateServiceCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateServiceCategory");

  const { categoryId } = req.params;
  const updateData = req.body;

  const category = await ServiceCategory.findByIdAndUpdate(
    categoryId,
    updateData,
    { new: true },
  );

  if (!category) {
    req.rCode = 5;
    req.msg = "category_not_found";
    return next();
  }

  req.rData = { category };
  req.msg = "category_updated";
  next();
};

export const deleteServiceCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteServiceCategory");

  const { categoryId } = req.params;

  // Check if category has services
  const servicesCount = await ServiceDetails.countDocuments({ categoryId });
  if (servicesCount > 0) {
    req.rCode = 0;
    req.msg = "category_has_services";
    return next();
  }

  const category = await ServiceCategory.findByIdAndDelete(categoryId);

  if (!category) {
    req.rCode = 5;
    req.msg = "category_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "category_deleted";
  next();
};

// ========== FILE UPLOAD ==========

export const uploadFile = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => uploadFile");

  if (!req.files && !req.file) {
    req.rCode = 0;
    req.msg = "no_file_provided";
    return next();
  }

  const files = req.file ? [req.file] : (req.files as Express.Multer.File[]);

  if (files.length === 1) {
    const result = await uploadFileToAws(files);
    req.rData = { url: result.images };
  } else {
    const result = await uploadMultipleFilesToAws(files);
    req.rData = { urls: result.images };
  }

  req.msg = "file_uploaded";
  next();
};

// ========== VEHICLE CATEGORY UPDATE & DELETE ==========

export const updateVehicleCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateVehicleCategory");

  const { categoryId } = req.params;
  const updateData = req.body;

  const category = await VehicleCategory.findByIdAndUpdate(
    categoryId,
    updateData,
    { new: true },
  );

  if (!category) {
    req.rCode = 5;
    req.msg = "category_not_found";
    return next();
  }

  req.rData = { category };
  req.msg = "category_updated";
  next();
};

export const deleteVehicleCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteVehicleCategory");

  const { categoryId } = req.params;

  const typesCount = await VehicleType.countDocuments({ categoryId });
  if (typesCount > 0) {
    req.rCode = 0;
    req.msg = "category_has_vehicle_types";
    return next();
  }

  const category = await VehicleCategory.findByIdAndDelete(categoryId);

  if (!category) {
    req.rCode = 5;
    req.msg = "category_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "category_deleted";
  next();
};

export const deleteVehicleType = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteVehicleType");

  const { typeId } = req.params;

  const activeBookings = await Booking.countDocuments({
    vehicleTypeId: typeId,
    status: { $in: ["pending", "accepted", "arrived", "in_progress"] },
  });
  if (activeBookings > 0) {
    req.rCode = 0;
    req.msg = "vehicle_type_has_active_bookings";
    return next();
  }

  const driverVehicles = await DriverVehicle.countDocuments({
    vehicleTypeId: typeId,
  });
  if (driverVehicles > 0) {
    req.rCode = 0;
    req.msg = "vehicle_type_in_use";
    return next();
  }

  const vehicleType = await VehicleType.findByIdAndDelete(typeId);

  if (!vehicleType) {
    req.rCode = 5;
    req.msg = "vehicle_type_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "vehicle_type_deleted";
  next();
};

// ========== USER MANAGEMENT EXTENDED ==========

export const getUserStats = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getUserStats");

  const total = await User.countDocuments({ isDeleted: false });
  const active = await User.countDocuments({ isActive: true, isDeleted: false });
  const inactive = await User.countDocuments({ isActive: false, isDeleted: false });

  const thisMonth = new Date();
  thisMonth.setDate(1);
  thisMonth.setHours(0, 0, 0, 0);
  const newThisMonth = await User.countDocuments({
    createdAt: { $gte: thisMonth },
    isDeleted: false,
  });

  req.rData = { total, active, inactive, newThisMonth };
  req.msg = "success";
  next();
};

export const deleteUser = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteUser");

  const { userId } = req.params;

  const user = await User.findByIdAndUpdate(
    userId,
    { isDeleted: true, isActive: false },
    { new: true },
  );

  if (!user) {
    req.rCode = 5;
    req.msg = "user_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "user_deleted";
  next();
};

// ========== DRIVER MANAGEMENT EXTENDED ==========

export const getDriverStats = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getDriverStats");

  const total = await Driver.countDocuments({ isDeleted: false });
  const approved = await Driver.countDocuments({ status: "approved", isDeleted: false });
  const pending = await Driver.countDocuments({ status: { $in: ["under_verification", "documents_uploaded", "vehicle_added"] }, isDeleted: false });
  const online = await Driver.countDocuments({ isOnline: true, status: "approved", isDeleted: false });
  const suspended = await Driver.countDocuments({ status: "suspended", isDeleted: false });
  const rejected = await Driver.countDocuments({ status: "rejected", isDeleted: false });

  req.rData = { total, approved, pending, online, suspended, rejected };
  req.msg = "success";
  next();
};

export const getDriverKyc = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getDriverKyc");

  const { driverId } = req.params;
  const DriverKyc = require("../models/driver-kyc.model").default;
  const kyc = await DriverKyc.findOne({ driverId });

  req.rData = { kyc };
  req.msg = "success";
  next();
};

export const getDriverVehicle = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getDriverVehicle");

  const { driverId } = req.params;
  const DriverVehicle = require("../models/driver-vehicle.model").default;
  const vehicle = await DriverVehicle.findOne({ driverId });

  req.rData = { vehicle };
  req.msg = "success";
  next();
};

export const activateDriver = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => activateDriver");

  const { driverId } = req.params;

  const driver = await Driver.findByIdAndUpdate(
    driverId,
    { status: "approved", isActive: true },
    { new: true },
  );

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  req.rData = { driver };
  req.msg = "driver_activated";
  next();
};

export const deleteDriver = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => deleteDriver");

  const { driverId } = req.params;

  const driver = await Driver.findByIdAndUpdate(
    driverId,
    { isDeleted: true, isActive: false, isOnline: false },
    { new: true },
  );

  if (!driver) {
    req.rCode = 5;
    req.msg = "driver_not_found";
    return next();
  }

  req.rData = {};
  req.msg = "driver_deleted";
  next();
};

// ========== ONLINE DRIVERS MAP ==========

export const getOnlineDrivers = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getOnlineDrivers");

  const locations = await DriverLocation.find()
    .populate("driverId", "fullName mobileNumber status isOnline")
    .sort({ updatedAt: -1 });

  const onlineDrivers = locations.filter(
    (loc: any) => loc.driverId && loc.driverId.isOnline,
  );

  req.rData = { drivers: onlineDrivers };
  req.msg = "success";
  next();
};

// ========== APP SETTINGS ==========

const DEFAULT_SETTINGS = [
  {
    key: "google_maps_api_key",
    label: "Google Maps API Key",
    category: "maps",
    isPublic: true,
    value: "",
  },
  {
    key: "razorpay_key_id",
    label: "Razorpay Key ID",
    category: "payment",
    isPublic: true,
    value: "",
  },
  {
    key: "firebase_project_id",
    label: "Firebase Project ID",
    category: "firebase",
    isPublic: true,
    value: "",
  },
  {
    key: "sms_api_key",
    label: "MSG91 Auth Key",
    category: "sms",
    isPublic: false,
    value: "",
  },
  {
    key: "sms_sender_id",
    label: "MSG91 Sender ID",
    category: "sms",
    isPublic: false,
    value: "",
  },
  {
    key: "sms_otp_template_id",
    label: "MSG91 OTP Template ID",
    category: "sms",
    isPublic: false,
    value: "",
  },
  {
    key: "sms_otp_template",
    label: "OTP Template Text (use ##OTP## as placeholder)",
    category: "sms",
    isPublic: false,
    value: "Your Kebu verification code is ##OTP##. Valid for 10 minutes.",
  },
  {
    key: "sms_audience",
    label: "Send SMS To (all / customers / vendors)",
    category: "sms",
    isPublic: false,
    value: "all",
  },
];

export const getAppSettings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  // Seed any default keys that are missing (idempotent — preserves existing values)
  const existingKeys = new Set(
    (await AppSettings.find({}, { key: 1 })).map((s) => s.key),
  );
  const missing = DEFAULT_SETTINGS.filter((d) => !existingKeys.has(d.key));
  if (missing.length > 0) {
    await AppSettings.insertMany(missing);
  }

  const settings = await AppSettings.find().sort({ category: 1, key: 1 });

  req.rCode = 1;
  req.rData = { settings };
  req.msg = "success";
  next();
};

export const updateAppSettings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { settings } = req.body;

  if (!Array.isArray(settings)) {
    req.rCode = 0;
    req.msg = "settings must be an array";
    return next();
  }

  const adminId = (req as any).adminId;

  for (const item of settings) {
    if (!item.key) continue;
    await AppSettings.findOneAndUpdate(
      { key: item.key },
      {
        value: item.value ?? "",
        ...(item.label && { label: item.label }),
        ...(item.category && { category: item.category }),
        ...(typeof item.isPublic === "boolean" && { isPublic: item.isPublic }),
        updatedBy: adminId,
      },
      { upsert: true, new: true },
    );
  }

  const updated = await AppSettings.find().sort({ category: 1, key: 1 });

  req.rCode = 1;
  req.rData = { settings: updated };
  req.msg = "settings_updated";
  next();
};

export const addAppSetting = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { key, value, label, category, isPublic } = req.body;

  if (!key || !label) {
    req.rCode = 0;
    req.msg = "key and label are required";
    return next();
  }

  const existing = await AppSettings.findOne({ key });
  if (existing) {
    req.rCode = 0;
    req.msg = "setting_key_exists";
    return next();
  }

  const setting = await AppSettings.create({
    key,
    value: value ?? "",
    label,
    category: category ?? "general",
    isPublic: isPublic ?? false,
    updatedBy: (req as any).adminId,
  });

  req.rCode = 1;
  req.rData = { setting };
  req.msg = "setting_created";
  next();
};

export const deleteAppSetting = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { key } = req.params;

  const deleted = await AppSettings.findOneAndDelete({ key });

  if (!deleted) {
    req.rCode = 5;
    req.msg = "setting_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = {};
  req.msg = "setting_deleted";
  next();
};

// ========== SUPPORT TICKETS ==========

export const getSupportTickets = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getSupportTickets");

  const {
    page = 1,
    limit = 20,
    status,
    priority,
    category,
    search,
  } = req.query;

  const query: Record<string, unknown> = {};

  if (status) query.status = status;
  if (priority) query.priority = priority;
  if (category) query.category = category;
  if (search) {
    query.$or = [
      { subject: { $regex: search, $options: "i" } },
      { description: { $regex: search, $options: "i" } },
    ];
  }

  const skip = (Number(page) - 1) * Number(limit);

  const [tickets, total] = await Promise.all([
    SupportTicket.find(query)
      .populate("userId", "fullName mobileNumber email")
      .populate("driverId", "fullName mobileNumber email")
      .populate("assignedTo", "name email")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit)),
    SupportTicket.countDocuments(query),
  ]);

  req.rCode = 1;
  req.rData = {
    tickets,
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / Number(limit)),
    },
  };
  req.msg = "success";
  next();
};

export const getSupportTicketById = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getSupportTicketById");

  const { ticketId } = req.params;

  const ticket = await SupportTicket.findById(ticketId)
    .populate("userId", "fullName mobileNumber email profileImage")
    .populate("driverId", "fullName mobileNumber email")
    .populate("assignedTo", "name email")
    .populate("bookingId");

  if (!ticket) {
    req.rCode = 5;
    req.msg = "ticket_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = { ticket };
  req.msg = "success";
  next();
};

export const replySupportTicket = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => replySupportTicket");

  const { ticketId } = req.params;
  const { message } = req.body;
  const adminId = (req as any).adminId;

  if (!message) {
    req.rCode = 0;
    req.msg = "message_required";
    return next();
  }

  const ticket = await SupportTicket.findById(ticketId);

  if (!ticket) {
    req.rCode = 5;
    req.msg = "ticket_not_found";
    return next();
  }

  ticket.messages.push({
    senderId: new Types.ObjectId(adminId),
    senderType: "ADMIN",
    message,
    createdAt: new Date(),
  });

  if (ticket.status === "OPEN") {
    ticket.status = "IN_PROGRESS";
  }

  if (!ticket.assignedTo) {
    ticket.assignedTo = new Types.ObjectId(adminId);
  }

  await ticket.save();

  // Send push notification to the user/driver
  const targetId = ticket.driverId || ticket.userId;
  if (targetId) {
    const targetModel = ticket.driverId ? Driver : User;
    const target = await targetModel.findById(targetId).select("fcmToken");
    if (target?.fcmToken) {
      await sendToDevice(target.fcmToken, {
        title: "Support Reply",
        body: message.substring(0, 100),
      });
    }
  }

  req.rCode = 1;
  req.rData = { ticket };
  req.msg = "message_sent";
  next();
};

export const updateSupportTicketStatus = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => updateSupportTicketStatus");

  const { ticketId } = req.params;
  const { status } = req.body;
  const adminId = (req as any).adminId;

  const validStatuses = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];
  if (!validStatuses.includes(status)) {
    req.rCode = 0;
    req.msg = "invalid_status";
    return next();
  }

  const update: Record<string, unknown> = { status };

  if (status === "RESOLVED") update.resolvedAt = new Date();
  if (status === "CLOSED") update.closedAt = new Date();
  if (!update.assignedTo) update.assignedTo = new Types.ObjectId(adminId);

  const ticket = await SupportTicket.findByIdAndUpdate(ticketId, update, {
    new: true,
  })
    .populate("userId", "fullName mobileNumber email")
    .populate("driverId", "fullName mobileNumber email")
    .populate("assignedTo", "name email");

  if (!ticket) {
    req.rCode = 5;
    req.msg = "ticket_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = { ticket };
  req.msg = "status_updated";
  next();
};

export const getSupportTicketStats = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("AdminController => getSupportTicketStats");

  const [total, open, inProgress, resolved, closed, highPriority] =
    await Promise.all([
      SupportTicket.countDocuments(),
      SupportTicket.countDocuments({ status: "OPEN" }),
      SupportTicket.countDocuments({ status: "IN_PROGRESS" }),
      SupportTicket.countDocuments({ status: "RESOLVED" }),
      SupportTicket.countDocuments({ status: "CLOSED" }),
      SupportTicket.countDocuments({ priority: "HIGH", status: { $in: ["OPEN", "IN_PROGRESS"] } }),
    ]);

  req.rCode = 1;
  req.rData = { total, open, inProgress, resolved, closed, highPriority };
  req.msg = "success";
  next();
};

// ========== DELIVERIES ==========

export const getDeliveries = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;
  const status = req.query.status as string;
  const sortOrder = req.query.sortOrder === "desc" ? -1 : 1;

  const query: any = {};
  if (status) query.status = status;

  const [deliveries, total] = await Promise.all([
    Delivery.find(query)
      .populate("userId", "fullName mobileNumber")
      .populate("driverId", "fullName mobileNumber")
      .select("-__v")
      .sort({ createdAt: sortOrder })
      .skip(page * limit)
      .limit(limit),
    Delivery.countDocuments(query),
  ]);

  req.rCode = 1;
  req.rData = { deliveries, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  req.msg = "success";
  next();
};

export const getDeliveryDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { deliveryId } = req.params;
  const delivery = await Delivery.findById(deliveryId)
    .populate("userId", "fullName mobileNumber email")
    .populate("driverId", "fullName mobileNumber email");

  if (!delivery) {
    req.rCode = 5;
    req.msg = "delivery_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = { delivery };
  req.msg = "success";
  next();
};

// ========== FAQ MANAGEMENT ==========

export const getFaqs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const category = req.query.category as string;
  const query: any = {};
  if (category) query.category = category;

  const faqs = await FAQ.find(query).sort({ category: 1, order: 1 });

  req.rCode = 1;
  req.rData = { faqs };
  req.msg = "success";
  next();
};

export const createFaq = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { question, answer, category, order, isActive } = req.body;

  if (!question || !answer) {
    req.rCode = 0;
    req.msg = "question_and_answer_required";
    return next();
  }

  const faq = await FAQ.create({ question, answer, category, order: order || 0, isActive: isActive !== false });

  req.rCode = 1;
  req.rData = { faq };
  req.msg = "faq_created";
  next();
};

export const updateFaq = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { faqId } = req.params;
  const faq = await FAQ.findByIdAndUpdate(faqId, req.body, { new: true });

  if (!faq) {
    req.rCode = 5;
    req.msg = "faq_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = { faq };
  req.msg = "faq_updated";
  next();
};

export const deleteFaq = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { faqId } = req.params;
  const faq = await FAQ.findByIdAndDelete(faqId);

  if (!faq) {
    req.rCode = 5;
    req.msg = "faq_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = {};
  req.msg = "faq_deleted";
  next();
};

// ========== SUBSCRIPTION PLANS ==========

export const getSubscriptionPlans = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const plans = await SubscriptionPlan.find({ isDeleted: false }).sort({ price: 1 });

  req.rCode = 1;
  req.rData = { plans };
  req.msg = "success";
  next();
};

export const createSubscriptionPlan = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const plan = await SubscriptionPlan.create(req.body);

  req.rCode = 1;
  req.rData = { plan };
  req.msg = "plan_created";
  next();
};

export const updateSubscriptionPlan = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { planId } = req.params;
  const plan = await SubscriptionPlan.findByIdAndUpdate(planId, req.body, { new: true });

  if (!plan) {
    req.rCode = 5;
    req.msg = "plan_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = { plan };
  req.msg = "plan_updated";
  next();
};

export const deleteSubscriptionPlan = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { planId } = req.params;
  const plan = await SubscriptionPlan.findByIdAndUpdate(planId, { isDeleted: true }, { new: true });

  if (!plan) {
    req.rCode = 5;
    req.msg = "plan_not_found";
    return next();
  }

  req.rCode = 1;
  req.rData = {};
  req.msg = "plan_deleted";
  next();
};

export const getUserSubscriptions = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;
  const status = req.query.status as string;

  const query: any = {};
  if (status) query.status = status;

  const [subscriptions, total] = await Promise.all([
    UserSubscription.find(query)
      .populate("userId", "fullName mobileNumber email")
      .populate("planId", "name duration price")
      .sort({ createdAt: -1 })
      .skip(page * limit)
      .limit(limit),
    UserSubscription.countDocuments(query),
  ]);

  req.rCode = 1;
  req.rData = { subscriptions, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  req.msg = "success";
  next();
};

// ========== NOTIFICATIONS ==========

export const getNotifications = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;
  const type = req.query.type as string;

  const query: any = {};
  if (type) query.type = type;

  const [notifications, total] = await Promise.all([
    Notification.find(query)
      .populate("userId", "fullName mobileNumber")
      .sort({ createdAt: -1 })
      .skip(page * limit)
      .limit(limit),
    Notification.countDocuments(query),
  ]);

  req.rCode = 1;
  req.rData = { notifications, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  req.msg = "success";
  next();
};

export const sendBulkNotification = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { title, message, type, audience, serviceTypes, userIds, driverIds } = req.body;

  if (!title || !message) {
    req.rCode = 0;
    req.msg = "title_and_message_required";
    return next();
  }

  let userTargets: any[] = [];
  let driverTargets: any[] = [];

  const effectiveAudience = audience || "users";

  // ── Target Users ──────────────────────────────────────
  if (effectiveAudience === "users" || effectiveAudience === "all") {
    if (userIds && userIds.length > 0) {
      userTargets = await User.find({ _id: { $in: userIds }, isActive: true }).select("_id fcmToken fullName");
    } else {
      userTargets = await User.find({ isActive: true, fcmToken: { $exists: true, $ne: "" } }).select("_id fcmToken fullName");
    }
  }

  // ── Target Drivers / Vendors ──────────────────────────
  if (effectiveAudience === "vendors" || effectiveAudience === "all") {
    const driverQuery: any = { isActive: true, status: "approved" };
    if (driverIds && driverIds.length > 0) {
      driverQuery._id = { $in: driverIds };
    } else if (serviceTypes && serviceTypes.length > 0) {
      driverQuery.serviceType = { $in: serviceTypes };
    }
    if (!driverIds || driverIds.length === 0) {
      driverQuery.fcmToken = { $exists: true, $ne: "" };
    }
    driverTargets = await Driver.find(driverQuery).select("_id fcmToken fullName");
  }

  // ── Create notification records (user collection) ─────
  const userNotifs = userTargets.map((u: any) => ({
    userId: u._id,
    title,
    message,
    type: type || "SYSTEM",
    isRead: false,
  }));

  // For drivers, we also store records via the same Notification model
  const driverNotifs = driverTargets.map((d: any) => ({
    userId: d._id,
    title,
    message,
    type: type || "SYSTEM",
    isRead: false,
  }));

  const allNotifs = [...userNotifs, ...driverNotifs];
  if (allNotifs.length > 0) {
    await Notification.insertMany(allNotifs);
  }

  // ── Send FCM push ─────────────────────────────────────
  const allTokens = [
    ...userTargets.filter((u: any) => u.fcmToken).map((u: any) => u.fcmToken),
    ...driverTargets.filter((d: any) => d.fcmToken).map((d: any) => d.fcmToken),
  ];
  if (allTokens.length > 0) {
    try {
      const { sendToMultipleDevices } = require("../services/notification.service");
      await sendToMultipleDevices(allTokens, { title, body: message });
    } catch { /* push failure is non-critical */ }
  }

  req.rCode = 1;
  req.rData = {
    sent: allNotifs.length,
    users: userTargets.length,
    vendors: driverTargets.length,
  };
  req.msg = "notifications_sent";
  next();
};

// ========== WALLET & TRANSACTIONS ==========

export const getWalletTransactions = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;
  const type = req.query.type as string;
  const userId = req.query.userId as string;

  const query: any = {};
  if (type) query.type = type;
  if (userId) query.userId = userId;

  const [transactions, total] = await Promise.all([
    WalletTransaction.find(query)
      .populate("userId", "fullName mobileNumber email")
      .sort({ createdAt: -1 })
      .skip(page * limit)
      .limit(limit),
    WalletTransaction.countDocuments(query),
  ]);

  req.rCode = 1;
  req.rData = { transactions, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } };
  req.msg = "success";
  next();
};

export const getWalletStats = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const [totalWallets, totalBalance, totalCredits, totalDebits] = await Promise.all([
    Wallet.countDocuments(),
    Wallet.aggregate([{ $group: { _id: null, total: { $sum: "$balance" } } }]),
    WalletTransaction.aggregate([{ $match: { type: "CREDIT", status: "COMPLETED" } }, { $group: { _id: null, total: { $sum: "$amount" } } }]),
    WalletTransaction.aggregate([{ $match: { type: "DEBIT", status: "COMPLETED" } }, { $group: { _id: null, total: { $sum: "$amount" } } }]),
  ]);

  req.rCode = 1;
  req.rData = {
    totalWallets,
    totalBalance: totalBalance[0]?.total || 0,
    totalCredits: totalCredits[0]?.total || 0,
    totalDebits: totalDebits[0]?.total || 0,
  };
  req.msg = "success";
  next();
};

// ========== PUBLIC SETTINGS (for apps) ==========

export const getPublicSettings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  // Seed defaults if no settings exist
  const count = await AppSettings.countDocuments();
  if (count === 0) {
    await AppSettings.insertMany(DEFAULT_SETTINGS);
  }

  const settings = await AppSettings.find({ isPublic: true }).select(
    "key value category -_id",
  );

  const keyMap: Record<string, string> = {};
  for (const s of settings) {
    keyMap[s.key] = s.value;
  }

  req.rCode = 1;
  req.rData = { keys: keyMap };
  req.msg = "success";
  next();
};

// ========== ENHANCED DASHBOARD KPIs ==========

export const getDashboardKPIs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const now = new Date();
  const todayStart = new Date(now);
  todayStart.setHours(0, 0, 0, 0);

  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);

  const [
    totalLiveOrders,
    activeDrivers,
    failedOrders,
    onTripDrivers,
    idleDrivers,
    activeSOS,
    todayBookings,
    todayRevenue,
    todayCancellations,
  ] = await Promise.all([
    // Live orders (not completed/cancelled)
    Booking.countDocuments({
      status: { $in: ["SEARCHING", "ASSIGNED", "DRIVER_ARRIVED", "PICKED", "IN_PROGRESS"] },
    }),
    // Active drivers online
    Driver.countDocuments({ isOnline: true, status: "approved", isActive: true }),
    // Failed orders (unassigned > threshold)
    Booking.countDocuments({
      status: "SEARCHING",
      createdAt: { $lte: tenMinutesAgo },
    }),
    // Drivers on trip
    Driver.countDocuments({
      isOnline: true,
      currentBookingId: { $ne: null },
      status: "approved",
    }),
    // Idle drivers
    Driver.countDocuments({
      isOnline: true,
      currentBookingId: null,
      status: "approved",
      isActive: true,
    }),
    // Active SOS - check support tickets with high priority
    SupportTicket.countDocuments({
      priority: "high",
      status: { $in: ["open", "in_progress"] },
    }),
    // Today bookings count
    Booking.countDocuments({ createdAt: { $gte: todayStart } }),
    // Today revenue
    Booking.aggregate([
      { $match: { status: "COMPLETED", completedAt: { $gte: todayStart } } },
      { $group: { _id: null, total: { $sum: "$finalFare" } } },
    ]),
    // Today cancellations
    Booking.countDocuments({
      status: "CANCELLED",
      cancelledAt: { $gte: todayStart },
    }),
  ]);

  const utilizationRatio =
    activeDrivers > 0
      ? Math.round((onTripDrivers / activeDrivers) * 100)
      : 0;

  const failureRate =
    todayBookings > 0
      ? Math.round((failedOrders / todayBookings) * 100)
      : 0;

  req.rData = {
    totalLiveOrders,
    activeDrivers,
    failureRate,
    utilizationRatio,
    activeSOS,
    onTripDrivers,
    idleDrivers,
    failedOrders,
    todayBookings,
    todayRevenue: todayRevenue[0]?.total || 0,
    todayCancellations,
  };
  next();
};

// ========== DRIVER PERFORMANCE & RISK ==========

export const getDriverPerformance = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { driverId } = req.params;

  const driver = await Driver.findById(driverId);
  if (!driver) {
    req.rCode = 5;
    req.msg = "not_found";
    return next();
  }

  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const [totalBookings, completedBookings, cancelledBookings, weekEarnings, lastTrip, kycDocs] =
    await Promise.all([
      Booking.countDocuments({ driverId, createdAt: { $gte: thirtyDaysAgo } }),
      Booking.countDocuments({
        driverId,
        status: "COMPLETED",
        createdAt: { $gte: thirtyDaysAgo },
      }),
      Booking.countDocuments({
        driverId,
        status: "CANCELLED",
        cancelledBy: "DRIVER",
        createdAt: { $gte: thirtyDaysAgo },
      }),
      Booking.aggregate([
        {
          $match: {
            driverId: new Types.ObjectId(driverId),
            status: "COMPLETED",
            completedAt: { $gte: sevenDaysAgo },
          },
        },
        { $group: { _id: null, total: { $sum: "$finalFare" } } },
      ]),
      Booking.findOne({ driverId, status: "COMPLETED" }).sort({
        completedAt: -1,
      }),
      DriverKyc.findOne({ driverId }),
    ]);

  const acceptanceRate =
    totalBookings > 0
      ? Math.round(((totalBookings - cancelledBookings) / totalBookings) * 100)
      : 0;

  const cancellationRate =
    totalBookings > 0
      ? Math.round((cancelledBookings / totalBookings) * 100)
      : 0;

  // COD amount from cash bookings not settled
  const codAmount = await Booking.aggregate([
    {
      $match: {
        driverId: new Types.ObjectId(driverId),
        paymentMethod: "CASH",
        status: "COMPLETED",
        paymentStatus: "PAID",
      },
    },
    { $group: { _id: null, total: { $sum: "$finalFare" } } },
  ]);

  // Document expiry check
  const documents: any[] = [];
  if (kycDocs) {
    const doc = kycDocs as any;
    const sevenDaysFromNow = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    if (doc.dlExpiry) {
      documents.push({
        type: "Driving License",
        expiry: doc.dlExpiry,
        status:
          new Date(doc.dlExpiry) < new Date()
            ? "expired"
            : new Date(doc.dlExpiry) < sevenDaysFromNow
              ? "expiring_soon"
              : "valid",
      });
    }
    if (doc.rcExpiry) {
      documents.push({
        type: "RC",
        expiry: doc.rcExpiry,
        status:
          new Date(doc.rcExpiry) < new Date()
            ? "expired"
            : new Date(doc.rcExpiry) < sevenDaysFromNow
              ? "expiring_soon"
              : "valid",
      });
    }
    if (doc.insuranceExpiry) {
      documents.push({
        type: "Insurance",
        expiry: doc.insuranceExpiry,
        status:
          new Date(doc.insuranceExpiry) < new Date()
            ? "expired"
            : new Date(doc.insuranceExpiry) < sevenDaysFromNow
              ? "expiring_soon"
              : "valid",
      });
    }
  }

  const daysSinceLastTrip = lastTrip?.completedAt
    ? Math.floor(
        (Date.now() - new Date(lastTrip.completedAt).getTime()) /
          (1000 * 60 * 60 * 24),
      )
    : null;

  req.rData = {
    acceptanceRate,
    cancellationRate,
    weeklyEarnings: weekEarnings[0]?.total || 0,
    codAmount: codAmount[0]?.total || 0,
    totalRides: driver.totalRides,
    rating: driver.rating,
    daysSinceLastTrip,
    documents,
    appVersion: driver.appVersion || "Unknown",
    deviceModel: driver.deviceModel || "Unknown",
  };
  next();
};

// ========== EVENT TIMELINE ==========

export const getEventTimeline = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const limit = Number(req.query.limit) || 50;
  const page = Number(req.query.page) || 1;
  const skip = (page - 1) * limit;

  // Get recent bookings and their status changes
  const recentEvents = await Booking.find()
    .sort({ updatedAt: -1 })
    .skip(skip)
    .limit(limit)
    .populate("userId", "fullName mobileNumber")
    .populate("driverId", "fullName mobileNumber")
    .select("status paymentStatus finalFare pickup drop createdAt updatedAt cancelledBy cancellationReason");

  const events = recentEvents.map((b: any) => {
    let eventType = "order_update";
    if (b.status === "SEARCHING") eventType = "order_created";
    else if (b.status === "CANCELLED") eventType = "order_cancelled";
    else if (b.status === "COMPLETED") eventType = "order_completed";
    else if (b.paymentStatus === "REFUNDED") eventType = "refund_issued";

    return {
      id: b._id,
      type: eventType,
      status: b.status,
      user: b.userId,
      driver: b.driverId,
      fare: b.finalFare,
      pickup: b.pickup?.address,
      drop: b.drop?.address,
      timestamp: b.updatedAt,
      createdAt: b.createdAt,
    };
  });

  req.rData = { events, page, limit };
  next();
};
