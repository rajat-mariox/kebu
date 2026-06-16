/**
 * One-shot DB cleanup: clear `currentBookingId` on every driver whose
 * pointer references a booking that isn't currently active (CANCELLED,
 * COMPLETED, or simply gone). Run when the backend code that fixed the
 * silent-no-op `$set: { x: undefined }` bug isn't deployed yet but you
 * need stuck drivers to be findable by the customer right now.
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/free-stuck-drivers.ts
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

  const stuckDrivers = await Driver.find({ currentBookingId: { $ne: null } })
    .select({ _id: 1, fullName: 1, mobileNumber: 1, currentBookingId: 1, isOnline: 1 })
    .lean();

  if (stuckDrivers.length === 0) {
    console.log("No drivers with currentBookingId — nothing to do.");
    return;
  }

  console.log(`Found ${stuckDrivers.length} driver(s) with currentBookingId; checking each...`);

  const driverIdsToFree: mongoose.Types.ObjectId[] = [];
  for (const d of stuckDrivers) {
    const bookingId = d.currentBookingId;
    if (!bookingId) continue;

    const booking = await Booking.findById(bookingId)
      .select({ status: 1 })
      .lean();

    const status = booking?.status ?? "(no booking)";
    const stale = !booking || !ACTIVE_STATUSES.includes(booking.status as string);

    console.log(
      `  driver=${d._id} (${d.fullName ?? "?"} / ${d.mobileNumber ?? "?"}) ` +
        `online=${d.isOnline ?? false} bookingStatus=${status} -> ${stale ? "FREE" : "keep"}`,
    );

    if (stale) {
      driverIdsToFree.push(d._id);
    }
  }

  if (driverIdsToFree.length === 0) {
    console.log("All drivers point at currently-active bookings — nothing to free.");
    return;
  }

  // Use $unset (not $set: { x: undefined } — Mongoose silently drops that)
  // so the field is actually removed. The customer's nearby-drivers query
  // filters with `currentBookingId: null`, which matches missing fields.
  const result = await Driver.updateMany(
    { _id: { $in: driverIdsToFree } },
    { $unset: { currentBookingId: "" } },
  );

  console.log(
    `Cleared currentBookingId on ${result.modifiedCount} driver(s). ` +
      `(matched=${result.matchedCount})`,
  );
}

main()
  .catch((err) => {
    console.error("free-stuck-drivers failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
