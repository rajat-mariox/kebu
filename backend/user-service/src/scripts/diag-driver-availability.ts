/**
 * Diagnose why a driver isn't appearing in the customer's nearby-drivers
 * search. Walks every filter `findNearbyDrivers` applies and prints the
 * driver's value for each, so the failing condition is obvious.
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/diag-driver-availability.ts <mobileNumber>
 *   npx ts-node src/scripts/diag-driver-availability.ts            # lists all online drivers
 */

import mongoose from "mongoose";

import config from "../config";
import Driver from "../models/driver.model";
import DriverLocation from "../models/driver-location.model";

const FRESHNESS_MS = 10 * 60 * 1000;

async function main(): Promise<void> {
  if (!config.database.url) {
    throw new Error("DB_URL is not set in environment");
  }

  await mongoose.connect(config.database.url);
  console.log("Connected to MongoDB\n");

  const mobile = process.argv[2];

  const query: Record<string, unknown> = mobile
    ? { mobileNumber: mobile }
    : { isOnline: true };

  const drivers = await Driver.find(query)
    .select({
      _id: 1,
      fullName: 1,
      mobileNumber: 1,
      isOnline: 1,
      status: 1,
      isActive: 1,
      isDeleted: 1,
      serviceType: 1,
      currentBookingId: 1,
    })
    .lean();

  if (drivers.length === 0) {
    console.log(
      mobile
        ? `No driver found with mobileNumber=${mobile}`
        : "No drivers with isOnline:true",
    );
    return;
  }

  const cutoff = new Date(Date.now() - FRESHNESS_MS);

  for (const d of drivers) {
    const loc = await DriverLocation.findOne({ driverId: d._id })
      .select({ latitude: 1, longitude: 1, updatedAt: 1, location: 1 })
      .lean();

    const locFresh = loc?.updatedAt && loc.updatedAt >= cutoff;

    const checks = {
      isOnline: d.isOnline === true,
      "status==approved": d.status === "approved",
      isActive: d.isActive !== false,
      "!isDeleted": d.isDeleted !== true,
      "currentBookingId==null": !d.currentBookingId,
      "location doc exists": !!loc,
      "location fresh (<10m)": !!locFresh,
      "location has coords":
        !!loc && (loc as any).location?.coordinates?.length === 2,
    };

    const failing = Object.entries(checks)
      .filter(([, ok]) => !ok)
      .map(([k]) => k);

    console.log(`Driver ${d._id} (${d.fullName ?? "?"} / ${d.mobileNumber ?? "?"})`);
    console.log(`  isOnline=${d.isOnline}  status=${d.status}  serviceType=${d.serviceType}  ` +
        `isActive=${d.isActive}  isDeleted=${d.isDeleted}`);
    console.log(`  currentBookingId=${d.currentBookingId ?? "null"}`);
    if (loc) {
      console.log(
        `  location: lat=${loc.latitude} lng=${loc.longitude} ` +
          `updatedAt=${loc.updatedAt?.toISOString()} ` +
          `(age=${loc.updatedAt ? Math.round((Date.now() - loc.updatedAt.getTime()) / 1000) + "s" : "?"}) ` +
          `coords=${(loc as any).location?.coordinates ?? "missing"}`,
      );
    } else {
      console.log("  location: NO DriverLocation doc");
    }

    if (failing.length === 0) {
      console.log("  ✅ Should appear in nearby-drivers search.");
    } else {
      console.log(`  ❌ Filtered out by: ${failing.join(", ")}`);
    }
    console.log("");
  }
}

main()
  .catch((err) => {
    console.error("diag failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
