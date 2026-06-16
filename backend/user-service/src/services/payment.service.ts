import Razorpay from "razorpay";
import crypto from "crypto";
import config from "../config";
import { Types } from "mongoose";

// Initialize Razorpay instance
const razorpay = config.razorpay.keyId
  ? new Razorpay({
      key_id: config.razorpay.keyId,
      key_secret: config.razorpay.keySecret,
    })
  : null;

export interface CreateOrderParams {
  amount: number; // Amount in rupees
  currency?: string;
  receipt?: string;
  notes?: Record<string, string>;
}

export interface VerifyPaymentParams {
  razorpay_order_id: string;
  razorpay_payment_id: string;
  razorpay_signature: string;
}

/**
 * Create Razorpay order
 */
export const createOrder = async (params: CreateOrderParams) => {
  if (!razorpay) {
    throw new Error("Razorpay is not configured");
  }

  const { amount, currency = "INR", receipt, notes } = params;

  const amountInPaise = Math.round(amount * 100);
  console.log("Razorpay createOrder =>", { amount, amountInPaise, currency, receipt });

  try {
    const order = await razorpay.orders.create({
      amount: amountInPaise,
      currency,
      receipt: receipt || `order_${Date.now()}`,
      notes,
    });

    return {
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      receipt: order.receipt,
    };
  } catch (err: any) {
    console.error("Razorpay SDK error:", JSON.stringify(err?.error || err));
    throw new Error(err?.error?.description || err?.message || "Razorpay order creation failed");
  }
};

/**
 * Verify Razorpay payment signature
 */
export const verifyPayment = (params: VerifyPaymentParams): boolean => {
  if (!config.razorpay.keySecret) {
    throw new Error("Razorpay is not configured");
  }

  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = params;

  const body = razorpay_order_id + "|" + razorpay_payment_id;

  const expectedSignature = crypto
    .createHmac("sha256", config.razorpay.keySecret)
    .update(body.toString())
    .digest("hex");

  return expectedSignature === razorpay_signature;
};

/**
 * Fetch payment details
 */
export const getPaymentDetails = async (paymentId: string) => {
  if (!razorpay) {
    throw new Error("Razorpay is not configured");
  }

  return await razorpay.payments.fetch(paymentId);
};

/**
 * Initiate refund
 */
export const initiateRefund = async (
  paymentId: string,
  amount?: number, // Amount in rupees (optional - full refund if not provided)
  notes?: Record<string, string>,
) => {
  if (!razorpay) {
    throw new Error("Razorpay is not configured");
  }

  const refundParams: any = {
    notes,
  };

  if (amount) {
    refundParams.amount = amount * 100; // Convert to paise
  }

  return await razorpay.payments.refund(paymentId, refundParams);
};

/**
 * Get refund status
 */
export const getRefundStatus = async (paymentId: string, refundId: string) => {
  if (!razorpay) {
    throw new Error("Razorpay is not configured");
  }

  return await razorpay.refunds.fetch(refundId);
};

/**
 * Create payment link (for COD to online conversion)
 */
export const createPaymentLink = async (params: {
  amount: number;
  customerName: string;
  customerPhone: string;
  customerEmail?: string;
  description?: string;
  bookingId?: string;
}) => {
  if (!razorpay) {
    throw new Error("Razorpay is not configured");
  }

  const paymentLink = await razorpay.paymentLink.create({
    amount: params.amount * 100,
    currency: "INR",
    accept_partial: false,
    description: params.description || "Kebu One Payment",
    customer: {
      name: params.customerName,
      contact: params.customerPhone,
      email: params.customerEmail,
    },
    notify: {
      sms: true,
      email: !!params.customerEmail,
    },
    reminder_enable: true,
    notes: {
      bookingId: params.bookingId || "",
    },
    callback_url: `${process.env.API_URL}/v1/api/payment/callback`,
    callback_method: "get",
  });

  return {
    paymentLinkId: paymentLink.id,
    shortUrl: paymentLink.short_url,
    amount: paymentLink.amount,
    status: paymentLink.status,
  };
};

/**
 * Update payment status (placeholder for future database implementation)
 */
export const updatePaymentStatus = async (
  paymentId: string,
  status: string
): Promise<void> => {
  console.log(`Payment ${paymentId} status updated to: ${status}`);
};
