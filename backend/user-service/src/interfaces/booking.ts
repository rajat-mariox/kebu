import { Types } from "mongoose";

export type BookingStatus =
  | "SEARCHING"
  | "NO_DRIVERS"
  | "ASSIGNED"
  | "DRIVER_ARRIVED"
  | "PICKED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED";

export type PaymentMethod = "CASH" | "WALLET" | "CARD" | "UPI";
export type PaymentStatus = "PENDING" | "PAID" | "FAILED" | "REFUNDED";
export type CancelledBy = "USER" | "DRIVER" | "SYSTEM";

export interface IBooking {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;
  driverId?: Types.ObjectId;
  vehicleTypeId: Types.ObjectId;

  pickup: {
    address: string;
    lat: number;
    lng: number;
  };

  drop: {
    address: string;
    lat: number;
    lng: number;
  };

  distanceKm: number;
  durationMin: number;
  fare: number;
  surgeFare?: number;
  discount?: number;
  subscriptionDiscount?: number;
  subscriptionPlanName?: string;
  finalFare: number;

  status: BookingStatus;
  paymentMethod?: PaymentMethod;
  paymentStatus?: PaymentStatus;

  cancellationReason?: string;
  cancelledBy?: CancelledBy;

  rating?: number;
  feedback?: string;
  tip?: number;

  // Booking for others
  riderId?: Types.ObjectId;
  riderName?: string;
  riderPhone?: string;

  // Promo code
  promoCode?: string;
  promoDiscount?: number;

  scheduledAt?: Date;
  assignedAt?: Date;
  driverArrivedAt?: Date;
  pickedAt?: Date;
  completedAt?: Date;
  cancelledAt?: Date;

  estimatedArrivalTime?: number;
  otp?: string;

  // Track drivers notified for this booking
  notifiedDriverIds?: Types.ObjectId[];

  createdAt?: Date;
  updatedAt?: Date;
}
