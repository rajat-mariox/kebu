import mongoose, { Schema, Document, Types } from "mongoose";

export interface IHouseholdServiceHours extends Document {
  openTime: string;
  closeTime: string;
  daysActive: number[];
  timezone: string;
  isEnabled: boolean;
  closedMessage?: string;
  updatedBy?: Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const timeRegex = /^([01]\d|2[0-3]):[0-5]\d$/;

const householdServiceHoursSchema = new Schema<IHouseholdServiceHours>(
  {
    openTime: {
      type: String,
      required: true,
      match: timeRegex,
      default: "06:00",
    },
    closeTime: {
      type: String,
      required: true,
      match: timeRegex,
      default: "20:00",
    },
    daysActive: {
      type: [Number],
      default: [0, 1, 2, 3, 4, 5, 6],
      validate: {
        validator: (arr: number[]) => arr.every((d) => d >= 0 && d <= 6),
        message: "daysActive must contain values 0-6 (Sun-Sat)",
      },
    },
    timezone: {
      type: String,
      default: "Asia/Kolkata",
    },
    isEnabled: {
      type: Boolean,
      default: true,
    },
    closedMessage: {
      type: String,
      default: "We are currently closed. Please check back during our service hours.",
    },
    updatedBy: {
      type: Schema.Types.ObjectId,
      ref: "Admin",
    },
  },
  { timestamps: true },
);

const HouseholdServiceHours = mongoose.model<IHouseholdServiceHours>(
  "HouseholdServiceHours",
  householdServiceHoursSchema,
);

export default HouseholdServiceHours;
