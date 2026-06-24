import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import * as HouseholdService from "../services/household.service";
import * as DriverLocationService from "../services/driver-location.service";
import * as AutomationRuleService from "../services/automation-rule.service";
import * as SubscriptionBenefitsService from "../services/subscription-benefits.service";
import Driver from "../models/driver.model";
import ServiceBooking from "../models/service-booking.model";
import ServiceCategory from "../models/service-category.model";
import User from "../models/Users";
import Offer from "../models/offer.model";

/**
 * Get all service categories
 */
export const getCategories = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getCategories");

  const categories = await HouseholdService.getAllCategories();

  // Organize into parent/child structure
  const parentCategories = categories.filter((c) => !c.parentId);
  const result = parentCategories.map((parent) => ({
    ...parent.toObject(),
    subCategories: categories.filter(
      (c) => c.parentId?.toString() === parent._id?.toString(),
    ),
  }));

  req.rData = { categories: result };
  req.msg = "success";
  next();
};

/**
 * Get providers by category
 */
export const getProvidersByCategory = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getProvidersByCategory");

  const { categoryId } = req.params;
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 20;

  const providers = await HouseholdService.getProvidersByCategory(
    new Types.ObjectId(categoryId),
    page,
    limit,
  );

  req.rData = { providers };
  req.msg = "success";
  next();
};

/**
 * Find nearby providers
 */
export const findNearbyProviders = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => findNearbyProviders");

  const { categoryId, lat, lng, maxDistanceKm } = req.body;

  const providers = await HouseholdService.findNearbyProviders(
    lat,
    lng,
    new Types.ObjectId(categoryId),
    maxDistanceKm || 10,
  );

  req.rData = { providers };
  req.msg = "success";
  next();
};

/**
 * Get count of active experts near a location (public).
 * Powers the home screen's "N experts currently active around you" card.
 */
export const getActiveExpertsCount = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getActiveExpertsCount");

  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const maxDistanceKm = req.query.maxDistanceKm
    ? Number(req.query.maxDistanceKm)
    : 10;
  const rawCategory = req.query.categoryId as string | undefined;
  const categoryId =
    rawCategory && Types.ObjectId.isValid(rawCategory)
      ? new Types.ObjectId(rawCategory)
      : undefined;

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    req.rData = { count: 0 };
    req.msg = "success";
    return next();
  }

  const count = await HouseholdService.countNearbyActiveProviders(
    lat,
    lng,
    maxDistanceKm,
    categoryId,
  );

  req.rData = { count, maxDistanceKm };
  req.msg = "success";
  next();
};

/**
 * Get provider details
 */
export const getProviderDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getProviderDetails");

  const { providerId } = req.params;

  const provider = await HouseholdService.getProviderById(providerId);

  if (!provider) {
    req.rCode = 5;
    req.msg = "provider_not_found";
    return next();
  }

  // Get provider's reviews
  const ServiceBooking = require("../models/service-booking.model").default;
  const reviews = await ServiceBooking.find({
    providerId: new Types.ObjectId(providerId),
    userRating: { $exists: true },
  })
    .populate("userId", "fullName profileImage")
    .select("userRating userFeedback createdAt serviceType")
    .sort({ createdAt: -1 })
    .limit(10);

  req.rData = { provider, reviews };
  req.msg = "success";
  next();
};

/**
 * Create service booking
 */
