/**
 * One-shot DB cleanup: release EVERY driver from their current booking,
 * regardless of booking status. Clears `currentBookingId` (via $unset so
 * Mongoose actually removes the field) and cancels any still-active
 * bookings those drivers were attached to, so the system lands in a
 * clean "no one is on a ride" state.
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/release-all-drivers.ts
 */

import mongoose from "mongoose";

import config from "../config";
import Driver from "../models/driver.model";
import Booking from "../models/booking.model";

const ACTIVE_STATUSES = [
  "ASSIGNED",
  "DRIVER_ARRIVED",
  "PICKED",
  "IN_PROGRESS",
];

async function main(): Promise<void> {
  if (!config.database.url) {
    throw new Error("DB_URL is not set in environment");
  }

  await mongoose.connect(config.database.url);
  console.log("Connected to MongoDB");

  const drivers = await Driver.find({ currentBookingId: { $ne: null } })
    .select({ _id: 1, fullName: 1, mobileNumber: 1, currentBookingId: 1, isOnline: 1 })
    .lean();

  if (drivers.length === 0) {
    console.log("No drivers with currentBookingId — nothing to do.");
    return;
  }

  console.log(`Found ${drivers.length} driver(s) attached to a booking. Releasing all...`);

  const bookingIdsToCancel: mongoose.Types.ObjectId[] = [];
  for (const d of drivers) {
    const bookingId = d.currentBookingId;
    if (!bookingId) continue;

    const booking = await Booking.findById(bookingId)
      .select({ status: 1 })
      .lean();

    const status = booking?.status ?? "(no booking)";
    console.log(
      `  driver=${d._id} (${d.fullName ?? "?"} / ${d.mobileNumber ?? "?"}) ` +
        `online=${d.isOnline ?? false} bookingStatus=${status}`,
    );

    if (booking && ACTIVE_STATUSES.includes(booking.status as string)) {
      bookingIdsToCancel.push(booking._id);
    }
  }

  const driverIds = drivers.map((d) => d._id);
  const driverResult = await Driver.updateMany(
    { _id: { $in: driverIds } },
    { $unset: { currentBookingId: "" } },
  );
  console.log(
    `Cleared currentBookingId on ${driverResult.modifiedCount}/${driverResult.matchedCount} driver(s).`,
  );

  if (bookingIdsToCancel.length > 0) {
    const bookingResult = await Booking.updateMany(
      { _id: { $in: bookingIdsToCancel } },
      {
        $set: {
          status: "CANCELLED",
          cancelledBy: "ADMIN",
          cancelReason: "Admin-released via release-all-drivers script",
          cancelledAt: new Date(),
        },
      },
    );
    console.log(
      `Cancelled ${bookingResult.modifiedCount}/${bookingResult.matchedCount} active booking(s).`,
    );
  } else {
    console.log("No active bookings needed cancellation.");
  }
}

main()
  .catch((err) => {
    console.error("release-all-drivers failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
