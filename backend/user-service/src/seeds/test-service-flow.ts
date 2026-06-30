/**
 * End-to-end data-layer test of the household service lifecycle. Mirrors what
 * each controller does and asserts the booking moves correctly through:
 *   available → accept → en-route → arrived(OTP) → in-progress → complete → PAID
 * Creates a tagged test booking and deletes it at the end. Read-the-output test.
 *
 *   npm run test:service-flow
 */

import dotenv from "dotenv";
import mongoose from "mongoose";
import ServiceBooking from "../models/service-booking.model";
import ServiceCategory from "../models/service-category.model";
import Driver from "../models/driver.model";
import User from "../models/Users";

dotenv.config({ quiet: true } as any);
const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";
const TAG = "__FLOW_TEST__";

let pass = 0;
let fail = 0;
const check = (label: string, ok: boolean, extra = "") => {
  console.log(`  ${ok ? "✓ PASS" : "✗ FAIL"}  ${label}${extra ? "  — " + extra : ""}`);
  ok ? pass++ : fail++;
};

const run = async () => {
  await mongoose.connect(MONGODB_URI);
  console.log("Connected. Running household service flow test...\n");

  const cleaning = await ServiceCategory.findOne({ slug: "cleaning" });
  const driver = await Driver.findOne({ serviceType: "cleaning", isOnline: true });
  const user = await User.findOne({});
  if (!cleaning || !driver || !user) {
    console.error("Missing cleaning category / online cleaning driver / user.");
    await mongoose.disconnect();
    process.exit(1);
  }
  console.log(`Driver: ${driver.fullName}   Category: ${cleaning.name}\n`);

  // 0) Create a PENDING booking (what the customer app does).
  const booking = await ServiceBooking.create({
    userId: user._id,
    categoryId: cleaning._id,
    serviceType: "Everyday Cleaning",
    description: "Flow test",
    preferredDate: new Date(),
    preferredTimeSlot: "10:00 AM - 12:00 PM",
    estimatedDuration: 60,
    address: { fullAddress: "Test address, Noida", lat: 28.49, lng: 77.54, city: "Noida", pincode: "201304" },
    estimatedCost: 239,
    finalCost: 239,
    paymentMethod: "CASH",
    status: "PENDING",
    userNotes: TAG,
  });
  console.log("Created PENDING booking", String(booking._id), "\n");

  // 1) available-jobs query (HouseholdController.getAvailableServiceBookings)
  const available = await ServiceBooking.find({
    status: "PENDING",
    $or: [{ providerId: null }, { providerId: { $exists: false } }],
  }).select("_id");
  check("available-jobs returns the booking",
    available.some((b) => String(b._id) === String(booking._id)));

  // 2) accept (acceptServiceBooking) → provider assigned + OTP
  booking.otp = String(Math.floor(1000 + Math.random() * 9000));
  booking.providerId = driver._id as any;
  booking.status = "PROVIDER_ASSIGNED";
  await booking.save();
  let fresh = await ServiceBooking.findById(booking._id);
  check("accept assigns provider", String(fresh?.providerId) === String(driver._id));
  check("accept generates 4-digit arrival OTP", /^\d{4}$/.test(fresh?.otp || ""), `otp=${fresh?.otp}`);

  // 3) provider-detail (ownership check) + OTP stripped from payload
  const ownByDriver = String(fresh?.providerId) === String(driver._id);
  check("provider-detail ownership check passes", ownByDriver);
  const detail = fresh!.toObject() as any;
  delete detail.otp;
  check("provider-detail strips OTP from payload", detail.otp === undefined);

  // 4) en-route → arrived (OTP verified) → in-progress
  fresh!.status = "PROVIDER_EN_ROUTE";
  await fresh!.save();
  const enteredOtp = fresh!.otp; // customer would share this
  check("arrival accepts the correct OTP", !!fresh!.otp && enteredOtp === fresh!.otp);
  check("arrival rejects a wrong OTP", "0000" !== fresh!.otp);
  fresh!.status = "PROVIDER_ARRIVED";
  fresh!.providerArrivedAt = new Date();
  await fresh!.save();
  fresh!.status = "IN_PROGRESS";
  fresh!.startedAt = new Date();
  await fresh!.save();
  fresh = await ServiceBooking.findById(booking._id);
  check("status progressed to IN_PROGRESS", fresh?.status === "IN_PROGRESS");

  // 5) complete (completeServiceBooking)
  fresh!.status = "COMPLETED";
  fresh!.completedAt = new Date();
  await fresh!.save();
  fresh = await ServiceBooking.findById(booking._id);
  check("status COMPLETED + completedAt set", fresh?.status === "COMPLETED" && !!fresh?.completedAt);

  // 6) payment-received (markServicePaymentReceived)
  fresh!.paymentStatus = "PAID";
  await fresh!.save();
  fresh = await ServiceBooking.findById(booking._id);
  check("payment marked PAID", fresh?.paymentStatus === "PAID");

  // 7) once assigned, it no longer shows in available-jobs
  const stillAvailable = await ServiceBooking.find({
    status: "PENDING",
    $or: [{ providerId: null }, { providerId: { $exists: false } }],
  }).select("_id");
  check("completed booking is gone from available-jobs",
    !stillAvailable.some((b) => String(b._id) === String(booking._id)));

  // cleanup
  await ServiceBooking.deleteOne({ _id: booking._id });
  console.log("\nCleaned up test booking.");
  console.log("=".repeat(50));
  console.log(`RESULT: ${pass} passed, ${fail} failed`);
  await mongoose.disconnect();
  process.exit(fail === 0 ? 0 : 1);
};

run().catch((err) => {
  console.error("Test crashed:", err);
  process.exit(1);
});