export const createBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => createBooking");

  const userId = (req as any).userId;
  const {
    categoryId,
    providerId,
    serviceType,
    description,
    preferredDate,
    preferredTimeSlot,
    address,
    estimatedCost,
    paymentMethod,
    userNotes,
    promoCode,
  } = req.body;

  // Check for active booking
  const activeBooking =
    await HouseholdService.getActiveUserServiceBooking(userId);
  if (activeBooking) {
    req.rCode = 0;
    req.msg = "active_booking_exists";
    return next();
  }

  // Apply automation rules + promo code to compute discount / final cost
  const baseCost = Number(estimatedCost) || 0;
  let discount = 0;
  const appliedRules: Array<{ ruleId: string; name: string; amount: number }> = [];
  let appliedPromo: string | undefined;

  if (baseCost > 0) {
    const ruleResult = await AutomationRuleService.applyPromotionRulesToFare({
      userId,
      distanceKm: 0,
      durationMin: 0,
      vehicleTypeId: undefined,
      baseFare: baseCost,
      distanceFare: 0,
      timeFare: 0,
      surgeFare: 0,
      subtotal: baseCost,
    });
    discount += ruleResult.discount;
    appliedRules.push(...ruleResult.appliedRules);
  }

  if (promoCode && typeof promoCode === "string" && baseCost > 0) {
    const offer = await Offer.findOne({
      code: promoCode.toUpperCase(),
      isActive: true,
      isDeleted: false,
      $or: [{ applicableOn: "ALL" }, { applicableOn: "HOUSEHOLD" }],
    });

    if (offer) {
      const now = new Date();
      const validWindow =
        (!offer.startDate || offer.startDate <= now) &&
        (!offer.endDate || offer.endDate >= now);
      const remaining = Math.max(baseCost - discount, 0);
      const meetsMin = !offer.minOrderValue || baseCost >= offer.minOrderValue;

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
          discount += promoAmount;
          appliedPromo = offer.code;
        }
      }
    }
  }

  const finalCost = Math.max(Math.round((baseCost - discount) * 100) / 100, 0);

  const booking = await HouseholdService.createServiceBooking({
    userId,
    categoryId: new Types.ObjectId(categoryId),
    providerId: providerId ? new Types.ObjectId(providerId) : undefined,
    serviceType,
    description,
    preferredDate: new Date(preferredDate),
    preferredTimeSlot,
    address,
    estimatedCost: baseCost,
    finalCost,
    discount: Math.round(discount * 100) / 100,
    promoCode: appliedPromo,
    paymentMethod: paymentMethod || "CASH",
    userNotes,
    status: providerId ? "PROVIDER_ASSIGNED" : "PENDING",
  });

  if (appliedRules.length > 0) {
    await AutomationRuleService.recordRuleTrigger(
      appliedRules.map((r) => r.ruleId),
    );
  }

  const io = req.app.get("io");

  // Notify provider if directly assigned
  if (providerId && io) {
    io.to(`provider_${providerId}`).emit("new_service_booking", { booking });
  }

  // Broadcast to nearby cleaning-service drivers when no provider preselected
  if (!providerId && io && address?.coordinates?.lat && address?.coordinates?.lng) {
    try {
      const nearby = await DriverLocationService.findNearbyDrivers(
        address.coordinates.lat,
        address.coordinates.lng,
        10,
        undefined,
        "cleaning",
        new Types.ObjectId(categoryId),
      );
      nearby.forEach(({ driver }) => {
        io.to(`driver_${driver._id}`).emit("new_service_booking", { booking });
      });
    } catch (err) {
      console.error("Error broadcasting new_service_booking:", err);
    }
  }

  req.rData = { booking };
  req.msg = "booking_created";
  next();
};

/**
 * Driver/provider accepts a household service booking
 */
export const acceptServiceBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => acceptServiceBooking");

  const driverId = (req as any).driverId || (req as any).userId;
  const { bookingId } = req.params;

  if (!driverId) {
    req.rCode = 3;
    req.msg = "unauthorized";
    return next();
  }

  const driver = await Driver.findById(driverId);
  if (!driver || driver.serviceType !== "cleaning") {
    req.rCode = 4;
    req.msg = "not_a_cleaning_provider";
    return next();
  }

  const booking = await ServiceBooking.findById(bookingId);
  if (!booking) {
    req.rCode = 5;
    req.msg = "booking_not_found";
    return next();
  }

  if (booking.status !== "PENDING") {
    req.rCode = 0;
    req.msg = "booking_not_available";
    return next();
  }

  // Vendor must be trained for this service category
  const driverCategories = (driver.householdCategories || []).map((c) =>
    String(c),
  );
  if (
    booking.categoryId &&
    driverCategories.length > 0 &&
    !driverCategories.includes(String(booking.categoryId))
  ) {
    req.rCode = 0;
    req.msg = "category_not_supported";
    return next();
  }

  booking.providerId = new Types.ObjectId(String(driverId));
  booking.status = "PROVIDER_ASSIGNED";
  await booking.save();

  const io = req.app.get("io");
  if (io) {
    io.to(`user_${booking.userId}`).emit("service_booking_accepted", {
      booking,
      provider: {
        _id: driver._id,
        fullName: driver.fullName,
        mobileNumber: driver.mobileNumber,
        profileImage: driver.profileImage,
      },
    });
    io.emit("service_booking_taken", { bookingId: String(booking._id) });
  }

  // Enrich the response so the partner's "Start customer direction" screen can
  // be fully data-driven — the customer's name/phone (for Call/Chat) and the
  // booking's category name.
  const customerUser = await User.findById(booking.userId).select(
    "fullName mobileNumber countryCode profileImage",
  );
  const category = booking.categoryId
    ? await ServiceCategory.findById(booking.categoryId).select("name")
    : null;

  req.rData = {
    booking,
    bookingNumber: `#${String(booking._id).slice(-4)}`,
    categoryName: category?.name || "",
    customer: {
      name: customerUser?.fullName || "",
      phone: customerUser?.mobileNumber || "",
      countryCode: (customerUser as any)?.countryCode || "+91",
      profileImage: customerUser?.profileImage || "",
    },
  };
  req.msg = "booking_accepted";
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
  console.log("HouseholdController => getBookingDetails");

  const { bookingId } = req.params;

  const booking = await HouseholdService.getServiceBookingById(bookingId);

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
 * Get user's service bookings
 */
