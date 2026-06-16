import mongoose, { Schema } from "mongoose";
import { IUser } from "../interfaces/users";

const UserSchema: Schema<IUser> = new Schema(
  {
    fullName: {
      type: String,
      default: "",
      trim: true,
    },
    email: {
      type: String,
      default: "",
      trim: true,
      lowercase: true,
      match: [/^\S+@\S+\.\S+$/, "Please enter a valid email address"],
    },
    profileImage: {
      type: String,
      default: "",
      trim: true,
    },
    gender: {
      type: String,
      default: "Male",
      enum: ["Male", "Female", "Other"],
    },
    dob: {
      type: String,
      default: "",
    },
    countryCode: {
      type: String,
      required: [true, "Country code is required!"],
      default: "+91",
    },
    mobileNumber: {
      type: String,
      required: [true, "Mobile number is required!"],
      unique: true,
      match: [/^[6-9]\d{9}$/, "Please enter a valid 10-digit mobile number!"],
    },
    address: {
      type: String,
      default: "",
      trim: true,
    },
    city: {
      type: String,
      default: "",
      trim: true,
    },
    state: {
      type: String,
      default: "",
      trim: true,
    },
    pinCode: {
      type: String,
      default: "",
      trim: true,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    isDeleted: {
      type: Boolean,
      default: false,
      index: true,
    },
    notificationAllowed: {
      type: Boolean,
      default: true,
    },
    token: {
      type: String,
      default: null,
    },
    
    // FCM & Device Info
    fcmToken: {
      type: String,
      default: null,
    },
    deviceType: {
      type: String,
      enum: ["android", "ios"],
      default: null,
    },
    deviceModel: {
      type: String,
      default: null,
    },
    deviceId: {
      type: String,
      default: null,
    },
    appVersion: {
      type: String,
      default: null,
    },
    
    referralCode: {
      type: String,
      unique: true,
      sparse: true,
    },
    socialAccounts: {
      google: {
        providerUserId: { type: String, default: "" },
        username: { type: String, default: "" },
        email: { type: String, default: "" },
        avatar: { type: String, default: "" },
        linkedAt: { type: Date, default: null },
      },
      facebook: {
        providerUserId: { type: String, default: "" },
        username: { type: String, default: "" },
        email: { type: String, default: "" },
        avatar: { type: String, default: "" },
        linkedAt: { type: Date, default: null },
      },
      x: {
        providerUserId: { type: String, default: "" },
        username: { type: String, default: "" },
        email: { type: String, default: "" },
        avatar: { type: String, default: "" },
        linkedAt: { type: Date, default: null },
      },
    },
  },
  {
    timestamps: true,
  },
);

// Compound indexes
UserSchema.index({ mobileNumber: 1, isDeleted: 1 });

// Prevent overwrite error in dev / hot reload
const User = mongoose.models.User || mongoose.model<IUser>("User", UserSchema);

export default User;
