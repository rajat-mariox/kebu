import { Router } from "express";

import * as PaymentController from "../controllers/payment.controller";
import ErrorHandlerMiddleware from "../middlewares/error-handler.middleware";
import ResponseMiddleware from "../middlewares/response.middleware";
import AuthMiddleware from "../middlewares/auth.middleware";
import AdminAuthMiddleware from "../middlewares/admin-auth.middleware";

const paymentRouter = Router();

/**
 * Create payment order (for UPI, Cards)
 */
paymentRouter.post(
  "/order",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(PaymentController.createPaymentOrder),
  ResponseMiddleware,
);

/**
 * Verify payment
 */
paymentRouter.post(
  "/verify",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(PaymentController.verifyPayment),
  ResponseMiddleware,
);

/**
 * Get payment details
 */
paymentRouter.get(
  "/:paymentId",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(PaymentController.getPaymentDetails),
  ResponseMiddleware,
);

/**
 * Create payment link
 */
paymentRouter.post(
  "/link",
  AuthMiddleware().verifyUserToken,
  ErrorHandlerMiddleware(PaymentController.createPaymentLink),
  ResponseMiddleware,
);

/**
 * Initiate refund (admin only)
 */
paymentRouter.post(
  "/refund",
  AdminAuthMiddleware().verifyAdminToken,
  ErrorHandlerMiddleware(PaymentController.initiateRefund),
  ResponseMiddleware,
);

/**
 * Payment callback (for payment links)
 */
paymentRouter.get("/callback", PaymentController.paymentCallback);

export default paymentRouter;
