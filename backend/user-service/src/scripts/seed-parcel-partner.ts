/**
 * Seed (or update) an APPROVED parcel-delivery partner you can log into the
 * driver app with.
 *
 * Login: open the driver app → enter the mobile number below → OTP = master OTP
 * (config.auth.masterOtp, default 123456). The driver is approved + serviceType
 * "parcel", so it lands straight on the Parcel partner home.
 *
 * Usage (from backend/user-service):
 *   npx ts-node src/scripts/seed-parcel-partner.ts [mobileNumber] [fullName]
 *   e.g.  npx ts-node src/scripts/seed-parcel-partner.ts 9000000077 "Parcel Partner"
 */

import mongoose from "mongoose";

import config from "../config";
import Driver from "../models/driver.model";

async function main(): Promise<void> {
  if (!config.database.url) throw new Error("DB_URL is not set");
  await mongoose.connect(config.database.url);
  console.log("Connected to MongoDB\n");

  const mobileNumber = process.argv[2] || "9000000077";
  const fullName = process.argv[3] || "Parcel Partner";
  const countryCode = "+91";

  if (!/^[6-9]\d{9}$/.test(mobileNumber)) {
    throw new Error(
      `Invalid mobileNumber "${mobileNumber}" — must be a 10-digit number starting 6-9.`,
    );
  }

  const fields = {
    fullName,
    email: `parcel.${mobileNumber}@kebu.test`,
    serviceType: "parcel" as const,
    status: "approved" as const,
    onboardingStep: 7, // past onboarding → goes to the parcel home
    isActive: true,
    isDeleted: false,
    isOnline: false,
  };

  let driver = await Driver.findOne({ mobileNumber, countryCode });
  if (driver) {
    Object.assign(driver, fields);
    await driver.save();
    console.log(`Updated existing driver ${driver._id}`);
  } else {
    driver = await Driver.create({ mobileNumber, countryCode, ...fields });
    console.log(`Created new driver ${driver._id}`);
  }

  const masterOtp = config.auth.masterOtp;
  console.log("\n✅ Parcel partner ready. Log in with:");
  console.log(`   Mobile : ${countryCode} ${mobileNumber}`);
  console.log(`   OTP    : ${masterOtp}  (master OTP)`);
  console.log(`   Name   : ${fullName}`);
  console.log(`   Status : approved | serviceType: parcel`);
  console.log(
    "\nOn login the app should route straight to the Parcel partner home.",
  );
}

main()
  .catch((err) => {
    console.error("seed failed:", err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
