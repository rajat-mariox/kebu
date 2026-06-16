import { Types } from "mongoose";

export interface IVehicleType {
  _id?: Types.ObjectId;
  categoryId: Types.ObjectId;

  name: string;
  maxWeightKg: number;
  maxSeats?: number;
  description?: string;
  minimumFare?: number;

  baseFare: number;
  perKmRate: number;
  perMinuteRate: number;
  minDistanceKm: number;

  surgeMultiplier?: number;
  cancellationFee?: number;

  image?: string;
  isActive: boolean;

  createdAt?: Date;
  updatedAt?: Date;
}
