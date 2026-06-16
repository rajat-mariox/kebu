import mongoose, { Schema } from "mongoose";
import { IVehicleType } from "../interfaces/vehicle-type";

const VehicleTypeSchema = new Schema<IVehicleType>(
  {
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "VehicleCategory",
      required: true,
      index: true,
    },
    name: { type: String, required: true },
    maxWeightKg: { type: Number, required: true },
    maxSeats: { type: Number, default: 4, min: 1 },
    description: { type: String },
    minimumFare: { type: Number, default: 0, min: 0 },
    baseFare: { type: Number, required: true, min: 0 },
    perKmRate: { type: Number, required: true, min: 0 },
    perMinuteRate: { type: Number, required: true, min: 0 },
    minDistanceKm: { type: Number, default: 1, min: 0 },
    surgeMultiplier: { type: Number, default: 1, min: 1 },
    cancellationFee: { type: Number, default: 0, min: 0 },
    image: { type: String },
    isActive: { type: Boolean, default: true, index: true },
  },
  { timestamps: true }
);

VehicleTypeSchema.index({ categoryId: 1, isActive: 1 });

export default mongoose.model<IVehicleType>("VehicleType", VehicleTypeSchema);