export const getUserBookings = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getUserBookings");

  const userId = (req as any).userId;
  const page = parseInt(req.query.page as string) || 0;
  const limit = parseInt(req.query.limit as string) || 10;
  const status = req.query.status as string;

  const bookings = await HouseholdService.getUserServiceBookings(
    userId,
    page,
    limit,
    status as any,
  );

  const total = await HouseholdService.countServiceBookings({ userId });

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
  console.log("HouseholdController => getActiveBooking");

  const userId = (req as any).userId;

  const booking = await HouseholdService.getActiveUserServiceBooking(userId);

  req.rData = { booking };
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
  console.log("HouseholdController => cancelBooking");

  const userId = (req as any).userId;
  const { bookingId } = req.params;
  const { reason } = req.body;

  const booking = await HouseholdService.getServiceBookingById(bookingId);

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

  const cancellableStatuses = [
    "PENDING",
    "ACCEPTED",
    "PROVIDER_ASSIGNED",
    "PROVIDER_EN_ROUTE",
  ];
  if (!cancellableStatuses.includes(booking.status)) {
    req.rCode = 0;
    req.msg = "booking_cannot_be_cancelled";
    return next();
  }

  const updatedBooking = await HouseholdService.cancelServiceBooking(
    bookingId,
    "USER",
    reason,
  );

  // Notify provider
  if (booking.providerId) {
    const io = req.app.get("io");
    if (io) {
      io.to(`provider_${booking.providerId}`).emit("booking_cancelled", {
        booking: updatedBooking,
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
 * Rate service
 */
export const rateService = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => rateService");

  const userId = (req as any).userId;
  const { bookingId } = req.params;
  const { rating, feedback } = req.body;

  const booking = await HouseholdService.getServiceBookingById(bookingId);

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

  const updatedBooking = await HouseholdService.rateServiceBooking(
    bookingId,
    "user",
    rating,
    feedback,
  );

  req.rData = { booking: updatedBooking };
  req.msg = "rating_submitted";
  next();
};

// ============ SERVICE PACKAGES (Duration-based pricing) ============

/**
 * Get service packages by category
 * Returns 1 hr, 1.5 hr, 2 hr packages with pricing
 */
export const getServicePackages = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getServicePackages");

  const { categoryId } = req.params;
  const rawServiceId = (req.query.serviceId || req.query.service) as
    | string
    | undefined;

  const ServicePackage = require("../models/service-package.model").default;
  const ServiceDetails = require("../models/service-details.model").default;

  const isValidCategory =
    categoryId && Types.ObjectId.isValid(categoryId) && categoryId !== "default";
  const isValidService =
    !!rawServiceId && Types.ObjectId.isValid(rawServiceId);

  // Per-service pricing when serviceId is provided; otherwise category-wide.
  const packageQuery: any = { isAvailable: true };
  if (isValidCategory) {
    packageQuery.categoryId = new Types.ObjectId(categoryId);
  }
  if (isValidService) {
    packageQuery.serviceId = new Types.ObjectId(rawServiceId!);
  }

  let packages = await ServicePackage.find(packageQuery).sort({
    displayOrder: 1,
  });

  // Per-service pricing falls back to category-wide if none exists yet, so a
  // fresh leaf service isn't empty until the admin explicitly overrides.
  if (packages.length === 0 && isValidService && isValidCategory) {
    packages = await ServicePackage.find({
      isAvailable: true,
      categoryId: new Types.ObjectId(categoryId),
      $or: [{ serviceId: { $exists: false } }, { serviceId: null }],
    }).sort({ displayOrder: 1 });
  }

  // Auto-seed default duration packages when nothing exists at either level,
  // so the prebook screen is never empty after a fresh category is created.
  if (packages.length === 0 && isValidCategory) {
    const catObjectId = new Types.ObjectId(categoryId);
    const seedTarget: any = { categoryId: catObjectId };
    if (isValidService) seedTarget.serviceId = new Types.ObjectId(rawServiceId!);
    const defaults = [
      {
        ...seedTarget,
        name: "1.5 hr",
        durationMinutes: 90,
        originalPrice: 699,
        discountedPrice: 499,
        discountPercentage: 29,
        isPopular: false,
        isAvailable: true,
        displayOrder: 1,
      },
      {
        ...seedTarget,
        name: "2 hr",
        durationMinutes: 120,
        originalPrice: 899,
        discountedPrice: 599,
        discountPercentage: 33,
        isPopular: true,
        isAvailable: true,
        displayOrder: 2,
      },
      {
        ...seedTarget,
        name: "3 hr",
        durationMinutes: 180,
        originalPrice: 1299,
        discountedPrice: 849,
        discountPercentage: 35,
        isPopular: false,
        isAvailable: true,
        displayOrder: 3,
      },
    ];
    await ServicePackage.insertMany(defaults);
    packages = await ServicePackage.find(packageQuery).sort({ displayOrder: 1 });
  }

  // No persisted packages and no category to seed against (e.g. the prebook
  // flow opens the "Choose service details" screen without a categoryId) —
  // return sensible default durations so "Select Duration" is never empty.
  if (packages.length === 0) {
    packages = [
      {
        name: "1 hr",
        durationMinutes: 60,
        originalPrice: 199,
        discountedPrice: 99,
        discountPercentage: 50,
        isPopular: false,
        isAvailable: true,
        displayOrder: 1,
      },
      {
        name: "1.5 hr",
        durationMinutes: 90,
        originalPrice: 255,
        discountedPrice: 149,
        discountPercentage: 41,
        isPopular: true,
        isAvailable: true,
        displayOrder: 2,
      },
      {
        name: "2 hr",
        durationMinutes: 120,
        originalPrice: 399,
        discountedPrice: 200,
        discountPercentage: 50,
        isPopular: false,
        isAvailable: true,
        displayOrder: 3,
      },
    ];
  }

  // Compute lowest hourly price across all services in the category — the
  // mobile screen renders this as the headline "starting from ₹X" card.
  let lowestHourly: {
    perHourPrice: number;
    originalPerHourPrice: number;
    packageId: any;
    serviceId?: any;
    durationMinutes: number;
  } | null = null;
  if (isValidCategory) {
    const categoryPackages = await ServicePackage.find({
      isAvailable: true,
      categoryId: new Types.ObjectId(categoryId),
    });
    for (const pkg of categoryPackages) {
      const duration = pkg.durationMinutes || 0;
      if (duration <= 0) continue;
      const price = pkg.discountedPrice ?? pkg.originalPrice ?? 0;
      const perHour = Math.round((price / duration) * 60);
      if (!lowestHourly || perHour < lowestHourly.perHourPrice) {
        lowestHourly = {
          perHourPrice: perHour,
          originalPerHourPrice: Math.round(
            ((pkg.originalPrice ?? price) / duration) * 60,
          ),
          packageId: pkg._id,
          serviceId: pkg.serviceId,
          durationMinutes: duration,
        };
      }
    }
  }

  // Expose the list of services that have their own pricing so the mobile
  // pre-book screen can route the user to per-service views.
  let services: any[] = [];
  if (isValidCategory) {
    services = await ServiceDetails.find({
      categoryId: new Types.ObjectId(categoryId),
      isActive: true,
    })
      .select("_id serviceType slug icon image")
      .sort({ displayOrder: 1 });
  }

  const now = new Date();
  const offerQuery: any = {
    isActive: true,
    isDeleted: false,
    startDate: { $lte: now },
    endDate: { $gte: now },
    $or: [{ applicableOn: "ALL" }, { applicableOn: "HOUSEHOLD" }],
  };
  if (isValidCategory) {
    offerQuery.$and = [
      {
        $or: [
          { categories: { $size: 0 } },
          { categories: new Types.ObjectId(categoryId) },
          { categories: { $exists: false } },
        ],
      },
    ];
  }

  const offers = await Offer.find(offerQuery).sort({ priority: -1 });

  const pickOfferForPackage = (pkg: any) => {
    const subtotal = pkg.discountedPrice ?? pkg.originalPrice ?? 0;
    const eligible = offers.filter((o: any) => {
      if (o.minOrderValue && subtotal < o.minOrderValue) return false;
      return true;
    });
    if (eligible.length === 0) return null;
    const computeDiscount = (o: any) => {
      if (!o.value) return 0;
      if (o.type === "PERCENTAGE") {
        const raw = (subtotal * o.value) / 100;
        return Math.min(raw, o.maxDiscount ?? raw);
      }
      if (o.type === "FLAT") return Math.min(o.value, subtotal);
      return 0;
    };
    eligible.sort((a: any, b: any) => computeDiscount(b) - computeDiscount(a));
    const best = eligible[0];
    const discount = Math.round(computeDiscount(best));
    const finalPrice = Math.max(subtotal - discount, 0);
    return {
      offerId: best._id,
      code: best.code,
      title: best.title,
      type: best.type,
      value: best.value,
      discount,
      finalPrice,
      savingsPercent:
        subtotal > 0 ? Math.round((discount / subtotal) * 100) : 0,
    };
  };

  const packagesWithAvailability = packages.map((pkg: any) => {
    const obj = typeof pkg.toObject === "function" ? pkg.toObject() : pkg;
    const applied = pickOfferForPackage(obj);
    return {
      ...obj,
      isAvailableForDate: true,
      appliedOffer: applied,
    };
  });

  req.rData = {
    packages: packagesWithAvailability,
    offers,
    lowestHourly,
    services,
  };
  req.msg = "success";
  next();
};

// ============ TIME SLOTS ============

/**
 * Get available time slots for a date
 */
export const getAvailableTimeSlots = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getAvailableTimeSlots");

  const { categoryId } = req.params;
  const { date } = req.query;

  const {
    TimeSlotConfig,
    BlockedSlot,
  } = require("../models/service-time-slot.model");

  // categoryId may be "default" / absent when the prebook flow opens this
  // screen without a specific category — guard against an invalid ObjectId.
  const hasValidCategory =
    !!categoryId && Types.ObjectId.isValid(categoryId) && categoryId !== "default";

  // Get time slot configuration
  let slotConfigs = await TimeSlotConfig.find({
    $or: hasValidCategory
      ? [{ categoryId: new Types.ObjectId(categoryId) }, { categoryId: null }]
      : [{ categoryId: null }],
    isActive: true,
  });

  // If no category-specific config, use default slots
  if (slotConfigs.length === 0) {
    slotConfigs = [
      {
        slotType: "MORNING",
        slots: [
          "08:00 Am",
          "08:15 Am",
          "08:30 Am",
          "08:45 Am",
          "09:00 Am",
          "09:15 Am",
          "09:30 Am",
          "09:45 Am",
          "10:00 Am",
          "10:15 Am",
          "10:30 Am",
          "10:45 Am",
          "11:00 Am",
          "11:15 Am",
          "11:30 Am",
          "11:45 Am",
        ],
      },
      {
        slotType: "AFTERNOON",
        slots: [
          "12:00 Pm",
          "12:15 Pm",
          "12:30 Pm",
          "12:45 Pm",
          "01:00 Pm",
          "01:15 Pm",
          "01:30 Pm",
          "01:45 Pm",
          "02:00 Pm",
          "02:15 Pm",
          "02:30 Pm",
          "02:45 Pm",
          "03:00 Pm",
          "03:15 Pm",
          "03:30 Pm",
          "03:45 Pm",
        ],
      },
      {
        slotType: "EVENING",
        slots: [
          "04:00 Pm",
          "04:15 Pm",
          "04:30 Pm",
          "04:45 Pm",
          "05:00 Pm",
          "05:15 Pm",
          "05:30 Pm",
          "05:45 Pm",
          "06:00 Pm",
          "06:15 Pm",
          "06:30 Pm",
          "06:45 Pm",
          "07:00 Pm",
          "07:15 Pm",
          "07:30 Pm",
          "07:45 Pm",
        ],
      },
    ];
  }

  // Get blocked slots for the date
  let blockedSlots: string[] = [];
  if (date && hasValidCategory) {
    const blockedData = await BlockedSlot.findOne({
      date: new Date(date as string),
      categoryId: new Types.ObjectId(categoryId),
    });
    if (blockedData) {
      blockedSlots = blockedData.blockedSlots;
    }
  }

  // Mark blocked slots
  const timeSlots = slotConfigs.map((config: any) => ({
    slotType: config.slotType,
    slots: (config.slots || []).map((slot: string) => ({
      time: slot,
      isAvailable: !blockedSlots.includes(slot),
    })),
  }));

  req.rData = { timeSlots, date };
  req.msg = "success";
  next();
};

// ============ SERVICE DETAILS (Inclusions/Exclusions) ============

/**
 * Get service types with detailed inclusions/exclusions
 */
export const getServiceTypes = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getServiceTypes");

  const { categoryId } = req.params;
  const isValidCategory =
    categoryId && Types.ObjectId.isValid(categoryId) && categoryId !== "default";

  const ServiceDetails = require("../models/service-details.model").default;

  const query: any = { isActive: true };
  if (isValidCategory) {
    query.categoryId = new Types.ObjectId(categoryId);
  }

  const serviceTypes = await ServiceDetails.find(query).sort({
    displayOrder: 1,
  });

  req.rData = { serviceTypes };
  req.msg = "success";
  next();
};

