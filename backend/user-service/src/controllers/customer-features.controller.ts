import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";

import Offer from "../models/offer.model";
import {
  SubscriptionPlan,
  UserSubscription,
} from "../models/subscription.model";
import {
  Referral,
  Notification,
  FAQ,
  SupportTicket,
  PaymentMethod,
  Rider,
} from "../models/customer-features.model";
import User from "../models/Users";
import * as WalletService from "../services/wallet.service";
import helpers from "../utils/helpers";

// ============ OFFERS ============

/**
 * Get all active offers
 */
export const getOffers = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { type } = req.query; // ALL, CAB, DELIVERY, HOUSEHOLD, WALLET

  const now = new Date();

  const query: any = {
    isActive: true,
    isDeleted: false,
    startDate: { $lte: now },
    endDate: { $gte: now },
  };

  if (type && type !== "ALL") {
    query.applicableOn = { $in: ["ALL", type] };
  }

  const offers = await Offer.find(query)
    .select("-targetUserIds -usageLimit -usedCount")
    .sort({ priority: -1, createdAt: -1 })
    .limit(40);

  const bySection = (s: string) =>
    offers.filter((o) => (o as any).section === s);

  const latestOffers = bySection("latest");
  const limitedOffers = bySection("limited");
  const justForYouOffers = bySection("just_for_you");

  req.rData = {
    offers,
    latestOffers,
    limitedOffers,
    justForYouOffers,
  };
  req.msg = "success";
  next();
};

/**
 * Apply promo code
 */
export const applyPromoCode = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { code, orderType, orderAmount } = req.body;

  // Normalize client-side order types to the Offer.applicableOn enum
  // (Offer enum: ALL | CAB | DELIVERY | HOUSEHOLD | WALLET)
  const orderTypeAliases: Record<string, string> = {
    SERVICE: "HOUSEHOLD",
    CLEANING: "HOUSEHOLD",
    PARCEL: "DELIVERY",
    RIDE: "CAB",
  };
  const normalizedOrderType =
    orderTypeAliases[String(orderType || "").toUpperCase()] ||
    String(orderType || "").toUpperCase();

  const now = new Date();

  const offer = await Offer.findOne({
    code: code.toUpperCase(),
    isActive: true,
    isDeleted: false,
    startDate: { $lte: now },
    endDate: { $gte: now },
  });

  if (!offer) {
    req.rCode = 0;
    req.msg = "invalid_promo_code";
    return next();
  }

  // Check applicability
  if (
    offer.applicableOn !== "ALL" &&
    offer.applicableOn !== normalizedOrderType
  ) {
    req.rCode = 0;
    req.msg = "promo_not_applicable";
    return next();
  }

  // Check minimum order value
  if (offer.minOrderValue && orderAmount < offer.minOrderValue) {
    req.rCode = 0;
    req.msg = "min_order_not_met";
    return next();
  }

  // Check usage limit
  if (offer.usageLimit && offer.usedCount >= offer.usageLimit) {
    req.rCode = 0;
    req.msg = "promo_expired";
    return next();
  }

  // Calculate discount
  const offerValue = offer.value ?? 0;
  let discount = 0;
  if (offer.type === "PERCENTAGE") {
    discount = (orderAmount * offerValue) / 100;
    if (offer.maxDiscount) {
      discount = Math.min(discount, offer.maxDiscount);
    }
  } else if (offer.type === "FLAT") {
    discount = offerValue;
  } else if (offer.type === "CASHBACK") {
    discount = 0; // Cashback applied after payment
  }

  req.rData = {
    valid: true,
    offer: {
      _id: offer._id,
      code: offer.code,
      type: offer.type,
      discount: Math.round(discount),
      cashback: offer.type === "CASHBACK" ? offerValue : 0,
    },
  };
  req.msg = "success";
  next();
};

// ============ SUBSCRIPTION ============

/**
 * Get subscription plans
 */
export const getSubscriptionPlans = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const plans = await SubscriptionPlan.find({
    isActive: true,
    isDeleted: false,
  }).sort({ duration: 1 });

  req.rData = { plans };
  req.msg = "success";
  next();
};

/**
 * Get user's active subscription
 */
export const getMySubscription = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;

  const subscription = await UserSubscription.findOne({
    userId,
    status: "ACTIVE",
    endDate: { $gte: new Date() },
  }).populate("planId");

  req.rData = { subscription };
  req.msg = "success";
  next();
};

/**
 * Subscribe to a plan
 */
