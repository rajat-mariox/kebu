/**
 * Remove the FAKE household partner-dashboard demo bookings that were created by
 * the old "tap to load sample data" banner (DriverController.seedHouseholdDemoData).
 *
 * Those bookings were attached to a fixed set of demo customers and a fixed demo
 * address, so they can be deleted cleanly without touching any real booking.
 *
 *   npm run demo:household:remove
 */

import dotenv from "dotenv";
import mongoose from "mongoose";
import ServiceBooking from "../models/service-booking.model";
import User from "../models/Users";

dotenv.config({ quiet: true } as any);

const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";

// Markers hard-coded by the old seedHouseholdDemoData() routine.
const DEMO_MOBILE_NUMBERS = [
  "9000000001",
  "9000000002",
  "9000000003",
  "9000000004",
];
const DEMO_ADDRESS = "3517 W. Gray St. Utica, Pennsylvania 57867";

const run = async () => {
  await mongoose.connect(MONGODB_URI);
  console.log("Connected to MongoDB");

  const demoUsers = await User.find({
    mobileNumber: { $in: DEMO_MOBILE_NUMBERS },
  }).select("_id");
  const demoUserIds = demoUsers.map((u) => u._id);

  // Only delete bookings that BOTH belong to a demo customer AND carry the demo
  // address — this guards against ever touching a real booking.
  const res = await ServiceBooking.deleteMany({
    userId: { $in: demoUserIds },
    "address.fullAddress": DEMO_ADDRESS,
  });
  console.log(`Removed ${res.deletedCount} fake demo booking(s).`);

  // Clean up the demo customer accounts too (they only existed for the seed).
  const userRes = await User.deleteMany({
    mobileNumber: { $in: DEMO_MOBILE_NUMBERS },
  });
  console.log(`Removed ${userRes.deletedCount} demo customer account(s).`);

  await mongoose.disconnect();
};

if (require.main === module) {
  run()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Demo cleanup failed:", err);
      process.exit(1);
    });
}

export default run;
