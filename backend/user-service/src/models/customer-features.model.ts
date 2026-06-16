import mongoose, { Schema, Types } from "mongoose";

export interface IReferral {
  _id?: Types.ObjectId;
  referrerId: Types.ObjectId; // User who referred
  referredId: Types.ObjectId; // New user who signed up
  referralCode: string;

  status: "PENDING" | "COMPLETED" | "EXPIRED";

  // Rewards
  referrerReward: number;
  referredReward: number;
  referrerRewarded: boolean;
  referredRewarded: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface INotification {
  _id?: Types.ObjectId;
  // Exactly one of userId / driverId is set (the audience for this notification).
  userId?: Types.ObjectId;
  driverId?: Types.ObjectId;

  title: string;
  message: string;
  type: "REMINDER" | "MESSAGE" | "ORDER" | "OFFER" | "SYSTEM";

  data?: {
    bookingId?: Types.ObjectId;
    orderId?: Types.ObjectId;
    offerId?: Types.ObjectId;
    deepLink?: string;
  };

  icon?: string;
  image?: string;

  isRead: boolean;
  readAt?: Date;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface IFAQ {
  _id?: Types.ObjectId;
  question: string;
  answer: string;
  category:
    | "GENERAL"
    | "CONTACT"
    | "PAYMENT"
    | "BOOKING"
    | "DRIVER"
    | "SERVICE";
  order: number;
  isActive: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface ISupportTicket {
  _id?: Types.ObjectId;
  userId?: Types.ObjectId;
  driverId?: Types.ObjectId;

  subject: string;
  description: string;
  category: "BOOKING" | "PAYMENT" | "DRIVER" | "SERVICE" | "APP" | "OTHER";

  status: "OPEN" | "IN_PROGRESS" | "RESOLVED" | "CLOSED";
  priority: "LOW" | "MEDIUM" | "HIGH";

  bookingId?: Types.ObjectId;

  assignedTo?: Types.ObjectId; // Admin user

  messages: {
    senderId: Types.ObjectId;
    senderType: "USER" | "ADMIN" | "DRIVER";
    message: string;
    attachments?: string[];
    createdAt: Date;
  }[];

  resolvedAt?: Date;
  closedAt?: Date;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface IPaymentMethod {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;

  type: "CARD" | "UPI" | "NETBANKING";

  // For cards
  cardLast4?: string;
  cardBrand?: string; // Visa, Mastercard
  cardExpiry?: string;
  cardHolderName?: string;

  // For UPI
  upiId?: string;
  upiApp?: string; // GPay, PhonePe, Paytm

  // For netbanking
  bankName?: string;
  accountLast4?: string;

  isDefault: boolean;
  isVerified: boolean;

  razorpayTokenId?: string;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface IRider {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;

  name: string;
  phone: string;
  relationship?: string; // "Friend", "Family", etc.

  isDefault: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

// Schemas
const ReferralSchema = new Schema<IReferral>(
  {
    referrerId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    referredId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    referralCode: { type: String, required: true },
    status: {
      type: String,
      enum: ["PENDING", "COMPLETED", "EXPIRED"],
      default: "PENDING",
    },
    referrerReward: { type: Number, default: 400 },
    referredReward: { type: Number, default: 50 },
    referrerRewarded: { type: Boolean, default: false },
    referredRewarded: { type: Boolean, default: false },
  },
  { timestamps: true },
);

const NotificationSchema = new Schema<INotification>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      index: true,
    },
    driverId: {
      type: Schema.Types.ObjectId,
      ref: "Driver",
      index: true,
    },
    title: { type: String, required: true },
    message: { type: String, required: true },
    type: {
      type: String,
      enum: ["REMINDER", "MESSAGE", "ORDER", "OFFER", "SYSTEM"],
      default: "SYSTEM",
    },
    data: {
      bookingId: { type: Schema.Types.ObjectId, ref: "Booking" },
      orderId: String,
      offerId: { type: Schema.Types.ObjectId, ref: "Offer" },
      deepLink: String,
    },
    icon: String,
    image: String,
    isRead: { type: Boolean, default: false, index: true },
    readAt: Date,
  },
  { timestamps: true },
);

const FAQSchema = new Schema<IFAQ>(
  {
    question: { type: String, required: true },
    answer: { type: String, required: true },
    category: {
      type: String,
      enum: ["GENERAL", "CONTACT", "PAYMENT", "BOOKING", "DRIVER", "SERVICE"],
      default: "GENERAL",
    },
    order: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

const SupportTicketSchema = new Schema<ISupportTicket>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      index: true,
    },
    driverId: {
      type: Schema.Types.ObjectId,
      ref: "Driver",
      index: true,
    },
    subject: { type: String, required: true },
    description: { type: String, required: true },
    category: {
      type: String,
      enum: ["BOOKING", "PAYMENT", "DRIVER", "SERVICE", "APP", "OTHER"],
      default: "OTHER",
    },
    status: {
      type: String,
      enum: ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"],
      default: "OPEN",
      index: true,
    },
    priority: {
      type: String,
      enum: ["LOW", "MEDIUM", "HIGH"],
      default: "MEDIUM",
    },
    bookingId: { type: Schema.Types.ObjectId, ref: "Booking" },
    assignedTo: { type: Schema.Types.ObjectId, ref: "Admin" },
    messages: [
      {
        senderId: { type: Schema.Types.ObjectId, required: true },
        senderType: { type: String, enum: ["USER", "ADMIN", "DRIVER"], required: true },
        message: { type: String, required: true },
        attachments: [String],
        createdAt: { type: Date, default: Date.now },
      },
    ],
    resolvedAt: Date,
    closedAt: Date,
  },
  { timestamps: true },
);

const PaymentMethodSchema = new Schema<IPaymentMethod>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ["CARD", "UPI", "NETBANKING"],
      required: true,
    },
    cardLast4: String,
    cardBrand: String,
    cardExpiry: String,
    cardHolderName: String,
    upiId: String,
    upiApp: String,
    bankName: String,
    accountLast4: String,
    isDefault: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: false },
    razorpayTokenId: String,
  },
  { timestamps: true },
);

const RiderSchema = new Schema<IRider>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    name: { type: String, required: true },
    phone: { type: String, required: true },
    relationship: String,
    isDefault: { type: Boolean, default: false },
  },
  { timestamps: true },
);

// Indexes - Note: userId and status already have index: true in field definitions
ReferralSchema.index({ referrerId: 1, status: 1 });
ReferralSchema.index({ referralCode: 1 });
NotificationSchema.index({ createdAt: -1 }); // userId already indexed in field
FAQSchema.index({ category: 1, isActive: 1, order: 1 });
PaymentMethodSchema.index({ isDefault: 1 }); // userId already indexed in field

export const Referral = mongoose.model<IReferral>("Referral", ReferralSchema);
export const Notification = mongoose.model<INotification>(
  "Notification",
  NotificationSchema,
);
export const FAQ = mongoose.model<IFAQ>("FAQ", FAQSchema);
export const SupportTicket = mongoose.model<ISupportTicket>(
  "SupportTicket",
  SupportTicketSchema,
);
export const PaymentMethod = mongoose.model<IPaymentMethod>(
  "PaymentMethod",
  PaymentMethodSchema,
);
export const Rider = mongoose.model<IRider>("Rider", RiderSchema);
