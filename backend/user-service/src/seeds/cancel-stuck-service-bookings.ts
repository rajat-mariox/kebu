/**
 * Cancel "stuck" household service bookings so a leftover request from testing
 * no longer blocks a user (the "you already have an active booking" guard).
 *
 * Marks every non-terminal ServiceBooking (PENDING / ACCEPTED / PROVIDER_* /
 * IN_PROGRESS) as CANCELLED. Intended for dev/testing resets.
 *
 * Usage: npm run reset:service-bookings
 *   Optional: pass a user id / mobile is NOT supported here — it clears ALL
 *   active service bookings, which is what you want for a clean test run.
 */

import dotenv from "dotenv";
import mongoose from "mongoose";
import ServiceBooking from "../models/service-booking.model";

dotenv.config({ quiet: true } as any);

const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";

const ACTIVE_STATUSES = [
  "PENDING",
  "ACCEPTED",
  "PROVIDER_ASSIGNED",
  "PROVIDER_EN_ROUTE",
  "PROVIDER_ARRIVED",
  "IN_PROGRESS",
];

const cancelStuckServiceBookings = async () => {
  await mongoose.connect(MONGODB_URI);
  console.log("Connected to MongoDB");

  const result = await ServiceBooking.updateMany(
    { status: { $in: ACTIVE_STATUSES } },
    {
      $set: {
        status: "CANCELLED",
        cancelledBy: "SYSTEM",
        cancellationReason: "Test reset — cleared stuck booking",
        cancelledAt: new Date(),
      },
    },
  );

  console.log(
    `Cancelled ${result.modifiedCount} stuck service booking(s). Users can book again now.`,
  );
  await mongoose.disconnect();
};

if (require.main === module) {
  cancelStuckServiceBookings()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Reset failed:", err);
      process.exit(1);
    });
}

export default cancelStuckServiceBookings;