/**
 * Get detailed info for a specific service type
 */
export const getServiceTypeDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getServiceTypeDetails");

  const { categoryId, serviceSlug } = req.params;

  const ServiceDetails = require("../models/service-details.model").default;

  const serviceDetails = await ServiceDetails.findOne({
    categoryId: new Types.ObjectId(categoryId),
    slug: serviceSlug,
    isActive: true,
  });

  if (!serviceDetails) {
    req.rCode = 5;
    req.msg = "service_not_found";
    return next();
  }

  req.rData = { serviceDetails };
  req.msg = "success";
  next();
};

// ============ MULTIPLE BOOKING (Pre-book) ============

/**
 * Get available dates for multiple booking
 */
export const getAvailableDates = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getAvailableDates");

  const { categoryId } = req.params;
  const { startDate, endDate } = req.query;

  const start = startDate ? new Date(startDate as string) : new Date();
  const end = endDate
    ? new Date(endDate as string)
    : new Date(start.getTime() + 30 * 24 * 60 * 60 * 1000); // 30 days

  const { BlockedSlot } = require("../models/service-time-slot.model");

  // categoryId may be "default" / absent — only filter blocked dates by
  // category when it's a valid ObjectId, otherwise treat all dates as open.
  const hasValidCategory =
    !!categoryId && Types.ObjectId.isValid(categoryId) && categoryId !== "default";

  // Get fully blocked dates
  const blockedDates = hasValidCategory
    ? await BlockedSlot.find({
        categoryId: new Types.ObjectId(categoryId),
        date: { $gte: start, $lte: end },
      }).select("date blockedSlots")
    : [];

  // Generate date availability
  const dates: any[] = [];
  const currentDate = new Date(start);

  while (currentDate <= end) {
    const dateStr = currentDate.toISOString().split("T")[0];
    const blocked = blockedDates.find(
      (b: any) => b.date.toISOString().split("T")[0] === dateStr,
    );

    dates.push({
      date: new Date(currentDate),
      isAvailable: !blocked || blocked.blockedSlots.length < 48, // Not fully booked
      blockedSlotsCount: blocked?.blockedSlots.length || 0,
    });

    currentDate.setDate(currentDate.getDate() + 1);
  }

  req.rData = { dates };
  req.msg = "success";
  next();
};

