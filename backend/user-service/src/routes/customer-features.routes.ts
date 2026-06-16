import { Router } from "express";

import * as CustomerFeaturesController from "../controllers/customer-features.controller";
import * as ScratchCardController from "../controllers/scratch-card.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";

const customerFeaturesRouter = Router();

// ============ SCRATCH CARDS ============

customerFeaturesRouter.get(
  "/scratch-cards",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(ScratchCardController.getMyScratchCards),
  ResponseMiddleware,
);

customerFeaturesRouter.post(
  "/scratch-cards/:cardId/scratch",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(ScratchCardController.scratchCard),
  ResponseMiddleware,
);

// ============ OFFERS ============

/**
 * Get all offers
 */
customerFeaturesRouter.get(
  "/offers",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getOffers),
  ResponseMiddleware,
);

/**
 * Apply promo code
 */
customerFeaturesRouter.post(
  "/offers/apply",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.applyPromoCode),
  ResponseMiddleware,
);

// ============ SUBSCRIPTION (Kebu One Pass) ============

/**
 * Get subscription plans
 */
customerFeaturesRouter.get(
  "/subscription/plans",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getSubscriptionPlans),
  ResponseMiddleware,
);

/**
 * Get my subscription
 */
customerFeaturesRouter.get(
  "/subscription",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getMySubscription),
  ResponseMiddleware,
);

/**
 * Subscribe to plan
 */
customerFeaturesRouter.post(
  "/subscription",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.subscribeToPlan),
  ResponseMiddleware,
);

// ============ REFERRAL ============

/**
 * Get referral info
 */
customerFeaturesRouter.get(
  "/referral",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getReferralInfo),
  ResponseMiddleware,
);

/**
 * Apply referral code
 */
customerFeaturesRouter.post(
  "/referral/apply",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.applyReferralCode),
  ResponseMiddleware,
);

// ============ NOTIFICATIONS ============

/**
 * Get notifications
 */
customerFeaturesRouter.get(
  "/notifications",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getNotifications),
  ResponseMiddleware,
);

/**
 * Mark notification as read
 */
customerFeaturesRouter.put(
  "/notifications/:notificationId/read",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.markNotificationRead),
  ResponseMiddleware,
);

// ============ FAQ ============

/**
 * Get FAQs
 */
customerFeaturesRouter.get(
  "/faq",
  ErrorHandlerMiddleware(CustomerFeaturesController.getFAQs),
  ResponseMiddleware,
);

// ============ SUPPORT ============

/**
 * Create support ticket
 */
customerFeaturesRouter.post(
  "/support/tickets",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.createSupportTicket),
  ResponseMiddleware,
);

/**
 * Get support tickets
 */
customerFeaturesRouter.get(
  "/support/tickets",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getSupportTickets),
  ResponseMiddleware,
);

/**
 * Get ticket details
 */
customerFeaturesRouter.get(
  "/support/tickets/:ticketId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getTicketDetails),
  ResponseMiddleware,
);

/**
 * Add message to ticket
 */
customerFeaturesRouter.post(
  "/support/tickets/:ticketId/message",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.addTicketMessage),
  ResponseMiddleware,
);

// ============ PAYMENT METHODS ============

/**
 * Get payment methods
 */
customerFeaturesRouter.get(
  "/payment-methods",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getPaymentMethods),
  ResponseMiddleware,
);

/**
 * Add payment method
 */
customerFeaturesRouter.post(
  "/payment-methods",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.addPaymentMethod),
  ResponseMiddleware,
);

/**
 * Delete payment method
 */
customerFeaturesRouter.delete(
  "/payment-methods/:methodId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.deletePaymentMethod),
  ResponseMiddleware,
);

// ============ RIDERS (Book for Others) ============

/**
 * Get riders
 */
customerFeaturesRouter.get(
  "/riders",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.getRiders),
  ResponseMiddleware,
);

/**
 * Add rider
 */
customerFeaturesRouter.post(
  "/riders",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.addRider),
  ResponseMiddleware,
);

/**
 * Update rider
 */
customerFeaturesRouter.put(
  "/riders/:riderId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.updateRider),
  ResponseMiddleware,
);

/**
 * Delete rider
 */
customerFeaturesRouter.delete(
  "/riders/:riderId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.deleteRider),
  ResponseMiddleware,
);

// ============ TIP ============

/**
 * Add tip to booking
 */
customerFeaturesRouter.post(
  "/tip",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(CustomerFeaturesController.addTip),
  ResponseMiddleware,
);

export default customerFeaturesRouter;
