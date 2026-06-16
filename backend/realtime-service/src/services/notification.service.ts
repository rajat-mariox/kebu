import admin from 'firebase-admin';
import { getConfig } from '../utils/config';
import { createLogger } from '../utils/logger';
import { NotificationPayload } from '../types';

const logger = createLogger('Notification');

let firebaseApp: admin.app.App | null = null;

export const initFirebase = async (): Promise<void> => {
  const config = getConfig();

  if (!config.firebase.projectId || !config.firebase.privateKey || !config.firebase.clientEmail) {
    logger.warn('Firebase configuration missing. Push notifications disabled.');
    return;
  }

  try {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: config.firebase.projectId,
        privateKey: config.firebase.privateKey,
        clientEmail: config.firebase.clientEmail,
      }),
    }, 'kebu-realtime-service');

    logger.info('Firebase initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize Firebase', { error });
  }
};

export const sendPushNotification = async (payload: NotificationPayload): Promise<boolean> => {
  if (!firebaseApp) {
    logger.warn('Firebase not initialized. Skipping push notification.');
    return false;
  }

  try {
    const message: admin.messaging.Message = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      android: {
        priority: (payload.android?.priority as any) || 'high',
        notification: {
          channelId: payload.android?.channelId || 'kebu_rides',
          sound: payload.android?.sound || 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: payload.ios?.sound || 'default',
            badge: payload.ios?.badge || 1,
          },
        },
      },
    };

    if (payload.token) {
      message.token = payload.token;
    } else if (payload.topic) {
      message.topic = payload.topic;
    } else {
      throw new Error('Either token or topic must be provided');
    }

    const response = await admin.messaging().send(message);
    logger.info('Push notification sent', { messageId: response });
    return true;
  } catch (error) {
    logger.error('Failed to send push notification', { error });
    return false;
  }
};

export const sendToMultipleDevices = async (
  tokens: string[],
  payload: Omit<NotificationPayload, 'token' | 'topic'>
): Promise<{ success: number; failure: number }> => {
  if (!firebaseApp) {
    logger.warn('Firebase not initialized. Skipping push notification.');
    return { success: 0, failure: tokens.length };
  }

  try {
    const message: admin.messaging.MulticastMessage = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      tokens,
      data: payload.data || {},
      android: {
        priority: (payload.android?.priority as any) || 'high',
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    
    const results = {
      success: response.successCount,
      failure: response.failureCount,
    };

    logger.info('Multicast push notification sent', results);
    return results;
  } catch (error) {
    logger.error('Failed to send multicast push notification', { error });
    return { success: 0, failure: tokens.length };
  }
};

export const subscribeToTopic = async (tokens: string[], topic: string): Promise<boolean> => {
  if (!firebaseApp) {
    logger.warn('Firebase not initialized. Skipping topic subscription.');
    return false;
  }

  try {
    await admin.messaging().subscribeToTokens(tokens, topic);
    logger.info(`Subscribed ${tokens.length} tokens to topic: ${topic}`);
    return true;
  } catch (error) {
    logger.error('Failed to subscribe to topic', { error });
    return false;
  }
};

export const unsubscribeFromTopic = async (tokens: string[], topic: string): Promise<boolean> => {
  if (!firebaseApp) {
    logger.warn('Firebase not initialized. Skipping topic unsubscription.');
    return false;
  }

  try {
    await admin.messaging().unsubscribeFromTokens(tokens, topic);
    logger.info(`Unsubscribed ${tokens.length} tokens from topic: ${topic}`);
    return true;
  } catch (error) {
    logger.error('Failed to unsubscribe from topic', { error });
    return false;
  }
};

export const sendRideAcceptedNotification = async (
  userToken: string,
  driverName: string,
  vehicleNumber: string,
  eta: number
): Promise<boolean> => {
  return sendPushNotification({
    token: userToken,
    title: 'Driver Accepted Your Ride! 🚗',
    body: `${driverName} is on the way. Arriving in ${eta} mins. Vehicle: ${vehicleNumber}`,
    data: {
      type: 'ride_accepted',
      click_action: 'OPEN_RIDE_TRACKING',
    },
    android: { priority: 'high' },
  });
};

export const sendDriverArrivedNotification = async (
  userToken: string,
  driverName: string
): Promise<boolean> => {
  return sendPushNotification({
    token: userToken,
    title: 'Driver Arrived! 📍',
    body: `${driverName} has arrived at your pickup location.`,
    data: {
      type: 'driver_arrived',
      click_action: 'OPEN_RIDE_TRACKING',
    },
    android: { priority: 'high' },
  });
};

export const sendRideCompletedNotification = async (
  userToken: string,
  fare: number,
  rating: number
): Promise<boolean> => {
  return sendPushNotification({
    token: userToken,
    title: 'Ride Completed! ✅',
    body: `Your ride is complete. Fare: ₹${fare}. Rate your trip!`,
    data: {
      type: 'ride_completed',
      fare: fare.toString(),
      click_action: 'OPEN_RATING',
    },
    android: { priority: 'high' },
  });
};

export const sendNewRideRequestNotification = async (
  driverTokens: string[],
  pickup: string,
  fare: number,
  distance: number
): Promise<{ success: number; failure: number }> => {
  return sendToMultipleDevices(driverTokens, {
    title: 'New Ride Request! 🔔',
    body: `Pickup: ${pickup} | Fare: ₹${fare} | Distance: ${distance.toFixed(1)} km`,
    data: {
      type: 'new_ride_request',
      click_action: 'OPEN_RIDE_REQUEST',
    },
    android: { priority: 'high' },
  });
};

export const sendSOSAlertNotification = async (
  adminTokens: string[],
  bookingId: string,
  location: { lat: number; lng: number }
): Promise<{ success: number; failure: number }> => {
  return sendToMultipleDevices(adminTokens, {
    title: '🚨 SOS Alert!',
    body: `Emergency alert for booking ${bookingId}. Location: ${location.lat}, ${location.lng}`,
    data: {
      type: 'sos_alert',
      bookingId,
      latitude: location.lat.toString(),
      longitude: location.lng.toString(),
      click_action: 'OPEN_SOS_DASHBOARD',
    },
    android: { priority: 'high' },
  });
};

export const sendChatMessageNotification = async (
  receiverToken: string,
  senderName: string,
  message: string
): Promise<boolean> => {
  return sendPushNotification({
    token: receiverToken,
    title: `Message from ${senderName}`,
    body: message.length > 100 ? message.substring(0, 100) + '...' : message,
    data: {
      type: 'new_message',
      click_action: 'OPEN_CHAT',
    },
    android: { priority: 'normal' },
  });
};
