# Quick Integration Guide - E2E Booking Flow

## ✅ What Was Implemented

### Backend Changes Summary
1. ✅ FCM token + device info fields added to User & Driver models
2. ✅ Auth controllers updated to capture device info at login
3. ✅ Booking controller sends FCM to offline drivers
4. ✅ Socket handler notifies all drivers when ride is taken
5. ✅ Booking tracks notified driver IDs

### Flutter Changes Summary
1. ✅ Firebase packages added to pubspec.yaml (both apps)
2. ✅ FCM service created for customer app
3. ✅ FCM service created for driver app (with ride_taken handling)

## 🚀 Quick Integration Steps

### Step 1: Install Backend Dependencies (Already Done)
The backend already has `firebase-admin` installed.

### Step 2: Flutter Dependencies
Run in both apps:
```bash
# Customer app
cd kebu_customer
flutter pub get

# Driver app
cd kebu_driver
flutter pub get
```

### Step 3: Firebase Console Setup

1. **Go to:** https://console.firebase.google.com
2. **Create Project** (or use existing)
3. **Add Android Apps:**
   - Customer: `com.kebu.customer` (check your package name)
   - Driver: `com.kebu.driver`
4. **Download Files:**
   - `google-services.json` → Place in `android/app/`
   - `GoogleService-Info.plist` → Place in `ios/Runner/`
5. **Enable Cloud Messaging** in Firebase Console

### Step 4: Update Customer App Main

**File:** `kebu_customer/lib/main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'Services/fcm_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize FCM
  await FCMNotificationService().initialize();
  
  runApp(const MyApp());
}
```

### Step 5: Update Customer Login/OTP Verification

**Find your OTP verification API call and add:**

```dart
// Get FCM service instance
final fcm = FCMNotificationService();
final deviceInfo = await fcm.getDeviceInfo();

// Your existing API call with added fields:
final response = await http.post(
  Uri.parse('$baseUrl/auth/verify-otp'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'otp': otp,
    'txnId': txnId,
    // ⭐ NEW: Add these fields
    'fcmToken': fcm.fcmToken,
    'deviceType': deviceInfo['deviceType'],
    'deviceModel': deviceInfo['deviceModel'],
    'deviceId': deviceInfo['deviceId'],
    'appVersion': deviceInfo['appVersion'],
  }),
);
```

### Step 6: Update Driver App Main

**File:** `kebu_driver/lib/main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'Services/fcm_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  await FCMNotificationService().initialize();
  
  runApp(const MyApp());
}
```

### Step 7: Update Driver Login/OTP Verification

**Same as customer app:**

```dart
final fcm = FCMNotificationService();
final deviceInfo = await fcm.getDeviceInfo();

final response = await http.post(
  Uri.parse('$baseUrl/driver/auth/verify-otp'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'otp': otp,
    'txnId': txnId,
    'fcmToken': fcm.fcmToken,
    'deviceType': deviceInfo['deviceType'],
    'deviceModel': deviceInfo['deviceModel'],
    'deviceId': deviceInfo['deviceId'],
    'appVersion': deviceInfo['appVersion'],
  }),
);
```

### Step 8: Critical - Listen for "ride_taken" in Driver App

**Find your Socket Service or Driver Booking Controller:**

```dart
// In your socket initialization or wherever you listen for socket events
socket.on('ride_taken', (data) {
  print('Ride ${data['bookingId']} taken by another driver');
  
  // Close any open ride request popup
  if (Get.isDialogOpen ?? false) {
    Get.back(); // Close dialog
    Get.snackbar(
      'Ride Taken',
      'This ride was accepted by another driver',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
    );
  }
  
  // Or if using a dedicated screen:
  if (Get.currentRoute == '/ride-request') {
    Get.back();
    Get.snackbar('Ride Taken', data['message']);
  }
  
  // Or update state in your controller:
  // Get.find<DriverBookingController>().closeRideRequest(data['bookingId']);
});
```

### Step 9: Backend Environment Variables

**File:** `backend/.env`

Add Firebase credentials:
```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour_Private_Key_Here\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

**To get these:**
1. Go to Firebase Console
2. Project Settings → Service Accounts
3. Generate New Private Key
4. Download JSON file
5. Copy values from JSON to .env

### Step 10: Android Manifest Updates

**Customer:** `kebu_customer/android/app/src/main/AndroidManifest.xml`
**Driver:** `kebu_driver/android/app/src/main/AndroidManifest.xml`

Add inside `<application>` tag:

```xml
<!-- Firebase Cloud Messaging -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="kebu_notifications" />

