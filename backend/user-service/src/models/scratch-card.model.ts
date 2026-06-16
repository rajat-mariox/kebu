import mongoose, { Schema, Types } from "mongoose";

export type ScratchCardStatus = "UNSCRATCHED" | "SCRATCHED" | "EXPIRED";
export type ScratchCardRewardType = "WALLET_CREDIT" | "DISCOUNT_COUPON" | "BETTER_LUCK";

export interface IScratchCard {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;
  title: string;
  description?: string;
  rewardType: ScratchCardRewardType;
  rewardValue: number; // rupees or percent
  couponCode?: string;
  status: ScratchCardStatus;
  expiresAt: Date;
  scratchedAt?: Date;
  sourceType?: string; // e.g. "ride_completed", "admin_gift", "campaign"
  sourceRef?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

const ScratchCardSchema = new Schema<IScratchCard>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    title: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    rewardType: {
      type: String,
      enum: ["WALLET_CREDIT", "DISCOUNT_COUPON", "BETTER_LUCK"],
      required: true,
    },
    rewardValue: { type: Number, default: 0 },
    couponCode: { type: String, uppercase: true, sparse: true },
    status: {
      type: String,
      enum: ["UNSCRATCHED", "SCRATCHED", "EXPIRED"],
      default: "UNSCRATCHED",
      index: true,
    },
    expiresAt: { type: Date, required: true },
    scratchedAt: Date,
    sourceType: String,
    sourceRef: { type: Schema.Types.ObjectId },
  },
  { timestamps: true },
);

ScratchCardSchema.index({ userId: 1, status: 1, expiresAt: 1 });

export default mongoose.model<IScratchCard>("ScratchCard", ScratchCardSchema);
