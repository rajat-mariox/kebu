import mongoose, { Schema, Types } from "mongoose";

export interface ISubscriptionPlan {
  _id?: Types.ObjectId;
  name: string; // "Monthly Pass", "Quarterly Pass", "Annual Pass"
  description: string;
  duration: number; // in days
  price: number;
  originalPrice?: number; // for showing discount

  // Benefits
  benefits: {
    priceLockGuarantee: boolean;
    zeroWaitGuarantee: boolean;
    unlimitedDeliveries: boolean;
    priorityRides: boolean;
    discountPercentage?: number;
    freeDeliveriesPerMonth?: number;
    prioritySupportAccess: boolean;
  };

  image?: string; // plan icon/image URL (uploaded from admin)
  tag?: string; // "BEST VALUE", "POPULAR"
  isTrialAvailable: boolean;
  trialDays: number;

  isActive: boolean;
  isDeleted: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

export interface IUserSubscription {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;
  planId: Types.ObjectId;

  startDate: Date;
  endDate: Date;

  paymentId?: string;
  amount: number;

  status: "ACTIVE" | "EXPIRED" | "CANCELLED";
  autoRenew: boolean;

  isTrial: boolean;

  // Usage counters for benefit consumption.
  // `deliveriesUsedThisCycle` resets at each 30-day window since startDate.
  // `currentCycleMonthIndex` tracks which window the counter belongs to so we
  // can detect rollover.
  deliveriesUsedThisCycle: number;
  currentCycleMonthIndex: number;

  createdAt?: Date;
  updatedAt?: Date;
}

const SubscriptionPlanSchema = new Schema<ISubscriptionPlan>(
  {
    name: { type: String, required: true },
    description: { type: String, required: true },
    duration: { type: Number, required: true },
    price: { type: Number, required: true },
    originalPrice: Number,

    benefits: {
      priceLockGuarantee: { type: Boolean, default: false },
      zeroWaitGuarantee: { type: Boolean, default: false },
      unlimitedDeliveries: { type: Boolean, default: false },
      priorityRides: { type: Boolean, default: false },
      discountPercentage: Number,
      freeDeliveriesPerMonth: Number,
      prioritySupportAccess: { type: Boolean, default: false },
    },

    image: String,
    tag: String,
    isTrialAvailable: { type: Boolean, default: false },
    trialDays: { type: Number, default: 0 },

    isActive: { type: Boolean, default: true },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true },
);

const UserSubscriptionSchema = new Schema<IUserSubscription>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    planId: {
      type: Schema.Types.ObjectId,
      ref: "SubscriptionPlan",
      required: true,
    },

    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },

    paymentId: String,
    amount: { type: Number, required: true },

    status: {
      type: String,
      enum: ["ACTIVE", "EXPIRED", "CANCELLED"],
      default: "ACTIVE",
      index: true,
    },
    autoRenew: { type: Boolean, default: false },

    isTrial: { type: Boolean, default: false },

    deliveriesUsedThisCycle: { type: Number, default: 0 },
    currentCycleMonthIndex: { type: Number, default: 0 },
  },
  { timestamps: true },
);

UserSubscriptionSchema.index({ userId: 1, status: 1 });
UserSubscriptionSchema.index({ endDate: 1, status: 1 });

export const SubscriptionPlan = mongoose.model<ISubscriptionPlan>(
  "SubscriptionPlan",
  SubscriptionPlanSchema,
);

export const UserSubscription = mongoose.model<IUserSubscription>(
  "UserSubscription",
  UserSubscriptionSchema,
);
