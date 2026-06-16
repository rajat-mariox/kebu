import mongoose from "mongoose";
import config from "../config";

// Import all models
import User from "./Users";
import UserAddress from "./UserAddress";
import Driver from "./driver.model";
import DriverKyc from "./driver-kyc.model";
import DriverLocation from "./driver-location.model";
import DriverVehicle from "./driver-vehicle.model";
import Vehicle from "./vehicle.model";
import VehicleCategory from "./vehicle-category.model";
import VehicleType from "./vehicle-type.model";
import Booking from "./booking.model";
import Wallet from "./wallet.model";
import WalletTransaction from "./wallet-transaction.model";
import RewardTransaction from "./reward-transaction.model";
import UserGST from "./user-gst.model";

mongoose.set("strictQuery", true);

export const connectDB = async (): Promise<void> => {
  try {
    await mongoose.connect(config.database.url);
    console.log("✅ Connected to MongoDB");

    // Self-heal: clear stale `currentBookingId` pointers left behind by
    // crashes, race conditions, or pre-fix cancellation paths. Without this,
    // affected drivers would never reappear in nearby-driver search.
    try {
      const { clearStaleDriverBookings } = await import(
        "../services/driver.service"
      );
      const cleared = await clearStaleDriverBookings();
      if (cleared > 0) {
        console.log(
          `🧹 Cleared stale currentBookingId on ${cleared} driver(s)`,
        );
      }
    } catch (err) {
      console.error("⚠️ clearStaleDriverBookings failed:", err);
    }
  } catch (error) {
    console.error("❌ Error connecting to MongoDB:", error);
    process.exit(1);
  }
};

// Connection listeners
mongoose.connection.on("error", (error) => {
  console.error("MongoDB connection error:", error);
});

mongoose.connection.on("disconnected", () => {
  console.warn("⚠️ MongoDB disconnected");
});

// Complete model registry
export const models = {
  User,
  UserAddress,
  Driver,
  DriverKyc,
  DriverLocation,
  DriverVehicle,
  Vehicle,
  VehicleCategory,
  VehicleType,
  Booking,
  Wallet,
  WalletTransaction,
  RewardTransaction,
  UserGST,
} as const;

export default connectDB;

export type ModelName = keyof typeof models;
