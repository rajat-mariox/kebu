import mongoose, { Schema, Types } from "mongoose";

export type OfferSection = "latest" | "limited" | "just_for_you";
export type OfferTargetService = "booking" | "cleaning" | "parcel" | "none";

export interface IOffer {
  _id?: Types.ObjectId;
  title: string;
  subtitle?: string;
  description: string;
  code?: string;
  type?: "PERCENTAGE" | "FLAT" | "CASHBACK";
  value?: number; // percentage or flat amount
  maxDiscount?: number; // max discount for percentage type
  minOrderValue?: number;

  // Applicability
  applicableOn: "ALL" | "CAB" | "DELIVERY" | "HOUSEHOLD" | "WALLET";
  vehicleTypes?: Types.ObjectId[]; // specific vehicle types
  categories?: Types.ObjectId[]; // specific service categories

  // Display grouping on customer home
  section: OfferSection; // "latest" | "limited" | "just_for_you"
  // Where tapping the banner should take the user
  targetService: OfferTargetService; // "booking" | "cleaning" | "parcel" | "none"
  targetCategory?: string; // optional sub-category identifier

  // Validity
  startDate: Date;
  endDate: Date;
  usageLimit?: number; // total usage limit
  perUserLimit: number; // per user usage limit
  usedCount: number;

  // Targeting
  isForNewUsers: boolean;
  isForAllUsers: boolean;
  targetUserIds?: Types.ObjectId[];

  // Display
  image?: string;
  bannerImage?: string;
  tag?: string; // "Trending", "New", "Limited"
  priority: number; // for sorting

  isActive: boolean;
  isDeleted: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}

const OfferSchema = new Schema<IOffer>(
  {
    title: { type: String, required: true },
    subtitle: { type: String },
    description: { type: String, required: true },
    code: {
      type: String,
      unique: true,
      sparse: true,
      uppercase: true,
    },
    type: {
      type: String,
      enum: ["PERCENTAGE", "FLAT", "CASHBACK"],
    },
    value: { type: Number, min: 0 },
    maxDiscount: { type: Number, min: 0 },
    minOrderValue: { type: Number, default: 0 },

    applicableOn: {
      type: String,
      enum: ["ALL", "CAB", "DELIVERY", "HOUSEHOLD", "WALLET"],
      default: "ALL",
    },
    vehicleTypes: [{ type: Schema.Types.ObjectId, ref: "VehicleType" }],
    categories: [{ type: Schema.Types.ObjectId, ref: "ServiceCategory" }],

    section: {
      type: String,
      enum: ["latest", "limited", "just_for_you"],
      default: "latest",
      index: true,
    },
    targetService: {
      type: String,
      enum: ["booking", "cleaning", "parcel", "none"],
      default: "none",
    },
    targetCategory: { type: String },

    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    usageLimit: Number,
    perUserLimit: { type: Number, default: 1 },
    usedCount: { type: Number, default: 0 },

    isForNewUsers: { type: Boolean, default: false },
    isForAllUsers: { type: Boolean, default: true },
    targetUserIds: [{ type: Schema.Types.ObjectId, ref: "User" }],

    image: String,
    bannerImage: String,
    tag: String,
    priority: { type: Number, default: 0 },

    isActive: { type: Boolean, default: true, index: true },
    isDeleted: { type: Boolean, default: false },
  },
  { timestamps: true },
);

OfferSchema.index({ isActive: 1, startDate: 1, endDate: 1 });
OfferSchema.index({ applicableOn: 1, isActive: 1 });
OfferSchema.index({ section: 1, isActive: 1, priority: -1 });

export default mongoose.model<IOffer>("Offer", OfferSchema);
