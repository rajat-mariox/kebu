import mongoose, { Schema } from "mongoose";
import { IBooking } from "../interfaces/booking";

const BookingSchema = new Schema<IBooking>(
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
    pickup: {
      address: { type: String, required: true },
      lat: { type: Number, required: true, min: -90, max: 90 },
      lng: { type: Number, required: true, min: -180, max: 180 },
    },
    drop: {
      address: { type: String, required: true },
      lat: { type: Number, required: true, min: -90, max: 90 },
      lng: { type: Number, required: true, min: -180, max: 180 },
    },
    distanceKm: { type: Number, required: true },
    durationMin: { type: Number, required: true },
    fare: { type: Number, required: true },
    surgeFare: { type: Number, default: 0 },
    discount: { type: Number, default: 0 },
    subscriptionDiscount: { type: Number, default: 0 },
    subscriptionPlanName: { type: String },
    finalFare: { type: Number, required: true },
    status: {
      type: String,
      enum: [
        "SEARCHING",
        "NO_DRIVERS",
        "ASSIGNED",
        "DRIVER_ARRIVED",
        "PICKED",
        "IN_PROGRESS",
        "COMPLETED",
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
      index: true,
    },
    cancellationReason: String,
    cancelledBy: {
      type: String,
      enum: ["USER", "DRIVER", "SYSTEM"],
    },
    rating: {
      type: Number,
      min: 1,
      max: 5,
    },
    feedback: String,
    tip: { type: Number, default: 0 },

    // Booking for others
    riderId: { type: Schema.Types.ObjectId, ref: "Rider" },
    riderName: String,
    riderPhone: String,

    // Promo code
    promoCode: String,
    promoDiscount: { type: Number, default: 0 },

    scheduledAt: Date,
    assignedAt: Date,
    driverArrivedAt: Date,
    pickedAt: Date,
    completedAt: Date,
    cancelledAt: Date,
    estimatedArrivalTime: Number,
    otp: {
      type: String,
      length: 4,
    },
    
    // Track drivers notified for this booking
    notifiedDriverIds: [
      {
        type: Schema.Types.ObjectId,
        ref: "Driver",
      },
    ],
  },
  { timestamps: true },
);

// Compound indexes
BookingSchema.index({ userId: 1, status: 1, createdAt: -1 });
BookingSchema.index({ driverId: 1, status: 1, createdAt: -1 });
BookingSchema.index({ status: 1, createdAt: -1 });
BookingSchema.index({ paymentStatus: 1, status: 1 });

export default mongoose.model<IBooking>("Booking", BookingSchema);