/**
 * Create multiple/recurring booking (Pre-book)
 */
export const createMultipleBooking = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => createMultipleBooking");

  const userId = (req as any).userId;
  const {
    categoryId,
    serviceType,
    packageId,
    bookingType, // "SINGLE" or "MULTIPLE"
    startDate,
    endDate,
    selectedDates, // Array of specific dates for multiple
    durationMinutes,
    timeSlot,
    timeSlotType,
    address,
    promoCode,
    paymentMethod,
    useSubscription,
  } = req.body;

  const MultipleBooking = require("../models/multiple-booking.model").default;
  const ServicePackage = require("../models/service-package.model").default;

  // Get package pricing
  let perSessionPrice = 0;
  if (packageId) {
    const pkg = await ServicePackage.findById(packageId);
    if (pkg) {
      perSessionPrice = pkg.discountedPrice;
    }
  }

  // Calculate total sessions
  let totalSessions = 1;
  let dates: Date[] = [new Date(startDate)];

  if (bookingType === "MULTIPLE" && selectedDates && selectedDates.length > 0) {
    dates = selectedDates.map((d: string) => new Date(d));
    totalSessions = dates.length;
  } else if (bookingType === "MULTIPLE" && endDate) {
    // Generate dates from range
    const start = new Date(startDate);
    const end = new Date(endDate);
    dates = [];
    const current = new Date(start);
    while (current <= end) {
      dates.push(new Date(current));
      current.setDate(current.getDate() + 1);
    }
    totalSessions = dates.length;
  }

  // Calculate pricing
  const subtotal = perSessionPrice * totalSessions;
  const taxRate = 0.18; // 18% GST
  const taxes = Math.round(subtotal * taxRate);
  let discount = 0;

  // Apply promo code if provided
  if (promoCode) {
    const Offer = require("../models/offer.model").default;
    const offer = await Offer.findOne({
      code: promoCode.toUpperCase(),
      isActive: true,
      $or: [{ applicableOn: "ALL" }, { applicableOn: "HOUSEHOLD" }],
    });

    if (offer) {
      if (offer.type === "PERCENTAGE") {
        discount = Math.min(
          Math.round((subtotal * offer.value) / 100),
          offer.maxDiscount || Infinity,
        );
      } else if (offer.type === "FLAT") {
        discount = offer.value;
      }
    }
  }

  // Apply Kebu Pass discount on top of any promo discount
  const benefits = await SubscriptionBenefitsService.getActiveBenefits(userId);
  const preSubDiscountAmount = Math.max(subtotal + taxes - discount, 0);
  const subscriptionDiscount =
    SubscriptionBenefitsService.computeSubscriptionDiscount(
      preSubDiscountAmount,
      benefits,
    );
  if (subscriptionDiscount > 0) {
    discount += subscriptionDiscount;
  }

  const totalAmount = Math.max(subtotal + taxes - discount, 0);
  const perSessionDiscount =
    totalSessions > 0 ? Math.round(discount / totalSessions) : 0;
  const perSessionFinalCost = Math.max(perSessionPrice - perSessionDiscount, 0);

  // Create parent booking
  const multipleBooking = await MultipleBooking.create({
    userId,
    categoryId,
    serviceType,
    packageId,
    bookingType,
    startDate: new Date(startDate),
    endDate: endDate ? new Date(endDate) : undefined,
    selectedDates: dates,
    durationMinutes,
    timeSlot,
    timeSlotType,
    address,
    perSessionPrice,
    totalSessions,
    subtotal,
    taxes,
    discount,
    subscriptionDiscount: subscriptionDiscount > 0 ? subscriptionDiscount : 0,
    subscriptionPlanName:
      subscriptionDiscount > 0 ? benefits?.planName : undefined,
    promoCode: promoCode?.toUpperCase(),
    totalAmount,
    paymentMethod: paymentMethod || "CASH",
    status: "CONFIRMED",
  });

  // Spawn a ServiceBooking per session so providers can see & accept each one
  const io = req.app.get("io");
  const sessionBookings: any[] = [];
  for (let i = 0; i < dates.length; i++) {
    const sessionDate = dates[i];
    const child = await HouseholdService.createServiceBooking({
      userId,
      categoryId: new Types.ObjectId(categoryId),
      serviceType,
      preferredDate: sessionDate,
      preferredTimeSlot: timeSlot,
      estimatedDuration: durationMinutes,
      address,
      estimatedCost: perSessionPrice,
      finalCost: perSessionFinalCost,
      discount: perSessionDiscount,
      promoCode: promoCode?.toUpperCase(),
      paymentMethod: paymentMethod || "CASH",
      status: "PENDING",
      multipleBookingId: multipleBooking._id,
      sessionIndex: i,
    });
    sessionBookings.push(child);

    // Broadcast to nearby cleaning drivers for each session booking
    if (io && address?.lat && address?.lng) {
      try {
        const nearby = await DriverLocationService.findNearbyDrivers(
          address.lat,
          address.lng,
          10,
          undefined,
          "cleaning",
          new Types.ObjectId(categoryId),
        );
        nearby.forEach(({ driver }) => {
          io.to(`driver_${driver._id}`).emit("new_service_booking", {
            booking: child,
            parentBookingId: multipleBooking._id,
          });
        });
      } catch (err) {
        console.error(
          "Error broadcasting prebook session to drivers:",
          err,
        );
      }
    }
  }

  multipleBooking.sessionBookings = sessionBookings.map((b: any) => b._id);
  await multipleBooking.save();

  req.rData = {
    booking: multipleBooking,
    sessionBookings,
    summary: {
      totalSessions,
      perSessionPrice,
      subtotal,
      taxes,
      discount,
      totalAmount,
    },
    subscriptionBenefit: benefits
      ? {
          planName: benefits.planName,
          discountPercentage: benefits.discountPercentage,
          subscriptionDiscount,
        }
      : null,
  };
  req.msg = "booking_created";
  next();
};