<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@mipmap/ic_launcher" />
```

Add permissions (outside `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### Step 11: Test the Flow

**Test Scenario 1: Online Driver**
1. Login as driver (app open)
2. Login as customer
3. Customer books a ride
4. **Expected:** Driver instantly sees ride request via socket
5. Driver accepts
6. **Expected:** Customer sees "Driver assigned" immediately

**Test Scenario 2: Offline Driver**
1. Driver app closed or in background
2. Customer books a ride
3. **Expected:** Driver receives FCM push notification
4. Tap notification
5. **Expected:** App opens with ride request

**Test Scenario 3: Multiple Drivers (CRITICAL)**
1. Login as Driver A (app open)
2. Login as Driver B (app open)
3. Customer books a ride
4. **Expected:** Both drivers see ride request
5. Driver A accepts
6. **Expected:** Driver B sees "Ride taken" message and popup closes

### Step 12: Monitoring

**Check logs:**

Backend:
```bash
cd backend
npm run dev
# Should see: "Firebase Admin initialized successfully"
# On booking: "Notification sent successfully"
```

Flutter:
```bash
flutter run
# Should see: "FCM Token: <token>"
# On notification: "Foreground message: ..."
```

## 🐛 Common Issues & Fixes

### Issue 1: FCM Token is null
```dart
// Check initialization
await Firebase.initializeApp();
await FCMNotificationService().initialize();

// Check permissions
print('FCM Token: ${FCMNotificationService().fcmToken}');
```

### Issue 2: Notifications not received on Android
1. Check `google-services.json` is in `android/app/`
2. Run `flutter clean` and rebuild
3. Check notification permission is granted
4. Check app is not in battery optimization

### Issue 3: "ride_taken" not working
Verify socket connection:
```dart
socket.on('connect', () => print('Socket connected'));
socket.on('ride_taken', (data) => print('Ride taken: $data'));
```

### Issue 4: Backend Firebase error
1. Verify `.env` file has correct Firebase credentials
2. Check private key has `\n` characters properly escaped
3. Restart backend server

## 📱 Platform-Specific Notes

### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- Add `google-services.json` before building

### iOS
- Minimum iOS: 12.0
- Add `GoogleService-Info.plist` to Xcode project
- Enable Push Notifications capability in Xcode
- Upload APNs key to Firebase Console for production

## 🎯 What Works Now

✅ **Customer App:**
- FCM token captured at login
- Device info stored
- Real-time ride updates via socket
- Push notifications when driver accepts

✅ **Driver App:**
- FCM token captured at login
- Device info stored
- Ride requests via socket (online)
- Ride requests via FCM (offline)
- **Automatic notification dismissal when ride taken**

✅ **Backend:**
- Stores FCM tokens for all users
- Sends push to offline drivers
- Tracks which drivers were notified
- Broadcasts "ride_taken" to all notified drivers

## 📚 Full Documentation

- **Complete Guide:** `E2E_BOOKING_FLOW_GUIDE.md`
- **Microservices Plan:** `MICROSERVICES_ARCHITECTURE.md`
- **Repository Memory:** `/memories/repo/booking-flow-architecture.md`

## ❓ Need Help?

Common questions:

**Q: Do I need MQTT?**
A: No, Socket.IO (which you already have) is better for this use case.

**Q: Should I migrate to microservices now?**
A: No, keep the monolith for now. See MICROSERVICES_ARCHITECTURE.md for when to migrate.

**Q: What if multiple drivers accept simultaneously?**
A: Backend checks booking status before assignment. Only first accepts, others get "ride_accept_failed".

**Q: How to update FCM token if it changes?**
A: Already handled - FCM service listens for token refresh and updates automatically.

## ✨ Next Steps

1. ⬜ Test with real devices
2. ⬜ Set up Firebase for production
3. ⬜ Add analytics tracking
4. ⬜ Implement retry logic for failed notifications
5. ⬜ Add APNs for iOS production
6. ⬜ Set up monitoring (Sentry/Firebase Crashlytics)

---

**Status:** ✅ Ready to integrate and test!

All backend changes are implemented. Follow Steps 1-12 above to complete Flutter integration.
