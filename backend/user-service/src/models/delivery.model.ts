import mongoose, { Schema, Types } from "mongoose";

export type DeliveryStatus =
  | "SEARCHING"
  | "ASSIGNED"
  | "PICKED_UP"
  | "IN_TRANSIT"
  | "DELIVERED"
  | "CANCELLED";

export type DeliveryType = "DOCUMENT" | "PARCEL" | "FOOD" | "GROCERY" | "OTHER";

export type DeliveryMode = "INSTANT" | "SCHEDULED";

export type ProofOfDeliveryType = "OTP" | "SIGNATURE" | "PHOTO";

export interface IDeliveryStop {
  address: string;
  lat: number;
  lng: number;
  contactName: string;
  contactPhone: string;
  instructions?: string;
  status: "PENDING" | "COMPLETED" | "SKIPPED";
  completedAt?: Date;
  proofImage?: string;
}

export interface IDelivery {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;
  driverId?: Types.ObjectId;
  vehicleTypeId: Types.ObjectId;

  deliveryType: DeliveryType;
  // INSTANT = courier picks up & delivers right away.
  // SCHEDULED = courier comes on the user-specified scheduledAt date/time.
  deliveryMode: DeliveryMode;
  // Optional helping hands requested on the Confirm Location screen ($5/hr
  // each; the exact labour charge is settled later, hence it is not folded
  // into the upfront fare).
  workers: number;
  packageDescription?: string;
  packageWeight?: number; // in kg
  packageSize?: "SMALL" | "MEDIUM" | "LARGE" | "EXTRA_LARGE";

  pickup: {
    address: string;
    lat: number;
    lng: number;
    contactName: string;
    contactPhone: string;
    instructions?: string;
  };

  drops: IDeliveryStop[];

  totalDistanceKm: number;
  totalDurationMin: number;
  fare: number;
  surgeFare: number;
  discount: number;
  subscriptionDiscount?: number;
  subscriptionPlanName?: string;
  freeDeliveryApplied?: boolean;
  finalFare: number;

  status: DeliveryStatus;
  paymentMethod: "CASH" | "WALLET" | "CARD" | "UPI";
  paymentStatus: "PENDING" | "PAID" | "FAILED" | "REFUNDED";

  proofOfDelivery: ProofOfDeliveryType;
  otp?: string;

  cancellationReason?: string;
  cancelledBy?: "USER" | "DRIVER" | "SYSTEM";

  rating?: number;
  feedback?: string;

  scheduledAt?: Date;
  pickedUpAt?: Date;
  deliveredAt?: Date;
  cancelledAt?: Date;

  createdAt?: Date;
  updatedAt?: Date;
}

const DeliveryStopSchema = new Schema<IDeliveryStop>({
  address: { type: String, required: true },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  contactName: { type: String, required: true },
  contactPhone: { type: String, required: true },
  instructions: String,
  status: {
    type: String,
    enum: ["PENDING", "COMPLETED", "SKIPPED"],
    default: "PENDING",
  },
  completedAt: Date,
  proofImage: String,
});

const DeliverySchema = new Schema<IDelivery>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    driverId: {
      type: Schema.Types.ObjectId,
      ref: "Driver",
      index: true,
    },
    vehicleTypeId: {
      type: Schema.Types.ObjectId,
      ref: "VehicleType",
      required: true,
    },
    deliveryType: {
      type: String,
      enum: ["DOCUMENT", "PARCEL", "FOOD", "GROCERY", "OTHER"],
      required: true,
    },
    deliveryMode: {
      type: String,
      enum: ["INSTANT", "SCHEDULED"],
      default: "INSTANT",
    },
    workers: { type: Number, default: 0, min: 0 },
    packageDescription: String,
    packageWeight: Number,
    packageSize: {
      type: String,
      enum: ["SMALL", "MEDIUM", "LARGE", "EXTRA_LARGE"],
    },
    pickup: {
      address: { type: String, required: true },
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
      contactName: { type: String, required: true },
      contactPhone: { type: String, required: true },
      instructions: String,
    },
    drops: [DeliveryStopSchema],
    totalDistanceKm: { type: Number, required: true },
    totalDurationMin: { type: Number, required: true },
    fare: { type: Number, required: true },
    surgeFare: { type: Number, default: 0 },
    discount: { type: Number, default: 0 },
    subscriptionDiscount: { type: Number, default: 0 },
    subscriptionPlanName: { type: String },
    freeDeliveryApplied: { type: Boolean, default: false },
    finalFare: { type: Number, required: true },
    status: {
      type: String,
      enum: [
        "SEARCHING",
        "ASSIGNED",
        "PICKED_UP",
        "IN_TRANSIT",
        "DELIVERED",
        "CANCELLED",
      ],
      default: "SEARCHING",
      index: true,
    },
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
    proofOfDelivery: {
      type: String,
      enum: ["OTP", "SIGNATURE", "PHOTO"],
      default: "OTP",
    },
    otp: String,
    cancellationReason: String,
    cancelledBy: {
      type: String,
      enum: ["USER", "DRIVER", "SYSTEM"],
    },
    rating: { type: Number, min: 1, max: 5 },
    feedback: String,
    scheduledAt: Date,
    pickedUpAt: Date,
    deliveredAt: Date,
    cancelledAt: Date,
  },
  { timestamps: true },
);

// Indexes
DeliverySchema.index({ userId: 1, status: 1, createdAt: -1 });
DeliverySchema.index({ driverId: 1, status: 1, createdAt: -1 });

export default mongoose.model<IDelivery>("Delivery", DeliverySchema);