export const subscribeToPlan = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { planId, paymentId, isTrial } = req.body;

  const plan = await SubscriptionPlan.findById(planId);
  if (!plan) {
    req.rCode = 0;
    req.msg = "plan_not_found";
    return next();
  }

  // Check if user already has active subscription
  const existingSubscription = await UserSubscription.findOne({
    userId,
    status: "ACTIVE",
    endDate: { $gte: new Date() },
  });

  if (existingSubscription) {
    req.rCode = 0;
    req.msg = "subscription_already_active";
    return next();
  }

  const startDate = new Date();
  const endDate = new Date();

  if (isTrial && plan.isTrialAvailable) {
    endDate.setDate(endDate.getDate() + plan.trialDays);
  } else {
    endDate.setDate(endDate.getDate() + plan.duration);
  }

  const subscription = await UserSubscription.create({
    userId,
    planId,
    startDate,
    endDate,
    paymentId,
    amount: isTrial ? 0 : plan.price,
    status: "ACTIVE",
    isTrial: isTrial || false,
  });

  req.rData = { subscription };
  req.msg = "subscription_created";
  next();
};

// ============ REFERRAL ============

/**
 * Get referral info
 */
export const getReferralInfo = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;

  const user = await User.findById(userId).select("referralCode");

  const referrals = await Referral.find({ referrerId: userId })
    .populate("referredId", "fullName createdAt")
    .sort({ createdAt: -1 })
    .limit(20);

  const totalEarned = referrals
    .filter((r) => r.referrerRewarded)
    .reduce((sum, r) => sum + r.referrerReward, 0);

  const pendingReferrals = referrals.filter(
    (r) => r.status === "PENDING",
  ).length;
  const completedReferrals = referrals.filter(
    (r) => r.status === "COMPLETED",
  ).length;

  req.rData = {
    referralCode: user?.referralCode,
    referrerReward: 400,
    referredReward: 50,
    totalEarned,
    pendingReferrals,
    completedReferrals,
    referrals,
  };
  req.msg = "success";
  next();
};

/**
 * Apply referral code
 */
export const applyReferralCode = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { referralCode } = req.body;

  // Check if user already applied a referral code
  const existingReferral = await Referral.findOne({ referredId: userId });
  if (existingReferral) {
    req.rCode = 0;
    req.msg = "referral_already_applied";
    return next();
  }

  // Find referrer
  const referrer = await User.findOne({
    referralCode: referralCode.toUpperCase(),
    isDeleted: false,
  });

  if (!referrer) {
    req.rCode = 0;
    req.msg = "invalid_referral_code";
    return next();
  }

  if (referrer._id.toString() === userId.toString()) {
    req.rCode = 0;
    req.msg = "cannot_refer_self";
    return next();
  }

  // Create referral record
  const referral = await Referral.create({
    referrerId: referrer._id,
    referredId: userId,
    referralCode,
    status: "PENDING",
    referrerReward: 400,
    referredReward: 50,
  });

  // Give immediate reward to referred user
  await WalletService.addToWallet(
    userId,
    50,
    "Referral signup bonus",
    "REFERRAL",
  );
  await Referral.findByIdAndUpdate(referral._id, { referredRewarded: true });

  req.rData = { referral };
  req.msg = "referral_applied";
  next();
};

// ============ NOTIFICATIONS ============

/**
 * Get notifications
 */
export const getNotifications = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { page = 1, limit = 20 } = req.query;

  const notifications = await Notification.find({ userId })
    .sort({ createdAt: -1 })
    .skip((Number(page) - 1) * Number(limit))
    .limit(Number(limit));

  const total = await Notification.countDocuments({ userId });
  const unreadCount = await Notification.countDocuments({
    userId,
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
 * Mark notification as read
 */
export const markNotificationRead = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { notificationId } = req.params;

  if (notificationId === "all") {
    await Notification.updateMany(
      { userId, isRead: false },
      { isRead: true, readAt: new Date() },
    );
  } else {
    await Notification.findOneAndUpdate(
      { _id: notificationId, userId },
      { isRead: true, readAt: new Date() },
    );
  }

  req.rData = {};
  req.msg = "success";
  next();
};

// ============ FAQ ============

/**
 * Get FAQs
 */
export const getFAQs = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const { category } = req.query;

  const query: any = { isActive: true };
  if (category) {
    query.category = category;
  }

  const faqs = await FAQ.find(query).sort({ category: 1, order: 1 });

  // Group by category
  const grouped = faqs.reduce((acc: any, faq) => {
    if (!acc[faq.category]) {
      acc[faq.category] = [];
    }
    acc[faq.category].push(faq);
    return acc;
  }, {});

  req.rData = { faqs, grouped };
  req.msg = "success";
  next();
};

// ============ SUPPORT ============

/**
 * Create support ticket
 */
export const createSupportTicket = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { subject, description, category, bookingId } = req.body;

  const ticket = await SupportTicket.create({
    userId,
    subject,
    description,
    category: category || "OTHER",
    bookingId,
    messages: [
      {
        senderId: userId,
        senderType: "USER",
        message: description,
        createdAt: new Date(),
      },
    ],
  });

  req.rData = { ticket };
  req.msg = "ticket_created";
  next();
};

/**
 * Get user's support tickets
 */
