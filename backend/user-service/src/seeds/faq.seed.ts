import mongoose from "mongoose";
import { FAQ } from "../models/customer-features.model";
import config from "../config";

const faqs = [
  // ── GENERAL ──
  {
    question: "What is Kebu?",
    answer:
      "Kebu is a ride-hailing and household services platform. You can book rides, send parcels, and access home services like cleaning — all from one app.",
    category: "GENERAL",
    order: 1,
  },
  {
    question: "How do I create an account?",
    answer:
      "Download the Kebu app, enter your mobile number, verify it with an OTP, and you're all set! No email or password needed.",
    category: "GENERAL",
    order: 2,
  },
  {
    question: "Is Kebu available in my city?",
    answer:
      "Kebu is currently available in select cities in India. Open the app to check if services are active in your area.",
    category: "GENERAL",
    order: 3,
  },
  {
    question: "How do I update my profile?",
    answer:
      'Go to Accounts tab > tap your profile > edit your name, email, or profile picture and save.',
    category: "GENERAL",
    order: 4,
  },
  {
    question: "How do I delete my account?",
    answer:
      "Contact our support team via the Support Chat in the app. We will process your account deletion request within 48 hours.",
    category: "GENERAL",
    order: 5,
  },

  // ── BOOKING ──
  {
    question: "How do I book a ride?",
    answer:
      'Tap "Book a Ride" on the home screen, set your pickup and drop-off locations, choose a vehicle type, and tap "Book Now". A nearby driver will be assigned to you.',
    category: "BOOKING",
    order: 1,
  },
  {
    question: "Can I book a ride for someone else?",
    answer:
      "Yes! You can book a ride and share the trip details with the passenger. The pickup location can be set to any address.",
    category: "BOOKING",
    order: 2,
  },
  {
    question: "How do I schedule a ride in advance?",
    answer:
      "Scheduled rides are coming soon. Currently, you can only book rides for immediate pickup.",
    category: "BOOKING",
    order: 3,
  },
  {
    question: "What vehicle types are available?",
    answer:
      "We offer Bike, Rickshaw, Economy, Normal, and Comfort vehicles. Availability may vary by location and time.",
    category: "BOOKING",
    order: 4,
  },
  {
    question: "How long does it take to find a driver?",
    answer:
      "Usually under 5 minutes. If no driver is available within 5 km of your pickup location, you will be notified to try again later.",
    category: "BOOKING",
    order: 5,
  },
  {
    question: "Can I change my destination after booking?",
    answer:
      "Currently, the destination cannot be changed after booking. You can cancel and rebook with the new destination.",
    category: "BOOKING",
    order: 6,
  },

  // ── PAYMENT ──
  {
    question: "What payment methods are accepted?",
    answer:
      "We accept Cash and UPI payments. More payment options including cards and wallets are coming soon.",
    category: "PAYMENT",
    order: 1,
  },
  {
    question: "How is the fare calculated?",
    answer:
      "Fares are calculated based on distance, vehicle type, and current demand. You can see the fare estimate before confirming your booking.",
    category: "PAYMENT",
    order: 2,
  },
  {
    question: "Will I be charged if I cancel a ride?",
    answer:
      "Cancellation within 2 minutes is free. After that, a small cancellation fee may apply if a driver has already been assigned.",
    category: "PAYMENT",
    order: 3,
  },
  {
    question: "How do I get a receipt for my ride?",
    answer:
      "After your ride is completed, a receipt is available in the Activity tab. Tap on the completed ride to view and share the receipt.",
    category: "PAYMENT",
    order: 4,
  },
  {
    question: "How long do refunds take?",
    answer:
      "Refunds are processed within 5-7 business days to your original payment method. For UPI payments, it may take 24-48 hours.",
    category: "PAYMENT",
    order: 5,
  },

  // ── DRIVER ──
  {
    question: "How do I contact my driver?",
    answer:
      "Once a driver is assigned, you can call them directly from the live tracking screen using the call button.",
    category: "DRIVER",
    order: 1,
  },
  {
    question: "What if my driver cancels the ride?",
    answer:
      "If your driver cancels, we will automatically search for another nearby driver. You will not be charged any cancellation fee.",
    category: "DRIVER",
    order: 2,
  },
  {
    question: "How do I rate my driver?",
    answer:
      "After your ride is completed, you will be prompted to rate your driver on a 5-star scale. You can also add written feedback.",
    category: "DRIVER",
    order: 3,
  },
  {
    question: "My driver took a longer route. What should I do?",
    answer:
      "If you were overcharged due to a longer route, contact our support team with your booking ID. We will review and refund the difference.",
    category: "DRIVER",
    order: 4,
  },
  {
    question: "How do I become a Kebu driver?",
    answer:
      "Download the Kebu Driver app, register with your details, upload required documents (license, vehicle RC, insurance), and wait for approval.",
    category: "DRIVER",
    order: 5,
  },

  // ── SERVICE (Household) ──
  {
    question: "What household services does Kebu offer?",
    answer:
      "We offer everyday cleaning, weekly deep cleaning, laundry, dishwashing, bathroom cleaning, and cooking assistance.",
    category: "SERVICE",
    order: 1,
  },
  {
    question: "How do I book a household service?",
    answer:
      'Tap "Household Service" on the home screen, select a service category, choose a date and time slot, and confirm your booking.',
    category: "SERVICE",
    order: 2,
  },
  {
    question: "Can I reschedule a household service?",
    answer:
      "Yes, you can reschedule up to 4 hours before the scheduled time from the Activity tab at no extra cost.",
    category: "SERVICE",
    order: 3,
  },
  {
    question: "Are the service providers verified?",
    answer:
      "Yes, all service providers go through background verification, ID checks, and skill assessments before being approved on our platform.",
    category: "SERVICE",
    order: 4,
  },

  // ── CONTACT ──
  {
    question: "How can I contact Kebu support?",
    answer:
      'You can reach us through the Support Chat in the app (Contact Us > Support Chat), email at support@kebu.com, or call our 24x7 helpline.',
    category: "CONTACT",
    order: 1,
  },
  {
    question: "What are your support hours?",
    answer:
      "Our chatbot is available 24x7 for instant help. Live support agents are available from 8 AM to 10 PM IST, 7 days a week.",
    category: "CONTACT",
    order: 2,
  },
  {
    question: "How do I report a safety issue?",
    answer:
      "During a ride, tap the SOS button on the tracking screen for immediate emergency assistance. You can also report issues via Support Chat after the ride.",
    category: "CONTACT",
    order: 3,
  },
  {
    question: "Where can I share feedback about the app?",
    answer:
      "We love hearing from you! Go to Contact Us > Support Chat and share your feedback. You can also rate us on the Play Store or App Store.",
    category: "CONTACT",
    order: 4,
  },
];

const seedFAQs = async () => {
  try {
    await mongoose.connect(config.database.url);
    console.log("Connected to MongoDB");

    // Clear existing FAQs
    await FAQ.deleteMany({});
    console.log("Cleared existing FAQs");

    // Insert all FAQs
    await FAQ.insertMany(faqs.map((f) => ({ ...f, isActive: true })));
    console.log(`Seeded ${faqs.length} FAQs successfully`);

    console.log("\n✅ FAQ seed completed!");
    process.exit(0);
  } catch (error) {
    console.error("Error seeding FAQs:", error);
    process.exit(1);
  }
};

seedFAQs();
