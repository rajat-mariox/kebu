import mongoose, { Schema, Types } from "mongoose";

/**
 * Admin-controlled pricing / metadata for Household pre-book options
 * (Single booking vs Multiple booking).
 *
 * One document per booking type. Customer app reads these to render the
 * "Single Booking" / "Multiple Booking" tiles on PreBookingForCleaning.
 */
export type BookingTypeKey = "SINGLE" | "MULTIPLE";

export interface IBookingTypeConfig {
  _id?: Types.ObjectId;
  bookingType: BookingTypeKey;
  serviceId?: Types.ObjectId; // If set, overrides the global config for that service. Null/absent = global default.
  title: string;
  description?: string;
  basePrice: number;
  discountedPrice?: number;
  displayOrder: number;
  isActive: boolean;
  updatedBy?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

const BookingTypeConfigSchema = new Schema<IBookingTypeConfig>(
  {
    bookingType: {
      type: String,
      enum: ["SINGLE", "MULTIPLE"],
      required: true,
      index: true,
    },
    serviceId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceDetails",
      index: true,
      default: null,
    },
    title: { type: String, required: true },
    description: String,
    basePrice: { type: Number, required: true, min: 0 },
    discountedPrice: { type: Number, min: 0 },
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    updatedBy: { type: Schema.Types.ObjectId, ref: "Admin" },
  },
  { timestamps: true },
);

// One config per (bookingType, serviceId) — serviceId=null is the global fallback.
BookingTypeConfigSchema.index(
  { bookingType: 1, serviceId: 1 },
  { unique: true },
);

export default mongoose.model<IBookingTypeConfig>(
  "BookingTypeConfig",
  BookingTypeConfigSchema,
);