export const getSupportTickets = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;

  const tickets = await SupportTicket.find({ userId })
    .sort({ updatedAt: -1 })
    .limit(20);

  req.rData = { tickets };
  req.msg = "success";
  next();
};

/**
 * Get ticket details
 */
export const getTicketDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { ticketId } = req.params;

  const ticket = await SupportTicket.findOne({ _id: ticketId, userId })
    .populate("bookingId")
    .populate("assignedTo", "fullName");

  if (!ticket) {
    req.rCode = 0;
    req.msg = "ticket_not_found";
    return next();
  }

  req.rData = { ticket };
  req.msg = "success";
  next();
};

/**
 * Add message to ticket
 */
export const addTicketMessage = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { ticketId } = req.params;
  const { message, attachments } = req.body;

  const ticket = await SupportTicket.findOneAndUpdate(
    { _id: ticketId, userId },
    {
      $push: {
        messages: {
          senderId: userId,
          senderType: "USER",
          message,
          attachments,
          createdAt: new Date(),
        },
      },
      status: "OPEN",
    },
    { new: true },
  );

  if (!ticket) {
    req.rCode = 0;
    req.msg = "ticket_not_found";
    return next();
  }

  req.rData = { ticket };
  req.msg = "success";
  next();
};

// ============ PAYMENT METHODS ============

/**
 * Get saved payment methods
 */
export const getPaymentMethods = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;

  const methods = await PaymentMethod.find({ userId }).sort({
    isDefault: -1,
    createdAt: -1,
  });

  req.rData = { methods };
  req.msg = "success";
  next();
};

/**
 * Add payment method
 */
export const addPaymentMethod = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const {
    type,
    upiId,
    upiApp,
    cardLast4,
    cardBrand,
    cardExpiry,
    cardHolderName,
    bankName,
    accountLast4,
    isDefault,
  } = req.body;

  // If setting as default, remove default from others
  if (isDefault) {
    await PaymentMethod.updateMany({ userId }, { isDefault: false });
  }

  const method = await PaymentMethod.create({
    userId,
    type,
    upiId,
    upiApp,
    cardLast4,
    cardBrand,
    cardExpiry,
    cardHolderName,
    bankName,
    accountLast4,
    isDefault: isDefault || false,
    isVerified: true,
  });

  req.rData = { method };
  req.msg = "payment_method_added";
  next();
};

/**
 * Delete payment method
 */
export const deletePaymentMethod = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { methodId } = req.params;

  await PaymentMethod.findOneAndDelete({ _id: methodId, userId });

  req.rData = {};
  req.msg = "success";
  next();
};

// ============ RIDERS (Book for Others) ============

/**
 * Get saved riders
 */
export const getRiders = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;

  const riders = await Rider.find({ userId }).sort({ isDefault: -1, name: 1 });

  req.rData = { riders };
  req.msg = "success";
  next();
};

/**
 * Add rider
 */
export const addRider = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { name, phone, relationship, isDefault } = req.body;

  if (isDefault) {
    await Rider.updateMany({ userId }, { isDefault: false });
  }

  const rider = await Rider.create({
    userId,
    name,
    phone,
    relationship,
    isDefault: isDefault || false,
  });

  req.rData = { rider };
  req.msg = "rider_added";
  next();
};

/**
 * Update rider
 */
export const updateRider = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { riderId } = req.params;
  const { name, phone, relationship, isDefault } = req.body;

  if (isDefault) {
    await Rider.updateMany({ userId }, { isDefault: false });
  }

  const rider = await Rider.findOneAndUpdate(
    { _id: riderId, userId },
    { name, phone, relationship, isDefault },
    { new: true },
  );

  req.rData = { rider };
  req.msg = "success";
  next();
};

/**
 * Delete rider
 */
export const deleteRider = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { riderId } = req.params;

  await Rider.findOneAndDelete({ _id: riderId, userId });

  req.rData = {};
  req.msg = "success";
  next();
};

// ============ TIP ============

/**
 * Add tip to booking
 */
export const addTip = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  const userId = req.user?._id;
  const { bookingId, amount } = req.body;

  // Import Booking model here to avoid circular dependency
  const Booking = require("../models/booking.model").default;

  const booking = await Booking.findOne({
    _id: bookingId,
    userId,
    status: "COMPLETED",
  });

  if (!booking) {
    req.rCode = 0;
    req.msg = "booking_not_found";
    return next();
  }

  // Deduct from wallet
  const wallet = await WalletService.deductFromWallet(
    userId,
    amount,
    `Tip for booking ${bookingId}`,
    "TIP",
  );

  // Add to driver's wallet
  if (booking.driverId) {
    await WalletService.addToWallet(
      booking.driverId,
      amount,
      `Tip received for booking ${bookingId}`,
      "TIP",
    );
  }

  // Update booking with tip
  await Booking.findByIdAndUpdate(bookingId, {
    $set: { tip: amount },
  });

  req.rData = { tipAmount: amount };
  req.msg = "tip_added";
  next();
};
