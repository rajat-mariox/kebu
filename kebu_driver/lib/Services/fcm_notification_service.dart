import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:kebu_driver/Screens/DriverModule/RideRequestScreen/ride_request_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/BookingDetailScreen/booking_detail_screen.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  
  // Handle new ride request in background
  if (message.data['type'] == 'new_ride_request') {
    // Play sound or vibration
    print('New ride request received in background!');
  }
}

class FCMNotificationService {
  static final FCMNotificationService _instance = FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM
  Future<void> initialize() async {
    try {
      // Request permissions (iOS)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true, // For important ride requests
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Driver granted FCM permission');
      } else {
        print('Driver declined FCM permission');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('FCM Token refreshed: $newToken');
        // TODO: Send updated token to backend
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app was opened from a terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    // Create high-priority notification channel for ride requests
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'kebu_driver_rides',
      'Ride Requests',
      description: 'High priority notifications for new ride requests',
      importance: Importance.max,
      playSound: true,
      enableLights: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Driver foreground message: ${message.notification?.title}');
    
    final String? type = message.data['type'];
    
    if (type == 'new_ride_request') {
      // Show ride request popup/dialog immediately
      _showRideRequestNotification(message);
      
      // You can also navigate to RideRequestScreen or show a dialog
      // Get.to(() => RideRequestScreen(bookingData: message.data));
    } else if (type == 'ride_taken') {
      // Another driver accepted, close the notification
      print('Ride taken by another driver');
      // Close any open ride request dialog
    } else {
      // Show normal notification
      _showLocalNotification(message);
    }
  }

  /// Handle message tap. Routes based on the push's `click_action`:
  ///
  /// - `OPEN_RIDE_REQUEST` (new ride buzzer) → push `RideRequestScreen`
  ///   with the bookingId so the buzzer hydrates from REST.
  /// - `OPEN_RIDE_TRACKING` for cancellations → push `BookingDetailScreen`.
  /// - other ride-tracking pushes (accepted/arrived/started/completed)
  ///   → also push `BookingDetailScreen` (driver gets a recap of the
  ///   ride in question; ongoing rides have their own active-ride screen
  ///   restored on home-screen resume).
  void _handleMessageTap(RemoteMessage message) {
    print('Driver message tapped: ${message.data}');

    final data = message.data;
    final String type = (data['type'] ?? '').toString();
    final String clickAction = (data['click_action'] ?? '').toString();
    final String bookingId = (data['bookingId'] ?? '').toString();

    final ctx = Get.key.currentContext;
    if (ctx == null) return;

    if (clickAction == 'OPEN_RIDE_REQUEST' || type == 'new_ride_request') {
      if (bookingId.isEmpty) return;
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => RideRequestScreen(bookingId: bookingId),
      ));
      return;
    }

    if (clickAction == 'OPEN_RIDE_TRACKING') {
      if (bookingId.isEmpty) return;
      Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => BookingDetailScreen(bookingId: bookingId),
      ));
      return;
    }
  }

  /// Show ride request notification with high priority
  Future<void> _showRideRequestNotification(RemoteMessage message) async {
    final data = message.data;
    
    await _localNotifications.show(
      message.hashCode,
      '🚗 New Ride Request!',
      '${data['pickup']} • ₹${data['fare']} • ${data['distanceKm']} km',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kebu_driver_rides',
          'Ride Requests',
          channelDescription: 'High priority notifications for new ride requests',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableLights: true,
          enableVibration: true,
          fullScreenIntent: true, // Show as heads-up notification
          icon: '@mipmap/ic_launcher',
          timeoutAfter: 30000, // Auto-dismiss after 30 seconds
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      payload: message.data.toString(),
    );
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kebu_driver_general',
            'General Notifications',
            channelDescription: 'General driver notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Dismiss ride request notification (when taken by another driver)
  Future<void> dismissRideRequestNotification(int notificationId) async {
    await _localNotifications.cancel(notificationId);
  }

  /// Get device info
  Future<Map<String, String>> getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return {
          'deviceType': 'android',
          'deviceModel': androidInfo.model,
          'deviceId': androidInfo.id,
          'appVersion': '1.0.0',
        };
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return {
          'deviceType': 'ios',
          'deviceModel': iosInfo.model,
          'deviceId': iosInfo.identifierForVendor ?? '',
          'appVersion': '1.0.0',
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
    
    return {
      'deviceType': Platform.isAndroid ? 'android' : 'ios',
      'deviceModel': 'unknown',
      'deviceId': 'unknown',
      'appVersion': '1.0.0',
    };
  }
}
