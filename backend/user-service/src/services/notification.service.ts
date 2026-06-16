import admin from "firebase-admin";
import { Types } from "mongoose";
import config from "../config";
import { publishRideRequest } from "../mqtt/broker";
import { Notification, INotification } from "../models/customer-features.model";

// Initialize Firebase Admin
let firebaseApp: admin.app.App | null = null;

export const initFirebase = (): void => {
  if (firebaseApp) return;

  if (config.firebase.projectId && config.firebase.privateKey) {
    try {
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert({
          projectId: config.firebase.projectId,
          privateKey: config.firebase.privateKey.replace(/\\n/g, "\n"),
          clientEmail: config.firebase.clientEmail,
        }),
      });
      console.log("🔥 Firebase Admin initialized successfully");
    } catch (error) {
      console.error("Firebase Admin initialization failed:", error);
    }
  } else {
    console.warn("⚠️ Firebase config missing — push notifications disabled");
  }
};

// Auto-init on import (backward compat)
initFirebase();

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

/**
 * Send push notification to a single device
 */
export const sendToDevice = async (
  fcmToken: string,
  payload: NotificationPayload,
) => {
  if (!firebaseApp) {
    console.warn("Firebase not initialized, skipping notification");
    return null;
  }

  try {
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: payload.imageUrl,
      },
      data: payload.data,
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "kebu_notifications",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log("Notification sent successfully:", response);
    return response;
  } catch (error: any) {
    console.error("Error sending notification:", error);
    throw error;
  }
};

/**
 * Send push notification to multiple devices
 */
export const sendToMultipleDevices = async (
  fcmTokens: string[],
  payload: NotificationPayload,
) => {
  if (!firebaseApp) {
    console.warn("Firebase not initialized, skipping notifications");
    return null;
  }

  if (fcmTokens.length === 0) {
    return null;
  }

  try {
    const message: admin.messaging.MulticastMessage = {
      tokens: fcmTokens,
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: payload.imageUrl,
      },
      data: payload.data,
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "kebu_notifications",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `Notifications sent: ${response.successCount} success, ${response.failureCount} failed`,
    );
    return response;
  } catch (error) {
    console.error("Error sending notifications:", error);
    throw error;
  }
};

/**
 * Send notification to a topic (e.g., all drivers in a city)
 */
export const sendToTopic = async (
  topic: string,
  payload: NotificationPayload,
) => {
  if (!firebaseApp) {
    console.warn("Firebase not initialized, skipping notification");
    return null;
  }

  try {
    const message: admin.messaging.Message = {
      topic,
      notification: {
        title: payload.title,
        body: payload.body,
        imageUrl: payload.imageUrl,
      },
      data: payload.data,
    };

    const response = await admin.messaging().send(message);
    console.log("Topic notification sent:", response);
    return response;
  } catch (error) {
    console.error("Error sending topic notification:", error);
    throw error;
  }
};

/**
 * Subscribe device to a topic
 */
export const subscribeToTopic = async (fcmTokens: string[], topic: string) => {
  if (!firebaseApp) {
    return null;
  }

  try {
    const response = await admin.messaging().subscribeToTopic(fcmTokens, topic);
    return response;
  } catch (error) {
    console.error("Error subscribing to topic:", error);
    throw error;
  }
};

/**
 * Unsubscribe device from a topic
 */
export const unsubscribeFromTopic = async (
  fcmTokens: string[],
  topic: string,
) => {
  if (!firebaseApp) {
    return null;
  }

  try {
    const response = await admin
      .messaging()
      .unsubscribeFromTopic(fcmTokens, topic);
    return response;
  } catch (error) {
    console.error("Error unsubscribing from topic:", error);
    throw error;
  }
};

// ========== NOTIFICATION TEMPLATES ==========

export const NotificationTemplates = {
  // User notifications
  rideAccepted: (driverName: string) => ({
    title: "Ride Accepted! 🚗",
    body: `${driverName} is on the way to pick you up`,
  }),

  driverArrived: () => ({
    title: "Driver Arrived! 📍",
    body: "Your driver has arrived at the pickup location",
  }),

  rideStarted: () => ({
    title: "Ride Started 🚀",
    body: "Your ride has started. Enjoy your trip!",
  }),

  rideStartedDriver: () => ({
    title: "Ride Started 🚀",
    body: "OTP verified. The trip is now in progress — drive safely!",
  }),

  rideCompleted: (amount: number) => ({
    title: "Ride Completed! ✅",
    body: `Your ride is complete. Total fare: ₹${amount}`,
  }),

  rideCancelled: (cancelledBy: string) => ({
    title: "Ride Cancelled ❌",
    body: `Your ride was cancelled by ${cancelledBy}`,
  }),

  // Driver notifications
  newRideRequest: (pickup: string, fare: number) => ({
    title: "New Ride Request! 🔔",
    body: `Pickup: ${pickup} | Fare: ₹${fare}`,
  }),

  rideCompleteDriver: (amount: number) => ({
    title: "Ride Completed! 💰",
    body: `You earned ₹${amount} from this ride`,
  }),

  // Delivery notifications
  packagePickedUp: () => ({
    title: "Package Picked Up 📦",
    body: "Your package has been picked up and is on the way",
  }),

  packageDelivered: () => ({
    title: "Package Delivered! ✅",
    body: "Your package has been delivered successfully",
  }),

  // Promotional
  offerNotification: (title: string, body: string) => ({
    title,
    body,
  }),

  referralBonus: (amount: number) => ({
    title: "Referral Bonus! 🎉",
    body: `You earned ₹${amount} as referral bonus`,
  }),
};

