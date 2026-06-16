import mongoose, { Schema, Types } from "mongoose";

/**
 * Multiple Booking / Pre-booking for household services
 * Allows booking services for multiple days (date range)
 */
export interface IMultipleBooking {
  _id?: Types.ObjectId;
  userId: Types.ObjectId;
  categoryId: Types.ObjectId;
  serviceType: string;
  packageId?: Types.ObjectId;

  // Booking Type
  bookingType: "SINGLE" | "MULTIPLE";

  // For multiple bookings - date range
  startDate: Date;
  endDate?: Date; // For multiple bookings
  selectedDates: Date[]; // Specific dates selected

  // Duration and timing
  durationMinutes: number;
  timeSlot: string; // "12:00 Pm"
  timeSlotType: "MORNING" | "AFTERNOON" | "EVENING";

  // Address
  address: {
    fullAddress: string;
    landmark?: string;
    lat: number;
    lng: number;
    label?: string; // "Home", "Office"
  };

  // Pricing
  perSessionPrice: number;
  totalSessions: number;
  subtotal: number;
  taxes: number;
  discount: number;
  subscriptionDiscount?: number;
  subscriptionPlanName?: string;
  promoCode?: string;
  totalAmount: number;

  // Payment
  paymentMethod: "CASH" | "WALLET" | "UPI" | "CARD";
  paymentStatus: "PENDING" | "PARTIAL" | "COMPLETED";

  // Status
  status: "PENDING" | "CONFIRMED" | "IN_PROGRESS" | "COMPLETED" | "CANCELLED";

  // Subscription/Pack applied
  subscriptionId?: Types.ObjectId;
  starterPackApplied?: boolean;

  // Individual session bookings
  sessionBookings: Types.ObjectId[];

  createdAt?: Date;
  updatedAt?: Date;
}

const MultipleBookingSchema = new Schema<IMultipleBooking>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "Users",
      required: true,
      index: true,
    },
    categoryId: {
      type: Schema.Types.ObjectId,
      ref: "ServiceCategory",
      required: true,
      index: true,
    },
    serviceType: { type: String, required: true },
    packageId: {
      type: Schema.Types.ObjectId,
      ref: "ServicePackage",
    },

    bookingType: {
      type: String,
      enum: ["SINGLE", "MULTIPLE"],
      required: true,
    },

    startDate: { type: Date, required: true },
    endDate: Date,
    selectedDates: [{ type: Date }],

    durationMinutes: { type: Number, required: true },
    timeSlot: { type: String, required: true },
    timeSlotType: {
      type: String,
      enum: ["MORNING", "AFTERNOON", "EVENING"],
      required: true,
    },

    address: {
      fullAddress: { type: String, required: true },
      landmark: String,
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
      label: String,
    },

    perSessionPrice: { type: Number, required: true },
    totalSessions: { type: Number, required: true },
    subtotal: { type: Number, required: true },
    taxes: { type: Number, default: 0 },
    discount: { type: Number, default: 0 },
    subscriptionDiscount: { type: Number, default: 0 },
    subscriptionPlanName: { type: String },
    promoCode: String,
    totalAmount: { type: Number, required: true },

    paymentMethod: {
      type: String,
      enum: ["CASH", "WALLET", "UPI", "CARD"],
      default: "CASH",
    },
    paymentStatus: {
      type: String,
      enum: ["PENDING", "PARTIAL", "COMPLETED"],
      default: "PENDING",
    },

    status: {
      type: String,
      enum: ["PENDING", "CONFIRMED", "IN_PROGRESS", "COMPLETED", "CANCELLED"],
      default: "PENDING",
      index: true,
    },

    subscriptionId: {
      type: Schema.Types.ObjectId,
      ref: "UserSubscription",
    },
    starterPackApplied: { type: Boolean, default: false },

    sessionBookings: [
      {
        type: Schema.Types.ObjectId,
        ref: "ServiceBooking",
      },
    ],
  },
  { timestamps: true },
);

MultipleBookingSchema.index({ userId: 1, status: 1 });
MultipleBookingSchema.index({ startDate: 1, endDate: 1 });

export default mongoose.model<IMultipleBooking>(
  "MultipleBooking",
  MultipleBookingSchema,
);
