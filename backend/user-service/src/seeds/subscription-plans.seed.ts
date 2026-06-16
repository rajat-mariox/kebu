import mongoose from "mongoose";
import { SubscriptionPlan } from "../models/subscription.model";
import config from "../config";

const plans = [
  {
    name: "Monthly Pass",
    description:
      "1st month free trial. Get priority rides, zero wait guarantee, and unlimited deliveries every month.",
    duration: 30,
    price: 199,
    originalPrice: 299,
    benefits: {
      priceLockGuarantee: true,
      zeroWaitGuarantee: true,
      unlimitedDeliveries: true,
      priorityRides: true,
      discountPercentage: 10,
      freeDeliveriesPerMonth: 5,
      prioritySupportAccess: false,
    },
    tag: "POPULAR",
    isTrialAvailable: true,
    trialDays: 30,
    isActive: true,
    isDeleted: false,
  },
  {
    name: "Quarterly Pass",
    description:
      "Save more with 3-month plan. All monthly benefits plus priority support and higher discounts.",
    duration: 90,
    price: 499,
    originalPrice: 597,
    benefits: {
      priceLockGuarantee: true,
      zeroWaitGuarantee: true,
      unlimitedDeliveries: true,
      priorityRides: true,
      discountPercentage: 15,
      freeDeliveriesPerMonth: 10,
      prioritySupportAccess: true,
    },
    isTrialAvailable: false,
    trialDays: 0,
    isActive: true,
    isDeleted: false,
  },
  {
    name: "Annual Pass",
    description:
      "Best value plan. All benefits unlocked with maximum discounts and unlimited deliveries year-round.",
    duration: 365,
    price: 1499,
    originalPrice: 2388,
    benefits: {
      priceLockGuarantee: true,
      zeroWaitGuarantee: true,
      unlimitedDeliveries: true,
      priorityRides: true,
      discountPercentage: 20,
      freeDeliveriesPerMonth: 999,
      prioritySupportAccess: true,
    },
    tag: "BEST VALUE",
    isTrialAvailable: false,
    trialDays: 0,
    isActive: true,
    isDeleted: false,
  },
];

const seedSubscriptionPlans = async () => {
  try {
    await mongoose.connect(config.database.url);
    console.log("Connected to MongoDB");

    await SubscriptionPlan.deleteMany({});
    console.log("Cleared existing subscription plans");

    await SubscriptionPlan.insertMany(plans);
    console.log(`Seeded ${plans.length} subscription plans successfully`);

    console.log("\n✅ Subscription plans seed completed!");
    process.exit(0);
  } catch (error) {
    console.error("Error seeding subscription plans:", error);
    process.exit(1);
  }
};

seedSubscriptionPlans();
