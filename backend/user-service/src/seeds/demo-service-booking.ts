/**
 * Create (or remove) a DEMO household service request so you can watch it land
 * in the partner app's "New Requests". The demo booking is tagged so it can be
 * cleanly removed afterwards — it does NOT touch any real bookings.
 *
 *   npm run demo:create   → inserts one PENDING, unassigned cleaning booking
 *   npm run demo:remove   → deletes the demo booking(s) again
 */

import dotenv from "dotenv";
import mongoose from "mongoose";
import ServiceBooking from "../models/service-booking.model";
import ServiceCategory from "../models/service-category.model";
import User from "../models/Users";

dotenv.config({ quiet: true } as any);

const MONGODB_URI = process.env.DB_URL || "mongodb://localhost:27017/kebo";
const DEMO_TAG = "__DEMO_REQUEST__"; // stored in userNotes for easy cleanup

const run = async () => {
  const remove = process.argv.includes("--remove");
  await mongoose.connect(MONGODB_URI);
  console.log("Connected to MongoDB");

  if (remove) {
    const res = await ServiceBooking.deleteMany({ userNotes: DEMO_TAG });
    console.log(`Removed ${res.deletedCount} demo booking(s).`);
    await mongoose.disconnect();
    return;
  }

  const cleaning = await ServiceCategory.findOne({ slug: "cleaning" });
  if (!cleaning) {
    console.error('No "cleaning" category. Run "npm run seed:household" first.');
    await mongoose.disconnect();
    process.exit(1);
  }

  const user = await User.findOne({}).select("_id fullName");
  if (!user) {
    console.error("No user found to attach the demo booking to.");
    await mongoose.disconnect();
    process.exit(1);
  }

  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);

  const booking = await ServiceBooking.create({
    userId: user._id,
    categoryId: cleaning._id,
    serviceType: "Everyday Cleaning",
    description: "Ac Repair & Gas Refill",
    preferredDate: tomorrow,
    preferredTimeSlot: "10:00 AM - 12:00 PM",
    estimatedDuration: 60,
    address: {
      fullAddress:
        "Tower 4, Assotech Business Cresterra, 714, Sector 135, Noida, Uttar Pradesh",
      landmark: "Sector 135, Noida",
      lat: 28.4949,
      lng: 77.54,
      city: "Noida",
      pincode: "201304",
    },
    estimatedCost: 239,
    finalCost: 239,
    discount: 0,
    paymentMethod: "CASH",
    paymentStatus: "PENDING",
    status: "PENDING", // unassigned → shows in /household/booking/available
    userNotes: DEMO_TAG,
  });

  console.log("Created DEMO booking:");
  console.log("  _id      :", booking._id.toString());
  console.log("  status   : PENDING (unassigned)");
  console.log("  amount   : ₹239  CASH");
  console.log("  forUser  :", (user as any).fullName || user._id.toString());
  console.log(
    "\nOpen the partner app (driver 'fggg', online) → it should appear in",
    '"New Requests" within ~20s. Remove later with: npm run demo:remove',
  );

  await mongoose.disconnect();
};

if (require.main === module) {
  run()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Demo booking failed:", err);
      process.exit(1);
    });
}

export default run;
