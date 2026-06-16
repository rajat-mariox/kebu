/**
 * Make a test driver bookable for "cab" rides:
 *  - sets driver.serviceType = "cab"  (booking searches drivers with serviceType "cab")
 *  - ensures the driver has an active+online DriverVehicle of a cab vehicle type
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/fix-driver-cab.ts <mobileNumber>
 */

import mongoose from "mongoose";

import config from "../config";
import Driver from "../models/driver.model";
import DriverVehicle from "../models/driver-vehicle.model";
import VehicleType from "../models/vehicle-type.model";

async function main(): Promise<void> {
  if (!config.database.url) throw new Error("DB_URL is not set");
  await mongoose.connect(config.database.url);
  console.log("Connected to MongoDB\n");

  const mobile = process.argv[2] || "9000000001";

  const driver = await Driver.findOne({ mobileNumber: mobile });
  if (!driver) {
    console.log(`No driver with mobileNumber=${mobile}`);
    return;
  }
  console.log(`Driver: ${driver._id} (${driver.fullName} / ${driver.mobileNumber})`);
  console.log(`  current serviceType="${driver.serviceType}"`);

  // 1) serviceType -> cab
  if (driver.serviceType !== "cab") {
    driver.serviceType = "cab" as any;
    await driver.save();
    console.log('  -> serviceType set to "cab"');
  } else {
    console.log("  serviceType already cab");
  }

  // 2) Ensure a cab vehicle type exists & driver owns one (active+online)
  const vehicleTypes = await VehicleType.find({ isActive: true })
    .select({ _id: 1, name: 1 })
    .lean();
  console.log(
    `\nActive vehicle types: ${vehicleTypes.map((v) => `${v.name}(${v._id})`).join(", ") || "NONE"}`,
  );
  if (vehicleTypes.length === 0) {
    console.log("No vehicle types found — seed vehicle types first.");
    return;
  }
  const vt = vehicleTypes[0];

  const existing = await DriverVehicle.find({ driverId: driver._id }).lean();
  console.log(
    `\nDriver's vehicles: ${
      existing.map((v: any) => `type=${v.vehicleTypeId} active=${v.isActive} online=${v.isOnline}`).join(" | ") || "NONE"
    }`,
  );

  let dv = await DriverVehicle.findOne({ driverId: driver._id, vehicleTypeId: vt._id });
  if (!dv) {
    dv = await DriverVehicle.create({
      driverId: driver._id,
      vehicleTypeId: vt._id,
      registrationNumber: "TEST0001",
      isActive: true,
      isOnline: true,
    });
    console.log(`  -> Created vehicle ${dv._id} (type ${vt.name}) active+online`);
  } else {
    (dv as any).isActive = true;
    (dv as any).isOnline = true;
    await dv.save();
    console.log(`  -> Updated vehicle ${dv._id} (type ${vt.name}) to active+online`);
  }

  console.log("\n✅ Done. Driver should now match cab bookings (pickup within 5km of driver location).");
}

main()
  .catch((err) => {
    console.error("fix failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
