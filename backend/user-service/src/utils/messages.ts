export type Lang = "en" | string;

export type MessageKey =
  | "user_already_found"
  | "success"
  | "logout"
  | "invalid_token"
  | "users_list"
  | "user_not_found"
  | "forbidden"
  | "otp_sent"
  | "otp_verified"
  | "incorrect_otp"
  | "status_changed"
  | "interest_exists"
  // Booking messages
  | "fare_estimated"
  | "booking_created"
  | "booking_not_found"
  | "booking_cancelled"
  | "booking_cannot_be_cancelled"
  | "booking_not_completed"
  | "active_booking_exists"
  | "invalid_vehicle_type"
  | "ride_accepted"
  | "ride_cancelled"
  | "rating_submitted"
  | "invalid_status_transition"
  | "invalid_otp"
  | "status_updated"
  | "unauthorized"
  // Driver messages
  | "driver_not_found"
  | "driver_not_approved"
  | "driver_online"
  | "driver_offline"
  | "driver_approved"
  | "driver_rejected"
  | "driver_suspended"
  | "booking_not_available"
  // Driver onboarding messages
  | "personal_info_updated"
  | "kyc_documents_uploaded"
  | "aadhaar_images_required"
  | "aadhaar_uploaded"
  | "pan_front_image_required"
  | "pan_uploaded"
  | "license_images_required"
  | "driving_license_uploaded"
  | "selfie_required"
  | "selfie_uploaded"
  | "rc_image_required"
  | "rc_uploaded"
  | "registration_number_exists"
  | "vehicle_added"
  | "personal_info_incomplete"
  | "kyc_incomplete"
  | "vehicle_not_added"
  | "submitted_for_verification"
  | "logout_success"
  // Delivery messages
  | "delivery_created"
  | "delivery_not_found"
  | "delivery_cancelled"
  | "delivery_cannot_be_cancelled"
  | "delivery_not_completed"
  | "active_delivery_exists"
  // Service messages
  | "provider_not_found"
  | "provider_approved"
  // Payment messages
  | "order_created"
  | "payment_error"
  | "payment_verified"
  | "payment_verification_failed"
  | "payment_not_found"
  | "refund_initiated"
  | "refund_failed"
  | "payment_link_created"
  | "payment_link_failed"
  // Admin messages
  | "invalid_credentials"
  | "login_success"
  | "user_activated"
  | "user_deactivated"
  | "category_created"
  | "vehicle_type_created"
  | "vehicle_type_updated"
  | "vehicle_type_not_found"
  // Maps messages
  | "place_not_found"
  | "directions_not_available"
  // Account messages
  | "ac_deactivated"
  // Customer features messages
  | "invalid_promo_code"
  | "promo_not_applicable"
  | "min_order_not_met"
  | "promo_expired"
  | "promo_applied"
  | "promo_usage_exceeded"
  | "plan_not_found"
  | "subscription_already_active"
  | "subscription_created"
  | "referral_already_applied"
  | "invalid_referral_code"
  | "cannot_refer_self"
  | "referral_applied"
  | "ticket_created"
  | "ticket_not_found"
  | "message_added"
  | "payment_method_added"
  | "payment_method_deleted"
  | "payment_method_not_found"
  | "rider_added"
  | "rider_updated"
  | "rider_deleted"
  | "rider_not_found"
  | "tip_added"
  // Household service messages
  | "service_not_found"
  | "package_not_found"
  | "slot_not_available"
  | "multiple_booking_created";

type MessageMap = Record<MessageKey, string>;

