/**
 * Stop (cancel) in-progress parcel deliveries and free the assigned partner(s).
 *
 * Active = SEARCHING / ASSIGNED / PICKED_UP / IN_TRANSIT.
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/cancel-active-deliveries.ts            # cancel all active
 *   npx ts-node src/scripts/cancel-active-deliveries.ts <deliveryId>   # cancel one
 */

import mongoose from "mongoose";

import config from "../config";
import Delivery from "../models/delivery.model";
import Driver from "../models/driver.model";

const ACTIVE = ["SEARCHING", "ASSIGNED", "PICKED_UP", "IN_TRANSIT"];

async function main(): Promise<void> {
  if (!config.database.url) throw new Error("DB_URL is not set");
  await mongoose.connect(config.database.url);
  console.log("Connected to MongoDB\n");

  const deliveryId = process.argv[2];
  const filter: any = deliveryId
    ? { _id: deliveryId, status: { $in: ACTIVE } }
    : { status: { $in: ACTIVE } };

  const deliveries = await Delivery.find(filter)
    .select("_id status driverId")
    .lean();

  if (!deliveries.length) {
    console.log("No active deliveries found. Nothing to stop.");
    return;
  }

  console.log(`Found ${deliveries.length} active delivery(ies):`);
  for (const d of deliveries) {
    console.log(`  ${d._id}  status=${d.status}  driver=${d.driverId ?? "-"}`);
  }

  const driverIds = deliveries
    .map((d: any) => d.driverId)
    .filter(Boolean);

  const res = await Delivery.updateMany(filter, {
    $set: {
      status: "CANCELLED",
      cancelledAt: new Date(),
      cancelledBy: "SYSTEM",
      cancellationReason: "Manually stopped",
    },
  });
  console.log(`\nCancelled ${res.modifiedCount} delivery(ies).`);

  if (driverIds.length) {
    const dres = await Driver.updateMany(
      { _id: { $in: driverIds } },
      { $unset: { currentBookingId: "" } },
    );
    console.log(`Freed ${dres.modifiedCount} partner(s) (currentBookingId cleared).`);
  }

  console.log("\n✅ Done.");
}

main()
  .catch((err) => {
    console.error("cancel failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
