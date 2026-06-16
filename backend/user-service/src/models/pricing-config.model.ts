import mongoose, { Schema, Types } from "mongoose";

// Surge pricing rules
export interface ISurgeConfig {
  _id?: Types.ObjectId;
  serviceType: "cab" | "delivery" | "household";
  name: string;
  multiplier: number; // e.g., 1.5x
  conditions: {
    triggerType: "demand" | "time" | "weather" | "event" | "manual";
    timeStart?: string; // "18:00"
    timeEnd?: string; // "22:00"
    daysOfWeek?: number[]; // 0=Sun, 6=Sat
    demandThreshold?: number; // ratio of requests to available drivers
    zoneId?: Types.ObjectId;
  };
  vehicleTypeIds?: Types.ObjectId[]; // if empty, applies to all
  maxMultiplier: number;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

const SurgeConfigSchema = new Schema<ISurgeConfig>(
  {
    serviceType: {
      type: String,
      enum: ["cab", "delivery", "household"],
      required: true,
    },
    name: { type: String, required: true, trim: true },
    multiplier: { type: Number, required: true, min: 1, max: 10 },
    conditions: {
      triggerType: {
        type: String,
        enum: ["demand", "time", "weather", "event", "manual"],
        required: true,
      },
      timeStart: String,
      timeEnd: String,
      daysOfWeek: [Number],
      demandThreshold: Number,
      zoneId: { type: Schema.Types.ObjectId, ref: "Zone" },
    },
    vehicleTypeIds: [{ type: Schema.Types.ObjectId, ref: "VehicleType" }],
    maxMultiplier: { type: Number, default: 3 },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

export const SurgeConfig = mongoose.model<ISurgeConfig>(
  "SurgeConfig",
  SurgeConfigSchema,
);

// Commission configuration
export interface ICommissionConfig {
  _id?: Types.ObjectId;
  serviceType: "cab" | "delivery" | "household";
  name: string;
  commissionType: "percentage" | "flat";
  value: number; // percentage (e.g., 20) or flat amount
  minCommission?: number;
  maxCommission?: number;
  vehicleTypeId?: Types.ObjectId;
  serviceCategoryId?: Types.ObjectId;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

const CommissionConfigSchema = new Schema<ICommissionConfig>(
  {
    serviceType: {
      type: String,
      enum: ["cab", "delivery", "household"],
      required: true,
    },
    name: { type: String, required: true, trim: true },
    commissionType: {
      type: String,
      enum: ["percentage", "flat"],
      required: true,
    },
    value: { type: Number, required: true },
    minCommission: Number,
    maxCommission: Number,
    vehicleTypeId: { type: Schema.Types.ObjectId, ref: "VehicleType" },
    serviceCategoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
    },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

CommissionConfigSchema.index({ serviceType: 1, isActive: 1 });

export const CommissionConfig = mongoose.model<ICommissionConfig>(
  "CommissionConfig",
  CommissionConfigSchema,
);

// Cancellation policy
export interface ICancellationPolicy {
  _id?: Types.ObjectId;
  serviceType: "cab" | "delivery" | "household";
  name: string;
  rules: {
    cancelledBy: "USER" | "DRIVER" | "PROVIDER" | "SYSTEM";
    beforeStatus: string; // cancel before this status
    chargeType: "none" | "percentage" | "flat";
    chargeValue: number;
    refundPercentage: number; // percentage of fare to refund
    penaltyToDriver?: number;
  }[];
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

const CancellationPolicySchema = new Schema<ICancellationPolicy>(
  {
    serviceType: {
      type: String,
      enum: ["cab", "delivery", "household"],
      required: true,
    },
    name: { type: String, required: true, trim: true },
    rules: [
      {
        cancelledBy: {
          type: String,
          enum: ["USER", "DRIVER", "PROVIDER", "SYSTEM"],
          required: true,
        },
        beforeStatus: { type: String, required: true },
        chargeType: {
          type: String,
          enum: ["none", "percentage", "flat"],
          default: "none",
        },
        chargeValue: { type: Number, default: 0 },
        refundPercentage: { type: Number, default: 100 },
        penaltyToDriver: Number,
      },
    ],
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

export const CancellationPolicy = mongoose.model<ICancellationPolicy>(
  "CancellationPolicy",
  CancellationPolicySchema,
);

// Delivery package types & pricing
export interface IDeliveryPackageType {
  _id?: Types.ObjectId;
  name: string; // "Document", "Small Parcel", "Large Parcel"
  description?: string;
  icon?: string;
  maxWeight: number; // kg
  maxDimensions?: { length: number; width: number; height: number }; // cm
  baseFare: number;
  perKmRate: number;
  perStopCharge: number; // extra charge per additional stop
  minimumFare: number;
  isActive: boolean;
  displayOrder: number;
  createdAt?: Date;
  updatedAt?: Date;
}

const DeliveryPackageTypeSchema = new Schema<IDeliveryPackageType>(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    icon: String,
    maxWeight: { type: Number, required: true },
    maxDimensions: {
      length: Number,
      width: Number,
      height: Number,
    },
    baseFare: { type: Number, required: true },
    perKmRate: { type: Number, required: true },
    perStopCharge: { type: Number, default: 0 },
    minimumFare: { type: Number, required: true },
    isActive: { type: Boolean, default: true },
    displayOrder: { type: Number, default: 0 },
  },
  { timestamps: true },
);

export const DeliveryPackageType = mongoose.model<IDeliveryPackageType>(
  "DeliveryPackageType",
  DeliveryPackageTypeSchema,
);

// Payout / Settlement tracking
export interface IPayout {
  _id?: Types.ObjectId;
  recipientType: "driver" | "provider";
  recipientId: Types.ObjectId;
  recipientName: string;
  serviceType: "cab" | "delivery" | "household";
  period: { start: Date; end: Date };
  totalEarnings: number;
  totalCommission: number;
  totalDeductions: number;
  netPayout: number;
  bookingCount: number;
  status: "pending" | "processing" | "completed" | "failed";
  transactionRef?: string;
  processedAt?: Date;
  processedBy?: Types.ObjectId;
  remarks?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

const PayoutSchema = new Schema<IPayout>(
  {
    recipientType: {
      type: String,
      enum: ["driver", "provider"],
      required: true,
    },
    recipientId: { type: Schema.Types.ObjectId, required: true },
    recipientName: { type: String, required: true },
    serviceType: {
      type: String,
      enum: ["cab", "delivery", "household"],
      required: true,
    },
    period: {
      start: { type: Date, required: true },
      end: { type: Date, required: true },
    },
    totalEarnings: { type: Number, required: true },
    totalCommission: { type: Number, required: true },
    totalDeductions: { type: Number, default: 0 },
    netPayout: { type: Number, required: true },
    bookingCount: { type: Number, required: true },
    status: {
      type: String,
      enum: ["pending", "processing", "completed", "failed"],
      default: "pending",
    },
    transactionRef: String,
    processedAt: Date,
    processedBy: { type: Schema.Types.ObjectId, ref: "Admin" },
    remarks: String,
  },
  { timestamps: true },
);

PayoutSchema.index({ recipientId: 1, status: 1 });
PayoutSchema.index({ serviceType: 1, status: 1 });
PayoutSchema.index({ createdAt: -1 });

export const Payout = mongoose.model<IPayout>("Payout", PayoutSchema);