export default function messages(lang: Lang = "en"): MessageMap {
  const data: Record<MessageKey, Record<string, string>> = {
    user_already_found: {
      en: "User already found with given username, Try again after new username!",
    },
    success: {
      en: "Success",
    },
    logout: {
      en: "Logout successfully",
    },
    invalid_token: {
      en: "Invalid token",
    },
    users_list: {
      en: "Users list",
    },
    user_not_found: {
      en: "User not found",
    },
    forbidden: {
      en: "Access forbidden",
    },
    otp_sent: {
      en: "OTP sent to your mobile number",
    },
    otp_verified: {
      en: "Login successful",
    },
    incorrect_otp: {
      en: "Incorrect OTP, try again!",
    },
    status_changed: {
      en: "Status changed successfully",
    },
    interest_exists: {
      en: "You have added this interest before",
    },
    // Booking messages
    fare_estimated: {
      en: "Fare estimated successfully",
    },
    booking_created: {
      en: "Booking created successfully",
    },
    booking_not_found: {
      en: "Booking not found",
    },
    booking_cancelled: {
      en: "Booking cancelled successfully",
    },
    booking_cannot_be_cancelled: {
      en: "This booking cannot be cancelled",
    },
    booking_not_completed: {
      en: "Booking is not completed yet",
    },
    active_booking_exists: {
      en: "You already have an active booking",
    },
    invalid_vehicle_type: {
      en: "Invalid vehicle type",
    },
    ride_accepted: {
      en: "Ride accepted successfully",
    },
    ride_cancelled: {
      en: "Ride cancelled",
    },
    rating_submitted: {
      en: "Rating submitted successfully",
    },
    invalid_status_transition: {
      en: "Invalid status transition",
    },
    invalid_otp: {
      en: "Invalid OTP",
    },
    status_updated: {
      en: "Status updated successfully",
    },
    unauthorized: {
      en: "Unauthorized access",
    },
    // Driver messages
    driver_not_found: {
      en: "Driver not found",
    },
    driver_not_approved: {
      en: "Your account is not approved yet",
    },
    driver_online: {
      en: "You are now online",
    },
    driver_offline: {
      en: "You are now offline",
    },
    driver_approved: {
      en: "Driver approved successfully",
    },
    driver_rejected: {
      en: "Driver rejected",
    },
    driver_suspended: {
      en: "Driver suspended",
    },
    booking_not_available: {
      en: "Booking is no longer available",
    },
    // Driver onboarding messages
    personal_info_updated: {
      en: "Personal information updated successfully",
    },
    kyc_documents_uploaded: {
      en: "KYC documents uploaded successfully",
    },
    aadhaar_images_required: {
      en: "Aadhaar front and back images are required",
    },
    aadhaar_uploaded: {
      en: "Aadhaar card uploaded successfully",
    },
    pan_front_image_required: {
      en: "PAN card front image is required",
    },
    pan_uploaded: {
      en: "PAN card uploaded successfully",
    },
    license_images_required: {
      en: "Driving license front and back images are required",
    },
    driving_license_uploaded: {
      en: "Driving license uploaded successfully",
    },
    selfie_required: {
      en: "Selfie image is required",
    },
    selfie_uploaded: {
      en: "Selfie uploaded successfully",
    },
    rc_image_required: {
      en: "RC image is required",
    },
    rc_uploaded: {
      en: "RC uploaded successfully",
    },
    registration_number_exists: {
      en: "Vehicle with this registration number already exists",
    },
    vehicle_added: {
      en: "Vehicle added successfully",
    },
    personal_info_incomplete: {
      en: "Please complete your personal information first",
    },
    kyc_incomplete: {
      en: "Please upload all KYC documents",
    },
    vehicle_not_added: {
      en: "Please add a vehicle first",
    },
    submitted_for_verification: {
      en: "Submitted for verification successfully",
    },
    logout_success: {
      en: "Logged out successfully",
    },
    // Delivery messages
    delivery_created: {
      en: "Delivery booking created successfully",
    },
    delivery_not_found: {
      en: "Delivery not found",
    },
    delivery_cancelled: {
      en: "Delivery cancelled successfully",
    },
    delivery_cannot_be_cancelled: {
      en: "This delivery cannot be cancelled",
    },
    delivery_not_completed: {
      en: "Delivery is not completed yet",
    },
    active_delivery_exists: {
      en: "You already have an active delivery",
    },
    // Service messages
    provider_not_found: {
      en: "Service provider not found",
    },
    provider_approved: {
      en: "Provider approved successfully",
    },
    // Payment messages
    order_created: {
      en: "Payment order created",
    },
    payment_error: {
      en: "Payment error occurred",
    },
    payment_verified: {
      en: "Payment verified successfully",
    },
    payment_verification_failed: {
      en: "Payment verification failed",
    },
    payment_not_found: {
      en: "Payment not found",
    },
    refund_initiated: {
      en: "Refund initiated successfully",
    },
    refund_failed: {
      en: "Refund failed",
    },
    payment_link_created: {
      en: "Payment link created",
    },
    payment_link_failed: {
      en: "Failed to create payment link",
    },
    // Admin messages
    invalid_credentials: {
      en: "Invalid email or password",
    },
    login_success: {
      en: "Login successful",
    },
    user_activated: {
      en: "User activated successfully",
    },
    user_deactivated: {
      en: "User deactivated",
    },
    category_created: {
      en: "Category created successfully",
    },
    vehicle_type_created: {
      en: "Vehicle type created successfully",
    },
    vehicle_type_updated: {
      en: "Vehicle type updated successfully",
    },
    vehicle_type_not_found: {
      en: "Vehicle type not found",
    },
    // Maps messages
    place_not_found: {
      en: "Place not found",
    },
    directions_not_available: {
      en: "Directions not available",
    },
    // Account messages
    ac_deactivated: {
      en: "Your account has been deactivated",
    },
    // Customer features messages
    invalid_promo_code: {
      en: "Invalid promo code",
    },
    promo_not_applicable: {
      en: "This promo code is not applicable for this service",
    },
    min_order_not_met: {
      en: "Minimum order value not met for this promo code",
    },
    promo_expired: {
      en: "This promo code has expired",
    },
    promo_applied: {
      en: "Promo code applied successfully",
    },
    promo_usage_exceeded: {
      en: "You have exceeded the usage limit for this promo code",
    },
    plan_not_found: {
      en: "Subscription plan not found",
    },
    subscription_already_active: {
      en: "You already have an active subscription",
    },
    subscription_created: {
      en: "Subscription activated successfully",
    },
    referral_already_applied: {
      en: "You have already applied a referral code",
    },
    invalid_referral_code: {
      en: "Invalid referral code",
    },
    cannot_refer_self: {
      en: "You cannot use your own referral code",
    },
    referral_applied: {
      en: "Referral code applied successfully",
    },
    ticket_created: {
      en: "Support ticket created successfully",
    },
    ticket_not_found: {
      en: "Support ticket not found",
    },
    message_added: {
      en: "Message sent successfully",
    },
    payment_method_added: {
      en: "Payment method added successfully",
    },
    payment_method_deleted: {
      en: "Payment method deleted successfully",
    },
    payment_method_not_found: {
      en: "Payment method not found",
    },
    rider_added: {
      en: "Rider added successfully",
    },
    rider_updated: {
      en: "Rider updated successfully",
    },
    rider_deleted: {
      en: "Rider deleted successfully",
    },
    rider_not_found: {
      en: "Rider not found",
    },
    tip_added: {
      en: "Tip added successfully",
    },
    // Household service messages
    service_not_found: {
      en: "Service not found",
    },
    package_not_found: {
      en: "Service package not found",
    },
    slot_not_available: {
      en: "Selected time slot is not available",
    },
    multiple_booking_created: {
      en: "Multiple booking created successfully",
    },
  };

  // fallback to English
  const result = {} as MessageMap;

  (Object.keys(data) as MessageKey[]).forEach((key) => {
    result[key] = data[key][lang] || data[key]["en"];
  });

  return result;
}