/**
 * Get booking fare summary/estimate
 */
export const getBookingEstimate = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getBookingEstimate");

  const { packageId, totalSessions, promoCode } = req.body;

  const ServicePackage = require("../models/service-package.model").default;

  // Get package pricing
  const pkg = await ServicePackage.findById(packageId);
  if (!pkg) {
    req.rCode = 5;
    req.msg = "package_not_found";
    return next();
  }

  const sessions = totalSessions || 1;
  const subtotal = pkg.discountedPrice * sessions;
  const taxRate = 0.18;
  const taxes = Math.round(subtotal * taxRate);
  let discount = 0;
  let promoApplied = false;

  // Apply promo code if provided
  if (promoCode) {
    const Offer = require("../models/offer.model").default;
    const offer = await Offer.findOne({
      code: promoCode.toUpperCase(),
      isActive: true,
      $or: [{ applicableOn: "ALL" }, { applicableOn: "HOUSEHOLD" }],
    });

    if (offer) {
      promoApplied = true;
      if (offer.type === "PERCENTAGE") {
        discount = Math.min(
          Math.round((subtotal * offer.value) / 100),
          offer.maxDiscount || Infinity,
        );
      } else if (offer.type === "FLAT") {
        discount = offer.value;
      }
    }
  }

  const totalAmount = subtotal + taxes - discount;

  req.rData = {
    package: {
      name: pkg.name,
      durationMinutes: pkg.durationMinutes,
      pricePerSession: pkg.discountedPrice,
      originalPrice: pkg.originalPrice,
    },
    totalSessions: sessions,
    subtotal,
    taxes,
    discount,
    promoApplied,
    totalAmount,
  };
  req.msg = "success";
  next();
};

