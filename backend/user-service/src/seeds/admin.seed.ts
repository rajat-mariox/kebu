import mongoose from "mongoose";
import Admin from "../models/admin.model";
import Role from "../models/role.model";
import CmsPage from "../models/cms.model";
import helpers from "../utils/helpers";
import config from "../config";

const seedAdminData = async () => {
  try {
    // Connect to database
    await mongoose.connect(config.database.url);
    console.log("Connected to MongoDB");

    // Create default roles
    const roles = [
      {
        name: "Super Admin",
        description: "Full access to all features",
        permissions: [
          "dashboard:view",
          "users:view",
          "users:create",
          "users:edit",
          "users:delete",
          "drivers:view",
          "drivers:create",
          "drivers:edit",
          "drivers:delete",
          "drivers:approve",
          "bookings:view",
          "bookings:edit",
          "bookings:cancel",
          "household:view",
          "household:create",
          "household:edit",
          "household:delete",
          "categories:view",
          "categories:create",
          "categories:edit",
          "categories:delete",
          "service-bookings:view",
          "service-bookings:edit",
          "service-bookings:cancel",
          "providers:view",
          "providers:create",
          "providers:edit",
          "providers:delete",
          "providers:approve",
          "cms:view",
          "cms:create",
          "cms:edit",
          "cms:delete",
          "admins:view",
          "admins:create",
          "admins:edit",
          "admins:delete",
          "roles:view",
          "roles:create",
          "roles:edit",
          "roles:delete",
          "settings:view",
          "settings:edit",
        ],
        isSystem: true,
        isActive: true,
      },
      {
        name: "Admin",
        description: "Access to manage users, drivers, and bookings",
        permissions: [
          "dashboard:view",
          "users:view",
          "users:edit",
          "drivers:view",
          "drivers:edit",
          "drivers:approve",
          "bookings:view",
          "bookings:edit",
          "household:view",
          "household:edit",
          "categories:view",
          "service-bookings:view",
          "service-bookings:edit",
          "providers:view",
          "providers:approve",
          "cms:view",
          "cms:edit",
        ],
        isSystem: true,
        isActive: true,
      },
      {
        name: "Support",
        description: "View-only access for customer support",
        permissions: [
          "dashboard:view",
          "users:view",
          "drivers:view",
          "bookings:view",
          "service-bookings:view",
          "providers:view",
        ],
        isSystem: true,
        isActive: true,
      },
      {
        name: "Finance",
        description: "Access to financial reports and transactions",
        permissions: [
          "dashboard:view",
          "bookings:view",
          "service-bookings:view",
        ],
        isSystem: true,
        isActive: true,
      },
    ];

    for (const roleData of roles) {
      await Role.findOneAndUpdate({ name: roleData.name }, roleData, {
        upsert: true,
        new: true,
      });
      console.log(`Role "${roleData.name}" created/updated`);
    }

    // Get Super Admin role
    const superAdminRole = await Role.findOne({ name: "Super Admin" });

    // Create default super admin user
    const existingAdmin = await Admin.findOne({ email: "admin@kebu.com" });

    if (!existingAdmin) {
      const hashedPassword = await helpers().hashPassword("Admin@123");

      await Admin.create({
        name: "Super Admin",
        email: "admin@kebu.com",
        password: hashedPassword,
        mobileNumber: "+919999999999",
        role: "super_admin",
        roleId: superAdminRole?._id,
        permissions: superAdminRole?.permissions || [],
        isActive: true,
      });

      console.log("Default super admin created:");
      console.log("Email: admin@kebu.com");
      console.log("Password: Admin@123");
    } else {
      console.log("Super admin already exists");
    }

    // Create default CMS pages
    const cmsPages = [
      {
        slug: "terms-and-conditions",
        title: "Terms & Conditions",
        content: `<h1>Terms and Conditions</h1>
<p>Welcome to Movezy. These terms and conditions outline the rules and regulations for the use of our services.</p>
<h2>1. Acceptance of Terms</h2>
<p>By accessing and using Movezy services, you accept and agree to be bound by these terms.</p>
<h2>2. Use of Service</h2>
<p>Our services are provided for personal, non-commercial use only.</p>
<h2>3. User Responsibilities</h2>
<p>You are responsible for maintaining the confidentiality of your account information.</p>`,
        metaTitle: "Terms & Conditions - Movezy",
        metaDescription:
          "Read our terms and conditions for using Movezy services.",
      },
      {
        slug: "privacy-policy",
        title: "Privacy Policy",
        content: `<h1>Privacy Policy</h1>
<p>Your privacy is important to us. This policy explains how we collect, use, and protect your information.</p>
<h2>1. Information Collection</h2>
<p>We collect information you provide directly to us, such as when you create an account.</p>
<h2>2. Use of Information</h2>
<p>We use the information we collect to provide and improve our services.</p>
<h2>3. Data Security</h2>
<p>We implement appropriate security measures to protect your personal information.</p>`,
        metaTitle: "Privacy Policy - Movezy",
        metaDescription: "Learn how Movezy protects your privacy and data.",
      },
      {
        slug: "about-us",
        title: "About Us",
        content: `<h1>About Movezy</h1>
<p>Movezy is a leading transportation and logistics platform designed to make your life easier.</p>
<h2>Our Mission</h2>
<p>To provide safe, reliable, and affordable transportation services to everyone.</p>
<h2>Our Vision</h2>
<p>To become the most trusted mobility platform in the region.</p>`,
        metaTitle: "About Us - Movezy",
        metaDescription:
          "Learn about Movezy and our mission to transform transportation.",
      },
      {
        slug: "contact-us",
        title: "Contact Us",
        content: `<h1>Contact Us</h1>
<p>We're here to help! Reach out to us through any of the following channels:</p>
<h2>Customer Support</h2>
<p>Email: support@movezy.com</p>
<p>Phone: +91 1800 123 4567</p>
<h2>Business Inquiries</h2>
<p>Email: business@movezy.com</p>`,
        metaTitle: "Contact Us - Movezy",
        metaDescription:
          "Get in touch with Movezy customer support and business team.",
      },
      {
        slug: "faq",
        title: "Frequently Asked Questions",
        content: `<h1>Frequently Asked Questions</h1>
<h2>How do I book a ride?</h2>
<p>Open the Movezy app, enter your destination, select your vehicle type, and confirm your booking.</p>
<h2>How do I become a driver?</h2>
<p>Download the Movezy Driver app and complete the registration process with required documents.</p>
<h2>What payment methods are accepted?</h2>
<p>We accept cash, credit/debit cards, UPI, and wallet payments.</p>`,
        metaTitle: "FAQ - Movezy",
        metaDescription:
          "Find answers to frequently asked questions about Movezy.",
      },
      {
        slug: "refund-policy",
        title: "Refund Policy",
        content: `<h1>Refund Policy</h1>
<p>We want you to be satisfied with our services. Here's our refund policy:</p>
<h2>Eligibility</h2>
<p>Refunds are available for cancelled bookings made before the driver accepts the ride.</p>
<h2>Processing Time</h2>
<p>Refunds are typically processed within 5-7 business days.</p>`,
        metaTitle: "Refund Policy - Movezy",
        metaDescription: "Understand our refund policy for Movezy services.",
      },
      {
        slug: "cancellation-policy",
        title: "Cancellation Policy",
        content: `<h1>Cancellation Policy</h1>
<p>You can cancel a booking at any time, but fees may apply.</p>
<h2>Free Cancellation</h2>
<p>Cancel within 2 minutes of booking for a full refund.</p>
<h2>Cancellation Fee</h2>
<p>After 2 minutes, a cancellation fee may be charged based on distance and time.</p>`,
        metaTitle: "Cancellation Policy - Movezy",
        metaDescription: "Learn about Movezy cancellation policy and fees.",
      },
    ];

    for (const pageData of cmsPages) {
      await CmsPage.findOneAndUpdate({ slug: pageData.slug }, pageData, {
        upsert: true,
        new: true,
      });
      console.log(`CMS page "${pageData.title}" created/updated`);
    }

    console.log("\n✅ Seed completed successfully!");
    process.exit(0);
  } catch (error) {
    console.error("Error seeding data:", error);
    process.exit(1);
  }
};

seedAdminData();
