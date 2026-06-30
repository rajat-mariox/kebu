/**
 * Remove a seeded parcel-delivery partner (and its location doc).
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/remove-parcel-partner.ts [mobileNumber]
 *   e.g.  npx ts-node src/scripts/remove-parcel-partner.ts 9000000077
 */

import mongoose from "mongoose";

import config from "../config";
import Driver from "../models/driver.model";
import DriverLocation from "../models/driver-location.model";

async function main(): Promise<void> {
  if (!config.database.url) throw new Error("DB_URL is not set");
  await mongoose.connect(config.database.url);
  console.log("Connected to MongoDB\n");

  const mobileNumber = process.argv[2] || "9000000077";
  const countryCode = "+91";

  const driver = await Driver.findOne({ mobileNumber, countryCode });
  if (!driver) {
    console.log(`No driver found with mobileNumber=${mobileNumber}. Nothing to remove.`);
    return;
  }

  console.log(
    `Removing driver ${driver._id} (${driver.fullName} / ${driver.mobileNumber}, serviceType=${driver.serviceType}, status=${driver.status})`,
  );

  await DriverLocation.deleteOne({ driverId: driver._id });
  const res = await Driver.deleteOne({ _id: driver._id });

  console.log(`\n✅ Removed ${res.deletedCount} driver and its location doc.`);
}

main()
  .catch((err) => {
    console.error("remove failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
