import mongoose, { Schema, Types } from "mongoose";

/**
 * Service Package - Duration-based pricing for household services
 * (1 hr, 1.5 hr, 2 hr packages as shown in UI)
 */
export interface IServicePackage {
  _id?: Types.ObjectId;
  categoryId: Types.ObjectId;
  serviceId?: Types.ObjectId; // If set, this package is tied to a specific ServiceDetails leaf; otherwise it applies to the whole category (fallback).
  name: string;
  durationMinutes: number; // 60, 90, 120
  originalPrice: number;
  discountedPrice: number;
  discountPercentage?: number;
  description?: string;
  isPopular: boolean;
  isAvailable: boolean;
  displayOrder: number;
  createdAt?: Date;
  updatedAt?: Date;
}

const ServicePackageSchema = new Schema<IServicePackage>(
  {
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      required: true,
      index: true,
    },
    serviceId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceDetails",
      index: true,
    },
    name: { type: String, required: true }, // "1 hr", "1.5 hr", "2 hr"
    durationMinutes: { type: Number, required: true },
    originalPrice: { type: Number, required: true },
    discountedPrice: { type: Number, required: true },
    discountPercentage: Number,
    description: String,
    isPopular: { type: Boolean, default: false },
    isAvailable: { type: Boolean, default: true },
    displayOrder: { type: Number, default: 0 },
  },
  { timestamps: true },
);

export default mongoose.model<IServicePackage>(
  "ServicePackage",
  ServicePackageSchema,
);
