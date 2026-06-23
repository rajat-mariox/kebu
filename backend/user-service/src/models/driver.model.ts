import mongoose, { Schema } from "mongoose";
import { IDriver } from "../interfaces/driver";

const DriverSchema = new Schema<IDriver>(
  {
    mobileNumber: {
      type: String,
      required: true,
      match: [/^[6-9]\d{9}$/, "Please enter a valid 10-digit mobile number"],
    },

    countryCode: {
      type: String,
      default: "+91",
    },

    fullName: {
      type: String,
      // required: true,
      default: "",
      trim: true,
    },

    profileImage: {
      type: String,
      default: "",
    },

    bloodGroup: {
      type: String,
      // required: true,
      default: "",
      trim: true,
    },

    email: {
      type: String,
      default: "",
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, "Please enter a valid email address"],
    },

    gender: {
      type: String,
      default: "Male",
      enum: ["Male", "Female", "Other"],
    },

    dob: String,

    serviceType: {
      type: String,
      enum: ["cab", "cleaning", "parcel", ""],
      default: "",
    },

    householdCategories: {
      type: [{ type: Schema.Types.ObjectId, ref: "ServiceCategory" }],
      default: [],
      index: true,
    },

    // ── Household partner "Personal Details" onboarding (backend-driven) ──
    totalExperience: {
      type: String,
      default: "",
    },
    pastWorkExperience: {
      type: String,
      default: "",
    },
    availability: {
      type: String,
      default: "",
    },
    interestedInPaidLeads: {
      type: String,
      default: "",
    },
    spokenLanguages: {
      type: [String],
      default: [],
    },

    city: {
      type: String,
      default: "",
    },

    state: {
      type: String,
      default: "",
    },

    address: {
      type: String,
      default: "",
    },

    apartment: {
      type: String,
      default: "",
    },

    country: {
      type: String,
      default: "India",
    },

    zipCode: {
      type: String,
      default: "",
    },

    emergencyContact: {
      type: String,
      default: "",
    },

    // Bank Details
    bankName: {
      type: String,
      default: "",
    },

    accountNumber: {
      type: String,
      default: "",
    },

    ifscCode: {
      type: String,
      default: "",
    },

    onboardingStep: {
      type: Number,
      default: 0,
    },

    preferredWorkHours: {
      type: String,
      default: "",
    },

    status: {
      type: String,
      enum: [
        "draft",
        "documents_uploaded",
        "vehicle_added",
        "under_verification",
        "approved",
        "rejected",
        "suspended",
      ],
      default: "draft",
      index: true,
    },

    rejectionReason: String,
    suspensionReason: String,

    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    isOnline: {
      type: Boolean,
      default: false,
      index: true,
    },
    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
    deletedAt: Date,
    currentBookingId: {
      type: Schema.Types.ObjectId,
      ref: "Booking",
      default: null,
    },
    rating: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
    },
    totalRides: {
      type: Number,
      default: 0,
    },

    // Online/login-time tracking
    totalOnlineSeconds: {
      type: Number,
      default: 0,
    },
    lastOnlineAt: {
      type: Date,
      default: null,
    },

    // FCM & Device Info
    fcmToken: String,
    deviceType: {
      type: String,
      enum: ["android", "ios"],
    },
    deviceModel: String,
    deviceId: String,
    appVersion: String,
  },
  { timestamps: true }
);

// Compound indexes
DriverSchema.index({ isOnline: 1, status: 1, isActive: 1 });
DriverSchema.index({ mobileNumber: 1, countryCode: 1 });

export default mongoose.model<IDriver>("Driver", DriverSchema);
