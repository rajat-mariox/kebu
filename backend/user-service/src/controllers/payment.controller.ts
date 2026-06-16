import { Request, Response, NextFunction } from "express";
import { Types } from "mongoose";
import crypto from "crypto";

import * as PaymentService from "../services/payment.service";
import * as WalletService from "../services/wallet.service";
import Booking from "../models/booking.model";
import Delivery from "../models/delivery.model";
import config from "../config";

/**
 * Create payment order
 */
export const createPaymentOrder = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("PaymentController => createPaymentOrder");

  const userId = (req as any).userId;
  const { amount, type, referenceId } = req.body;

  // type can be: WALLET_RECHARGE, BOOKING_PAYMENT, DELIVERY_PAYMENT, SERVICE_PAYMENT

  if (!amount || amount <= 0) {
    req.rCode = 0;
    req.msg = "payment_error";
    req.rData = { error: "Amount must be greater than 0" };
    return next();
  }

  try {
    console.log("Creating Razorpay order:", { amount, type, referenceId });

    const order = await PaymentService.createOrder({
      amount: Number(amount),
      receipt: `${type}_${Date.now()}`.substring(0, 40),
      notes: {
        userId: userId.toString(),
        type,
        referenceId: referenceId || "",
      },
    });

    console.log("Razorpay order created:", order.orderId);

    req.rData = {
      orderId: order.orderId,
      amount: order.amount,
      currency: order.currency,
      keyId: config.razorpay.keyId,
    };

    req.msg = "order_created";
    next();
  } catch (error: any) {
    console.error("Razorpay createOrder error:", error?.message || error);
    req.rCode = 0;
    req.msg = "payment_error";
    req.rData = { error: error?.message || "Unknown payment error" };
    next();
  }
};

/**
 * Verify payment
 */
export const verifyPayment = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("PaymentController => verifyPayment");

  const userId = (req as any).userId;
  const {
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature,
    type,
    referenceId,
    amount,
  } = req.body;

  try {
    const isValid = PaymentService.verifyPayment({
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
    });

    if (!isValid) {
      req.rCode = 0;
      req.msg = "payment_verification_failed";
      return next();
    }

    // Process based on payment type
    switch (type) {
      case "WALLET_RECHARGE":
        await WalletService.addToWallet(
          userId,
          amount,
          "Wallet Recharge",
          razorpay_payment_id,
        );
        break;

      case "BOOKING_PAYMENT":
        await Booking.findByIdAndUpdate(referenceId, {
          paymentStatus: "PAID",
          paymentMethod: "UPI",
        });
        break;

      case "DELIVERY_PAYMENT":
        await Delivery.findByIdAndUpdate(referenceId, {
          paymentStatus: "PAID",
          paymentMethod: "UPI",
        });
        break;

      case "SERVICE_PAYMENT":
        const ServiceBooking =
          require("../models/service-booking.model").default;
        await ServiceBooking.findByIdAndUpdate(referenceId, {
          paymentStatus: "PAID",
          paymentMethod: "UPI",
        });
        break;
    }

    req.rData = {
      verified: true,
      paymentId: razorpay_payment_id,
    };

    req.msg = "payment_verified";
    next();
  } catch (error: any) {
    req.rCode = 0;
    req.msg = "payment_verification_failed";
    req.rData = { error: error.message };
    next();
  }
};

/**
 * Get payment details
 */
export const getPaymentDetails = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("PaymentController => getPaymentDetails");

  const { paymentId } = req.params;

  try {
    const payment = await PaymentService.getPaymentDetails(paymentId);

    req.rData = { payment };
    req.msg = "success";
    next();
  } catch (error: any) {
    req.rCode = 0;
    req.msg = "payment_not_found";
    next();
  }
};

/**
 * Initiate refund
 */
export const initiateRefund = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("PaymentController => initiateRefund");

  const { paymentId, amount, reason, referenceId, type } = req.body;

  try {
    const refund = await PaymentService.initiateRefund(paymentId, amount, {
      reason,
      referenceId,
      type,
    });

    // Update payment status
    if (type === "BOOKING_PAYMENT") {
      await Booking.findByIdAndUpdate(referenceId, {
        paymentStatus: "REFUNDED",
      });
    } else if (type === "DELIVERY_PAYMENT") {
      await Delivery.findByIdAndUpdate(referenceId, {
        paymentStatus: "REFUNDED",
      });
    }

    req.rData = { refund };
    req.msg = "refund_initiated";
    next();
  } catch (error: any) {
    req.rCode = 0;
    req.msg = "refund_failed";
    req.rData = { error: error.message };
    next();
  }
};

/**
 * Create payment link
 */
export const createPaymentLink = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("PaymentController => createPaymentLink");

  const user = (req as any).user;
  const { amount, bookingId, description } = req.body;

  try {
    const paymentLink = await PaymentService.createPaymentLink({
      amount,
      customerName: user.fullName || "Customer",
      customerPhone: user.mobileNumber,
      customerEmail: user.email,
      description,
      bookingId,
    });

    req.rData = paymentLink;
    req.msg = "payment_link_created";
    next();
  } catch (error: any) {
    req.rCode = 0;
    req.msg = "payment_link_failed";
    req.rData = { error: error.message };
    next();
  }
};

/**
 * Payment callback (for payment links)
 */
export const paymentCallback = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  console.log("PaymentController => paymentCallback");

  const { razorpay_payment_link_id, razorpay_payment_id, razorpay_signature } =
    req.query;

  // Verify Razorpay signature
  if (razorpay_signature && razorpay_payment_id) {
    const expectedSignature = crypto
      .createHmac("sha256", config.razorpay.keySecret)
      .update(`${razorpay_payment_link_id}|${razorpay_payment_id}`)
      .digest("hex");

    if (expectedSignature === razorpay_signature) {
      console.log("Payment signature verified successfully");

      // Update payment status in database
      try {
        await PaymentService.updatePaymentStatus(
          razorpay_payment_id as string,
          "COMPLETED",
        );
      } catch (error) {
        console.error("Error updating payment status:", error);
      }
    } else {
      console.error("Payment signature verification failed");
    }
  }

  // Redirect to success page
  res.redirect(
    `${process.env.APP_URL}/payment/success?paymentId=${razorpay_payment_id}`,
  );
};
