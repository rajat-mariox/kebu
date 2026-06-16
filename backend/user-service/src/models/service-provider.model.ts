import mongoose, { Schema, Types } from "mongoose";

export interface IServiceProvider {
  _id?: Types.ObjectId;
  fullName: string;
  email?: string;
  mobileNumber: string;
  countryCode: string;
  profileImage?: string;
  gender: "Male" | "Female" | "Other";
  dob?: string;

  // Address
  address?: string;
  city?: string;
  state?: string;
  pincode?: string;
  location?: {
    type: "Point";
    coordinates: [number, number]; // [lng, lat]
  };

  // Categories they serve
  serviceCategories: Types.ObjectId[];

  // Documents
  aadhaar?: {
    number: string;
    verified: boolean;
  };
  pan?: {
    number: string;
    verified: boolean;
  };

  // Status
  status: "pending" | "approved" | "rejected" | "suspended";
  rejectionReason?: string;

  // Ratings
  rating: number;
  totalRatings: number;
  totalJobs: number;
  totalBookings: number;

  // Pricing
  hourlyRate?: number;
  minimumCharge?: number;

  // Availability
  isOnline: boolean;
  isActive: boolean;
  isDeleted: boolean;

  // FCM
  fcmToken?: string;

  createdAt?: Date;
  updatedAt?: Date;
}

const ServiceProviderSchema = new Schema<IServiceProvider>(
  {
    fullName: { type: String, required: true, trim: true },
    email: { type: String, lowercase: true, trim: true },
    mobileNumber: {
      type: String,
      required: true,
      match: [/^[6-9]\d{9}$/, "Please enter a valid 10-digit mobile number"],
    },
    countryCode: { type: String, default: "+91" },
    profileImage: String,
    gender: {
      type: String,
      enum: ["Male", "Female", "Other"],
      default: "Male",
    },
    dob: String,

    address: String,
    city: String,
    state: String,
    pincode: String,
    location: {
      type: { type: String, enum: ["Point"], default: "Point" },
      coordinates: { type: [Number] },
    },

    serviceCategories: [
      {
        type: Schema.Types.ObjectId,
        ref: "ServiceCategory",
      },
    ],

    aadhaar: {
      number: String,
      verified: { type: Boolean, default: false },
    },
    pan: {
      number: String,
      verified: { type: Boolean, default: false },
    },

    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "suspended"],
      default: "pending",
      index: true,
    },
    rejectionReason: String,

    rating: { type: Number, default: 0, min: 0, max: 5 },
    totalRatings: { type: Number, default: 0 },
    totalJobs: { type: Number, default: 0 },
    totalBookings: { type: Number, default: 0 },

    hourlyRate: { type: Number, min: 0 },
    minimumCharge: { type: Number, min: 0 },

    isOnline: { type: Boolean, default: false, index: true },
    isActive: { type: Boolean, default: true, index: true },
    isDeleted: { type: Boolean, default: false, index: true },

    fcmToken: String,
  },
  { timestamps: true },
);

// Indexes
ServiceProviderSchema.index({ location: "2dsphere" });
ServiceProviderSchema.index({ serviceCategories: 1, isOnline: 1, status: 1 });
ServiceProviderSchema.index({ mobileNumber: 1, countryCode: 1 });

export default mongoose.model<IServiceProvider>(
  "ServiceProvider",
  ServiceProviderSchema,
);
