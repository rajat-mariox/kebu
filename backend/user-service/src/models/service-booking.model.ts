import mongoose, { Schema, Types } from "mongoose";

export type ServiceBookingStatus =
  | "PENDING"
  | "ACCEPTED"
  | "PROVIDER_ASSIGNED"
  | "PROVIDER_EN_ROUTE"
  | "PROVIDER_ARRIVED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED";

export interface IServiceBooking {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;
  providerId?: Types.ObjectId;
  categoryId: Types.ObjectId;

  // Service details
  serviceType: string; // e.g., "AC Repair", "Deep Cleaning"
  description?: string;
  preferredDate: Date;
  preferredTimeSlot: string; // e.g., "10:00 AM - 12:00 PM"
  estimatedDuration?: number; // in minutes

  // Location
  address: {
    fullAddress: string;
    landmark?: string;
    lat: number;
    lng: number;
    city?: string;
    pincode?: string;
  };

  // Pricing
  estimatedCost?: number;
  actualCost?: number;
  discount: number;
  finalCost?: number;
  // Extra charge the provider adds while completing the work (e.g. parts).
  extraAmount?: number;
  extraAmountReason?: string;
  promoCode?: string;
  paymentMethod: "CASH" | "WALLET" | "CARD" | "UPI";
  paymentStatus: "PENDING" | "PAID" | "FAILED" | "REFUNDED";

  // Parent prebook linkage (set when created as a session of a MultipleBooking)
  multipleBookingId?: Types.ObjectId;
  sessionIndex?: number;

  // Status
  status: ServiceBookingStatus;
  otp?: string;
  cancellationReason?: string;
  cancelledBy?: "USER" | "PROVIDER" | "SYSTEM";

  // Timestamps
  acceptedAt?: Date;
  providerArrivedAt?: Date;
  startedAt?: Date;
  completedAt?: Date;
  cancelledAt?: Date;

  // Rating
  userRating?: number;
  userFeedback?: string;
  providerRating?: number;
  providerFeedback?: string;

  // Notes
  userNotes?: string;
  providerNotes?: string;

  // Images
  beforeImages?: string[];
  afterImages?: string[];

  // Photos the provider captures when starting the service (Figma "Service
  // details" photo step).
  serviceStartPhotos?: {
    selfie?: string;
    devicePhoto?: string;
    serialPhoto?: string;
    otherPhoto?: string;
  };

  createdAt?: Date;
  updatedAt?: Date;
}

const ServiceBookingSchema = new Schema<IServiceBooking>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    providerId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceProvider",
      index: true,
    },
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      required: true,
      index: true,
    },

    serviceType: { type: String, required: true },
    description: String,
    preferredDate: { type: Date, required: true },
    preferredTimeSlot: { type: String, required: true },
    estimatedDuration: Number,

    address: {
      fullAddress: { type: String, required: true },
      landmark: String,
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
      // Optional — a GPS-pin booking may not resolve city/pincode.
      city: { type: String, default: "" },
      pincode: { type: String, default: "" },
    },

    estimatedCost: Number,
    actualCost: Number,
    discount: { type: Number, default: 0 },
    finalCost: Number,
    extraAmount: { type: Number, default: 0 },
    extraAmountReason: { type: String, default: "" },
    promoCode: { type: String, uppercase: true },
    multipleBookingId: {
      type: Schema.Types.ObjectId,
      ref: "MultipleBooking",
      index: true,
    },
    sessionIndex: { type: Number },
    paymentMethod: {
      type: String,
      enum: ["CASH", "WALLET", "CARD", "UPI"],
      default: "CASH",
    },
    paymentStatus: {
      type: String,
      enum: ["PENDING", "PAID", "FAILED", "REFUNDED"],
      default: "PENDING",
    },

    status: {
      type: String,
      enum: [
        "PENDING",
        "ACCEPTED",
        "PROVIDER_ASSIGNED",
        "PROVIDER_EN_ROUTE",
        "PROVIDER_ARRIVED",
        "IN_PROGRESS",
        "COMPLETED",
        "CANCELLED",
      ],
      default: "PENDING",
      index: true,
    },
    otp: String,
    cancellationReason: String,
    cancelledBy: {
      type: String,
      enum: ["USER", "PROVIDER", "SYSTEM"],
    },

    acceptedAt: Date,
    providerArrivedAt: Date,
    startedAt: Date,
    completedAt: Date,
    cancelledAt: Date,

    userRating: { type: Number, min: 1, max: 5 },
    userFeedback: String,
    providerRating: { type: Number, min: 1, max: 5 },
    providerFeedback: String,

    userNotes: String,
    providerNotes: String,

    beforeImages: [String],
    afterImages: [String],

    serviceStartPhotos: {
      selfie: { type: String, default: "" },
      devicePhoto: { type: String, default: "" },
      serialPhoto: { type: String, default: "" },
      otherPhoto: { type: String, default: "" },
    },
  },
  { timestamps: true },
);

// Indexes
ServiceBookingSchema.index({ userId: 1, status: 1, createdAt: -1 });
ServiceBookingSchema.index({ providerId: 1, status: 1, createdAt: -1 });
ServiceBookingSchema.index({ categoryId: 1, status: 1 });
ServiceBookingSchema.index({ preferredDate: 1, status: 1 });

export default mongoose.model<IServiceBooking>(
  "ServiceBooking",
  ServiceBookingSchema,
);
