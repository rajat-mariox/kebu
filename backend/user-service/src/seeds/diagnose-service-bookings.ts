/**
 * Read-only diagnostic: explains why a household service request may not be
 * reaching the partner app. Prints recent bookings + the state of cleaning
 * drivers (online / serviceType / categories). Makes NO changes.
 *
 * Usage: npm run diagnose:service
 */

import dotenv from "dotenv";
import mongoose from "mongoose";
import ServiceBooking from "../models/service-booking.model";
import Driver from "../models/driver.model";

dotenv.config({ quiet: true } as any);

const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";

const run = async () => {
  await mongoose.connect(MONGODB_URI);
  console.log("Connected to:", MONGODB_URI.replace(/\/\/.*@/, "//***@"));
  console.log("=".repeat(60));

  // --- Bookings ---
  const recent = await ServiceBooking.find({})
    .sort({ createdAt: -1 })
    .limit(8)
    .select("status providerId categoryId serviceType paymentMethod createdAt");
  console.log(`\nRECENT SERVICE BOOKINGS (latest ${recent.length}):`);
  if (recent.length === 0) console.log("  (none — no booking has been created)");
  for (const b of recent) {
    console.log(
      `  • ${b.status.padEnd(18)} provider=${b.providerId ? "ASSIGNED" : "—".padEnd(8)} ` +
        `cat=${b.categoryId ?? "—"} type=${(b as any).serviceType ?? "—"} ` +
        `pay=${(b as any).paymentMethod ?? "—"} at=${b.createdAt?.toISOString()}`,
    );
  }

  const pendingUnassigned = await ServiceBooking.countDocuments({
    status: "PENDING",
    $or: [{ providerId: null }, { providerId: { $exists: false } }],
  });
  console.log(
    `\nPENDING + unassigned (what /booking/available returns): ${pendingUnassigned}`,
  );

  // --- Drivers ---
  const cleaningDrivers = await Driver.find({ serviceType: "cleaning" })
    .limit(10)
    .select(
      "fullName mobileNumber isOnline status serviceType householdCategories currentBookingId isActive isDeleted",
    );
  console.log(`\nCLEANING DRIVERS (${cleaningDrivers.length}):`);
  if (cleaningDrivers.length === 0) {
    console.log(
      "  (NONE — no driver has serviceType='cleaning'. Accept will fail with",
      "'not_a_cleaning_provider'. Set the test driver's serviceType to 'cleaning'.)",
    );
  }
  for (const d of cleaningDrivers) {
    console.log(
      `  • ${(d.fullName || "—").padEnd(16)} online=${d.isOnline} status=${d.status} ` +
        `cats=${(d as any).householdCategories?.length ?? 0} ` +
        `busy=${(d as any).currentBookingId ? "YES" : "no"} ` +
        `active=${(d as any).isActive} deleted=${(d as any).isDeleted}`,
    );
  }

  // --- Verdict ---
  console.log("\n" + "=".repeat(60));
  console.log("LIKELY ISSUE:");
  if (pendingUnassigned === 0) {
    console.log(
      "  → No PENDING unassigned booking exists. The customer booking either",
      "wasn't created (validation/active-booking) or was already accepted/cancelled.",
    );
  } else if (cleaningDrivers.length === 0) {
    console.log(
      "  → There ARE pending requests, but NO cleaning driver exists. The",
      "available list needs the partner logged in; accept needs serviceType='cleaning'.",
    );
  } else {
    const usable = cleaningDrivers.filter(
      (d) => d.status === "approved" && (d as any).isActive && !(d as any).isDeleted,
    );
    console.log(
      `  → ${pendingUnassigned} pending request(s) + ${cleaningDrivers.length} cleaning driver(s)` +
        ` (${usable.length} approved/active). These SHOULD show in "New Requests".`,
    );
    console.log(
      "    If they don't: backend not restarted, driver app not rebuilt, or the",
      "app is hitting the wrong base URL. Check the driver app's api_config base URL.",
    );
  }

  await mongoose.disconnect();
};

if (require.main === module) {
  run()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Diagnose failed:", err);
      process.exit(1);
    });
}

export default run;