// ========== HIGH-LEVEL NOTIFICATION HELPERS ==========

/**
 * Send new ride request to drivers via MQTT (bell ring) + FCM push.
 * Online drivers get MQTT instantly; offline drivers get FCM push.
 */
export const notifyDriversNewRide = async (
  drivers: {
    driverId: string;
    fcmToken?: string;
    isOnline: boolean;
  }[],
  rideData: {
    bookingId: string;
    pickup: any;
    drop: any;
    fare: number;
    distanceKm: number;
    durationMin: number;
    vehicleType?: string;
  }
): Promise<void> => {
  const offlineTokens: string[] = [];

  for (const driver of drivers) {
    // Always publish via MQTT — driver app listens on `driver/rides/{driverId}`
    publishRideRequest(driver.driverId, rideData);

    // Collect FCM tokens for offline drivers
    if (!driver.isOnline && driver.fcmToken) {
      offlineTokens.push(driver.fcmToken);
    }
  }

  // Send FCM push to offline drivers
  if (offlineTokens.length > 0) {
    const pickupAddr =
      typeof rideData.pickup === "string"
        ? rideData.pickup
        : rideData.pickup?.address?.substring(0, 50) || "Nearby";

    await sendToMultipleDevices(offlineTokens, {
      title: "New Ride Request! 🔔",
      body: `Pickup: ${pickupAddr} | Fare: ₹${rideData.fare}`,
      data: {
        type: "new_ride_request",
        bookingId: rideData.bookingId,
        click_action: "OPEN_RIDE_REQUEST",
      },
    });
  }

  console.log(
    `Ride ${rideData.bookingId}: MQTT sent to ${drivers.length} drivers, FCM to ${offlineTokens.length} offline`
  );
};

/**
 * Send FCM push for ride status changes (accepted, arrived, started, completed, cancelled)
 */
export const sendRideStatusPush = async (
  fcmToken: string | undefined,
  template: { title: string; body: string },
  data?: Record<string, string>
): Promise<void> => {
  if (!fcmToken) return;

  try {
    await sendToDevice(fcmToken, {
      ...template,
      data: {
        click_action: "OPEN_RIDE_TRACKING",
        ...data,
      },
    });
  } catch (err) {
    console.error("sendRideStatusPush failed:", err);
  }
};

/**
 * Send chat message notification via FCM
 */
export const sendChatNotification = async (
  receiverToken: string | undefined,
  senderName: string,
  message: string
): Promise<void> => {
  if (!receiverToken) return;

  await sendToDevice(receiverToken, {
    title: `Message from ${senderName}`,
    body: message.length > 100 ? message.substring(0, 100) + "..." : message,
    data: {
      type: "new_message",
      click_action: "OPEN_CHAT",
    },
  });
};

/**
 * Persist a notification row for the in-app notifications list. Pass exactly
 * one of `userId` / `driverId`. Failures are swallowed (logged) so a DB hiccup
 * never breaks the surrounding business action.
 */
export const createNotification = async (input: {
  userId?: string | Types.ObjectId;
  driverId?: string | Types.ObjectId;
  title: string;
  message: string;
  type?: INotification["type"];
  data?: INotification["data"];
}): Promise<void> => {
  if (!input.userId && !input.driverId) return;
  try {
    await Notification.create({
      userId: input.userId ? new Types.ObjectId(input.userId) : undefined,
      driverId: input.driverId ? new Types.ObjectId(input.driverId) : undefined,
      title: input.title,
      message: input.message,
      type: input.type ?? "ORDER",
      data: input.data,
      isRead: false,
    });
  } catch (err) {
    console.error("[createNotification] failed:", err);
  }
};

/**
 * Send SOS alert to admin tokens
 */
export const sendSOSAlert = async (
  adminTokens: string[],
  bookingId: string,
  location: { lat: number; lng: number }
): Promise<void> => {
  if (adminTokens.length === 0) return;

  await sendToMultipleDevices(adminTokens, {
    title: "🚨 SOS Alert!",
    body: `Emergency for booking ${bookingId}. Location: ${location.lat.toFixed(4)}, ${location.lng.toFixed(4)}`,
    data: {
      type: "sos_alert",
      bookingId,
      latitude: location.lat.toString(),
      longitude: location.lng.toString(),
      click_action: "OPEN_SOS_DASHBOARD",
    },
  });
};