/**
 * Get starter pack offers for household services
 */
export const getStarterPacks = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getStarterPacks");

  const { categoryId } = req.params;

  // Get subscription plans that apply to household services
  const { SubscriptionPlan } = require("../models/subscription.model");

  const plans = await SubscriptionPlan.find({
    isActive: true,
    $or: [
      { "benefits.unlimitedDeliveries": true },
      { "benefits.discountPercentage": { $gt: 0 } },
    ],
  }).sort({ price: 1 });

  // Get special starter pack offers
  const Offer = require("../models/offer.model").default;
  const starterOffers = await Offer.find({
    isActive: true,
    isFirstTimeUser: true,
    $or: [{ applicableOn: "ALL" }, { applicableOn: "HOUSEHOLD" }],
  });

  req.rData = {
    subscriptionPlans: plans,
    starterOffers,
  };
  req.msg = "success";
  next();
};

/**
 * Get current service hours and open/closed status (public)
 */
export const getServiceHours = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => getServiceHours");
  const hours = await HouseholdService.getServiceHours();
  const status = HouseholdService.computeOpenStatus({
    openTime: hours.openTime,
    closeTime: hours.closeTime,
    daysActive: hours.daysActive,
    timezone: hours.timezone,
    isEnabled: hours.isEnabled,
  });
  req.rData = {
    openTime: hours.openTime,
    closeTime: hours.closeTime,
    daysActive: hours.daysActive,
    timezone: hours.timezone,
    isEnabled: hours.isEnabled,
    closedMessage: hours.closedMessage,
    isOpen: status.isOpen,
    reason: status.reason,
  };
  req.msg = "success";
  next();
};

/**
 * Admin: update household service hours
 */
