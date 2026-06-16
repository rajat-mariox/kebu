import mongoose, { Schema, Types } from "mongoose";

/**
 * Service Time Slot - Available booking slots
 * Morning, Afternoon, Evening with specific times
 */
export interface ITimeSlotConfig {
  _id?: Types.ObjectId;
  categoryId?: Types.ObjectId; // If null, applies to all categories
  slotType: "MORNING" | "AFTERNOON" | "EVENING";
  slots: string[]; // ["12:00 Pm", "12:15 Pm", "12:30 Pm", ...]
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

const TimeSlotConfigSchema = new Schema<ITimeSlotConfig>(
  {
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      index: true,
    },
    slotType: {
      type: String,
      enum: ["MORNING", "AFTERNOON", "EVENING"],
      required: true,
    },
    slots: [{ type: String }],
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

/**
 * Blocked Slots - Slots that are already booked or unavailable
 */
export interface IBlockedSlot {
  _id?: Types.ObjectId;
  date: Date;
  categoryId: Types.ObjectId;
  providerId?: Types.ObjectId;
  blockedSlots: string[]; // List of blocked time slots
  reason?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

const BlockedSlotSchema = new Schema<IBlockedSlot>(
  {
    date: { type: Date, required: true, index: true },
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      required: true,
      index: true,
    },
    providerId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceProvider",
      index: true,
    },
    blockedSlots: [{ type: String }],
    reason: String,
  },
  { timestamps: true },
);

BlockedSlotSchema.index({ date: 1, categoryId: 1, providerId: 1 });

export const TimeSlotConfig = mongoose.model<ITimeSlotConfig>(
  "TimeSlotConfig",
  TimeSlotConfigSchema,
);

export const BlockedSlot = mongoose.model<IBlockedSlot>(
  "BlockedSlot",
  BlockedSlotSchema,
);
