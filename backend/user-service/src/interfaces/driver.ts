import { Types } from "mongoose";

export type DriverStatus =
  | "draft"
  | "documents_uploaded"
  | "vehicle_added"
  | "under_verification"
  | "approved"
  | "rejected"
  | "suspended";

export interface IDriver {
  _id?: Types.ObjectId;

  mobileNumber: string;
  countryCode: string;
  userId?: Types.ObjectId;

  fullName: string;
  profileImage?: string;
  email?: string;
  gender?: "Male" | "Female" | "Other";
  dob?: string;
  bloodGroup?: string;

  serviceType?: "cab" | "cleaning" | "parcel" | "";

  // For household vendors (serviceType === "cleaning"):
  // the ServiceCategory ids this vendor can service (plumbing, AC repair, deep cleaning, etc.)
  householdCategories?: Types.ObjectId[];

  // Household partner "Personal Details" onboarding (backend-driven form).
  totalExperience?: string;
  pastWorkExperience?: string;
  availability?: string;
  interestedInPaidLeads?: string;
  spokenLanguages?: string[];

  city: string;
  state: string;
  address?: string;
  apartment?: string;
  country?: string;
  zipCode?: string;
  emergencyContact?: string;

  // Bank Details
  bankName?: string;
  accountNumber?: string;
  ifscCode?: string;

  // Onboarding step tracking (0=not started, 1=basic, 2=licence, 3=documents, 4=address, 5=bank)
  onboardingStep?: number;

  preferredWorkHours?: string;

  status: DriverStatus;
  rejectionReason?: string;
  suspensionReason?: string;

  isActive: boolean;
  isOnline: boolean;
  isDeleted: boolean;
  deletedAt?: Date;

  currentBookingId?: Types.ObjectId;
  rating?: number;
  totalRides?: number;

  // Online/login-time tracking. `totalOnlineSeconds` is the accumulated time
  // the driver has spent online across sessions; `lastOnlineAt` is the start
  // of the current online session (null when offline).
  totalOnlineSeconds?: number;
  lastOnlineAt?: Date | null;

  // FCM & Device Info
  fcmToken?: string;
  deviceType?: "android" | "ios";
  deviceModel?: string;
  deviceId?: string;
  appVersion?: string;

  createdAt?: Date;
  updatedAt?: Date;
}
