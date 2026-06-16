import { Router } from "express";

import authRoutes from "./auth.routes";
import userRoutes from "./user.routes";
import walletRoutes from "./wallet.routes";
import driverAuthRoutes from "./driver-auth.routes";
import driverRoutes from "./driver.routes";
import bookingRoutes from "./booking.routes";
import deliveryRoutes from "./delivery.routes";
import householdRoutes from "./household.routes";
import serviceProviderRoutes from "./service-provider.routes";
import paymentRoutes from "./payment.routes";
import mapsRoutes from "./maps.routes";
import adminRoutes from "./admin.routes";
import customerFeaturesRoutes from "./customer-features.routes";
import settingsRoutes from "./settings.routes";
import realtimeRoutes from "./realtime.routes";

const router = Router();

// Customer App Routes
router.use("/auth", authRoutes);
router.use("/user", userRoutes);
router.use("/wallet", walletRoutes);
router.use("/booking", bookingRoutes);
router.use("/delivery", deliveryRoutes);
router.use("/services", householdRoutes);
router.use("/payment", paymentRoutes);
router.use("/maps", mapsRoutes);
router.use("/customer", customerFeaturesRoutes); // Offers, Subscription, Referral, etc.

// Driver App Routes
router.use("/driver", driverAuthRoutes);
router.use("/driver/app", driverRoutes);

// Service Provider (Household Vendor) App Routes
router.use("/provider", serviceProviderRoutes);

// Admin Dashboard Routes
router.use("/admin", adminRoutes);

// Realtime (notifications, chat, stats)
router.use("/realtime", realtimeRoutes);

// Public Settings (API keys for apps)
router.use("/settings", settingsRoutes);

export default router;
