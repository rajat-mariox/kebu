import { Document } from "mongoose";

export type Gender = "Male" | "Female" | "Other";
export type SocialProvider = "google" | "facebook" | "x";

export interface ISocialAccount {
  providerUserId: string;
  username?: string;
  email?: string;
  avatar?: string;
  linkedAt?: Date;
}

export interface IUser extends Document {
  fullName: string;
  email: string;
  profileImage: string;
  gender: Gender;
  dob: string;
  countryCode: string;
  mobileNumber: string;
  address?: string;
  city?: string;
  state?: string;
  pinCode?: string;
  isActive: boolean;
  isDeleted: boolean;
  notificationAllowed: boolean;
  token?: string | null;
  
  // FCM & Device Info
  fcmToken?: string | null;
  deviceType?: "android" | "ios" | null;
  deviceModel?: string | null;
  deviceId?: string | null;
  appVersion?: string | null;
  
  referralCode?: string | null;
  socialAccounts?: {
    google?: ISocialAccount | null;
    facebook?: ISocialAccount | null;
    x?: ISocialAccount | null;
  };
}