export const updateServiceHours = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("HouseholdController => updateServiceHours");
  const {
    openTime,
    closeTime,
    daysActive,
    timezone,
    isEnabled,
    closedMessage,
  } = req.body;

  const timeRegex = /^([01]\d|2[0-3]):[0-5]\d$/;
  if (openTime && !timeRegex.test(openTime)) {
    req.rCode = 0;
    req.msg = "openTime must be HH:mm (24h)";
    return next();
  }
  if (closeTime && !timeRegex.test(closeTime)) {
    req.rCode = 0;
    req.msg = "closeTime must be HH:mm (24h)";
    return next();
  }
  if (
    daysActive &&
    (!Array.isArray(daysActive) ||
      daysActive.some((d: number) => d < 0 || d > 6))
  ) {
    req.rCode = 0;
    req.msg = "daysActive must be array of 0-6";
    return next();
  }

  const adminId = (req as any).user?._id
    ? new Types.ObjectId((req as any).user._id)
    : undefined;
  const updated = await HouseholdService.updateServiceHours(
    { openTime, closeTime, daysActive, timezone, isEnabled, closedMessage },
    adminId,
  );
  req.rData = updated;
  req.msg = "Service hours updated";
  next();
};

// ============ BOOKING TYPE CONFIG (Single / Multiple pre-book pricing) ============

const DEFAULT_BOOKING_TYPE_CONFIGS = [
  {
    bookingType: "SINGLE" as const,
    title: "Single Booking",
    description: "Book a single session",
    basePrice: 499,
    discountedPrice: 399,
    displayOrder: 1,
    isActive: true,
  },
  {
    bookingType: "MULTIPLE" as const,
    title: "Multiple Booking",
    description: "Book multiple sessions and save more",
    basePrice: 1499,
    discountedPrice: 1199,
    displayOrder: 2,
    isActive: true,
  },
];

export const getBookingTypeConfigs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const BookingTypeConfig = require("../models/booking-type-config.model").default;
  const rawServiceId = (req.query.serviceId || req.query.service) as
    | string
    | undefined;
  const isValidService =
    !!rawServiceId && Types.ObjectId.isValid(rawServiceId);

  // Seed globals once so the fallback list is always populated.
  const globalCount = await BookingTypeConfig.countDocuments({
    serviceId: null,
  });
  if (globalCount === 0) {
    await BookingTypeConfig.insertMany(
      DEFAULT_BOOKING_TYPE_CONFIGS.map((d) => ({ ...d, serviceId: null })),
    );
  }

  const globals = await BookingTypeConfig.find({ serviceId: null }).sort({
    displayOrder: 1,
  });

  if (!isValidService) {
    req.rData = { bookingTypes: globals };
    return next();
  }

  const serviceObjectId = new Types.ObjectId(rawServiceId!);
  const overrides = await BookingTypeConfig.find({
    serviceId: serviceObjectId,
  }).sort({ displayOrder: 1 });

  // Merge: per-service override wins over global when both exist for a type.
  const byType = new Map<string, any>();
  for (const cfg of globals) byType.set(cfg.bookingType, cfg);
  for (const cfg of overrides) byType.set(cfg.bookingType, cfg);

  const merged = Array.from(byType.values()).sort(
    (a: any, b: any) => (a.displayOrder ?? 0) - (b.displayOrder ?? 0),
  );
  req.rData = { bookingTypes: merged };
  next();
};

export const updateBookingTypeConfig = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const BookingTypeConfig = require("../models/booking-type-config.model").default;
  const { bookingType } = req.params;
  if (bookingType !== "SINGLE" && bookingType !== "MULTIPLE") {
    req.rCode = 0;
    req.msg = "Invalid bookingType";
    return next();
  }

  const { title, description, basePrice, discountedPrice, displayOrder, isActive, serviceId } =
    req.body || {};

  if (basePrice != null && (typeof basePrice !== "number" || basePrice < 0)) {
    req.rCode = 0;
    req.msg = "basePrice must be a non-negative number";
    return next();
  }
  if (
    discountedPrice != null &&
    (typeof discountedPrice !== "number" || discountedPrice < 0)
  ) {
    req.rCode = 0;
    req.msg = "discountedPrice must be a non-negative number";
    return next();
  }

  const serviceObjectId =
    serviceId && Types.ObjectId.isValid(serviceId)
      ? new Types.ObjectId(serviceId)
      : null;

  const adminId = (req as any).user?._id
    ? new Types.ObjectId((req as any).user._id)
    : undefined;

  const update: any = { updatedBy: adminId };
  if (title !== undefined) update.title = title;
  if (description !== undefined) update.description = description;
  if (basePrice !== undefined) update.basePrice = basePrice;
  if (discountedPrice !== undefined) update.discountedPrice = discountedPrice;
  if (displayOrder !== undefined) update.displayOrder = displayOrder;
  if (isActive !== undefined) update.isActive = isActive;

  const defaults = DEFAULT_BOOKING_TYPE_CONFIGS.find(
    (d) => d.bookingType === bookingType,
  )!;

  const saved = await BookingTypeConfig.findOneAndUpdate(
    { bookingType, serviceId: serviceObjectId },
    {
      $set: update,
      $setOnInsert: { ...defaults, serviceId: serviceObjectId },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );
  req.rData = { bookingType: saved };
  req.msg = "Booking type updated";
  next();
};
