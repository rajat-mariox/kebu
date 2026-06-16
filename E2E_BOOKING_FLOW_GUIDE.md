# End-to-End Booking Flow Implementation Guide

## 🎯 Overview
Complete implementation of Uber/Ola-style cab booking with real-time notifications, FCM push notifications, device tracking,  and driver acceptance flow.

## 📋 Changes Implemented

### Backend Changes

#### 1. **Database Schema Updates**

**Driver Model** (`backend/src/interfaces/driver.ts` & `backend/src/models/driver.model.ts`)
- ✅ Added `fcmToken` field for push notifications
- ✅ Added `deviceType` (android/ios)
- ✅ Added `deviceModel`, `deviceId`, `appVersion` for device tracking

**User Model** (`backend/src/interfaces/users.ts` & `backend/src/models/Users.ts`)
- ✅ Updated from `deviceToken` to `fcmToken` for consistency
- ✅ Added `deviceType`, `deviceModel`, `deviceId`, `appVersion`

**Booking Model** (`backend/src/interfaces/booking.ts` & `backend/src/models/booking.model.ts`)
- ✅ Added `notifiedDriverIds[]` to track which drivers were notified
- ✅ This enables closing notifications for other drivers when one accepts

#### 2. **Auth Controllers**

**Customer Auth** (`backend/src/controllers/auth.controller.ts`)
```typescript
// Now accepts device info during OTP verification
verifyOtp({ 
  otp, txnId, 
  fcmToken, deviceType, deviceModel, deviceId, appVersion 
})
```

**Driver Auth** (`backend/src/controllers/driver-auth.controller.ts`)
```typescript
// Same device info capture for drivers
verifyDriverOtp({ 
  otp, txnId, 
  fcmToken, deviceType, deviceModel, deviceId, appVersion 
})
```

#### 3. **Booking Controller** (`backend/src/controllers/booking.controller.ts`)

**Enhanced Ride Request Flow:**
```typescript
// When customer books a ride:
1. Find nearby drivers (5km radius)
2. Store notified driver IDs in booking
3. Send socket events to ONLINE drivers
4. Send FCM push notifications to OFFLINE drivers
5. Include ride details: pickup, drop, fare, distance
```

#### 4. **Socket Handler** (`backend/src/socket/index.ts`)

**Critical Enhancement - Notify Other Drivers:**
```typescript
socket.on("accept_ride", async (data) => {
  // ... assign driver logic ...
  
  // ⭐ NEW: Notify all other drivers that ride is taken
  booking.notifiedDriverIds.forEach((notifiedDriverId) => {
    if (!notifiedDriverId.equals(driverId)) {
      io.to(`driver_${notifiedDriverId}`).emit("ride_taken", {
        bookingId: booking._id,
        message: "This ride has been accepted by another driver",
      });
    }
  });
});
```

#### 5. **Booking Service** (`backend/src/services/booking.service.ts`)
- ✅ Added generic `updateBooking()` method for flexible updates

### Flutter App Changes

#### 1. **Dependencies Added** (Both Apps)

**pubspec.yaml:**
```yaml
dependencies:
  firebase_core: ^3.8.1
  firebase_messaging: ^15.2.1
  device_info_plus: ^11.2.0
  flutter_local_notifications: ^18.0.1
```

#### 2. **FCM Notification Service Created**

**Customer App** (`kebu_customer/lib/Services/fcm_notification_service.dart`)
- Initialize Firebase Messaging
- Request notification permissions
- Capture FCM token
- Handle foreground/background/terminated state messages
- Navigate based on notification type

**Driver App** (`kebu_driver/lib/Services/fcm_notification_service.dart`)
- **High-priority notifications for ride requests**
- Handle "new_ride_request" with full-screen intent
- Handle "ride_taken" to dismiss notification
- Auto-dismiss after 30 seconds
- Get device info (model, OS, version)

## 🔄 Complete End-to-End Flow

### 1️⃣ User Login (Customer/Driver)
```dart
// Flutter: Capture device info and FCM token
final fcm = FCMNotificationService();
await fcm.initialize();
final deviceInfo = await fcm.getDeviceInfo();

// Send to backend during OTP verification
apiService.verifyOtp({
  'otp': otp,
  'txnId': txnId,
  'fcmToken': fcm.fcmToken,
  'deviceType': deviceInfo['deviceType'],
  'deviceModel': deviceInfo['deviceModel'],
  'deviceId': deviceInfo['deviceId'],
  'appVersion': deviceInfo['appVersion'],
});
```

### 2️⃣ Customer Books a Ride
```
Customer → Backend API → Creates Booking
                      ↓
              Find nearby drivers (5km)
                      ↓
          Store notified driver IDs
                      ↓
        ┌─────────────┴──────────────┐
        ↓                            ↓
  ONLINE DRIVERS              OFFLINE DRIVERS
  (Socket Event)              (FCM Push)
  "new_ride_request"          "new_ride_request"
```

### 3️⃣ Driver Receives Notification

**Online Driver (App Open):**
- Socket event received instantly
- Show ride request popup
- 30-second timer to accept/reject

**Offline Driver:**
- FCM push notification
- Notification shows: pickup, fare, distance
- Tap to open app → RideRequestScreen

### 4️⃣ Driver Accepts Ride
```dart
// Driver taps "Accept"
socket.emit('accept_ride', {'bookingId': bookingId});

// Backend processes:
1. Assign driver to booking
2. Update booking status to "ASSIGNED"
3. Notify customer via socket
4. ⭐ CRITICAL: Notify all other drivers via "ride_taken" event
5. Other drivers auto-dismiss notification
```

### 5️⃣ Other Drivers Notification Closed
```dart
// All other notified drivers receive:
socket.on('ride_taken', (data) {
  print('Ride ${data['bookingId']} taken by another driver');
  // Close/dismiss ride request popup
  Navigator.pop(context); // Close dialog
  Get.back(); // Or however you handle it
});

// For FCM notifications:
fcmService.dismissRideRequestNotification(notificationId);
```

### 6️⃣ Ride Progress
```
ASSIGNED → Driver navigates to pickup
         ↓
DRIVER_ARRIVED → Driver taps "Arrived"
         ↓
IN_PROGRESS → Driver enters OTP, starts ride
         ↓
COMPLETED → Driver completes ride
```

## 🛠️ Setup Instructions

### Backend Setup

1. **Update Environment Variables** (`.env`):
```env
# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
```

2. **Install Dependencies:**
```bash
cd backend
npm install
```

3. **Run Backend:**
```bash
npm run dev
```

### Flutter Customer App

1. **Install Dependencies:**
```bash
cd kebu_customer
flutter pub get
```

2. **Configure Firebase:**
   - Create Firebase project: https://console.firebase.google.com
   - Add Android app: `com.kebu.customer` (or your package name)
   - Add iOS app: `com.kebu.customer`
   - Download `google-services.json` → `android/app/`
   - Download `GoogleService-Info.plist` → `ios/Runner/`

3. **Update `main.dart`:**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'Services/fcm_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize FCM
  await FCMNotificationService().initialize();
  
  runApp(MyApp());
}
```

4. **Update OTP Verification:**
```dart
// In your auth service/controller
final fcm = FCMNotificationService();
final deviceInfo = await fcm.getDeviceInfo();

final response = await http.post(
  Uri.parse('$baseUrl/auth/verify-otp'),
  body: json.encode({
    'otp': otp,
    'txnId': txnId,
    'fcmToken': fcm.fcmToken,
    ...deviceInfo, // Spread device info
  }),
);
```

5. **Listen for Socket Events:**
```dart
// In BookingController or SocketService
socket.on('ride_accepted', (data) {
  // Navigate to live tracking
  Get.to(() => LiveTrackingScreen());
});

socket.on('driver_arrived', (data) {
  // Show alert or update UI
  Get.snackbar('Driver Arrived', 'Your driver has reached pickup point');
});
```

### Flutter Driver App

1. **Same Firebase Setup as Customer App**

2. **Update `main.dart`:**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'Services/fcm_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  await FCMNotificationService().initialize();
  
  runApp(MyApp());
}
```

3. **Listen for Ride Requests:**
```dart
// In DriverBookingController or SocketService

// Socket event (for online drivers)
socket.on('new_ride_request', (data) {
  // Show ride request popup
  Get.to(() => RideRequestScreen(
    bookingId: data['bookingId'],
    pickup: data['pickup'],
    drop: data['drop'],
    fare: data['fare'],
    distanceKm: data['distanceKm'],
  ));
});

// ⭐ CRITICAL: Listen for ride_taken event
socket.on('ride_taken', (data) {
  print('Ride ${data['bookingId']} taken by another driver');
  
  // Close any open ride request popup
  if (Get.isDialogOpen ?? false) {
    Get.back(); // Close dialog
  }
  
  // Or if using a screen:
  if (Get.currentRoute == '/ride-request') {
    Get.back();
    Get.snackbar('Ride Taken', data['message']);
  }
});
```

4. **Handle FCM Background Notifications:**
```dart
// FCM handles this automatically when app is in background/terminated
// The FCMNotificationService will show the notification
// When user taps, it will navigate to RideRequestScreen
```

## ⚠️ Critical Implementation Notes

### 1. Socket Event Handlers

**Driver App Must Listen for "ride_taken":**
```dart
// This is critical to close notifications when another driver accepts
socket.on('ride_taken', (data) {
  // Implementation depends on your UI structure
  // Option 1: Close dialog
  if (Get.isDialogOpen ?? false) Get.back();
  
  // Option 2: Close screen
  if (currentBookingId == data['bookingId']) {
    Navigator.pop(context);
  }
  
  // Option 3: Update state
  rideRequestController.closeRideRequest(data['bookingId']);
});
```

### 2. FCM Token Refresh

**Both Apps:**
```dart
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  // Send updated token to backend
  apiService.updateFcmToken(newToken);
});
```

### 3. Notification Permissions

**Request Early:**
```dart
// Best to request during onboarding or first launch
await FCMNotificationService().initialize();
```

### 4. Android Notification Channel

**Ensure high-priority for ride requests:**
```dart
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'kebu_driver_rides',
  'Ride Requests',
  importance: Importance.max, // Maximum priority
  playSound: true,
  enableVibration: true,
);
```

## 🐛 Testing Checklist

### End-to-End Flow Testing

- [ ] Customer login captures FCM token and device info
- [ ] Driver login captures FCM token and device info
- [ ] Customer books ride → Driver receives socket event (if online)
- [ ] Customer books ride → Driver receives FCM push (if offline/background)
- [ ] Driver accepts ride → Customer notified instantly
- [ ] **Driver accepts ride → All other drivers receive "ride_taken"**
- [ ] **Other drivers' notifications close automatically**
- [ ] Driver arrives → Customer notified
- [ ] Driver starts ride with OTP → Verified successfully
- [ ] Driver completes ride → Booking marked completed

### Notification Testing

- [ ] Foreground: Notification appears as popup
- [ ] Background: Notification appears in tray
- [ ] Terminated: Notification appears, tap opens app
- [ ] Sound/vibration works
- [ ] Notification auto-dismisses after 30s
- [ ] Multiple notifications handled correctly

### Edge Cases

- [ ] Two drivers try to accept simultaneously → Only one succeeds
- [ ] Customer cancels while driver accepting
- [ ] Driver goes offline mid-ride
- [ ] Socket disconnects and reconnects
- [ ] FCM token refresh handled
- [ ] App in background for extended period

## 🔧 Troubleshooting

### FCM Token Not Received
```dart
// Check Firebase initialization
await Firebase.initializeApp();

// Check permissions
NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
print('Permission status: ${settings.authorizationStatus}');

// Check token
String? token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

### Socket Events Not Received
```dart
// Ensure socket is connected
socket.on('connect', () => print('Socket connected'));
socket.on('disconnect', () => print('Socket disconnected'));

// Ensure proper room joining
socket.emit('join', {'userId': userId, 'userType': 'driver'});
```

### Notifications Not Showing on Android
- Check notification channel is created
- Check `AndroidManifest.xml` has proper permissions
- Ensure app has notification permission granted

### Backend FCM Errors
- Verify Firebase Admin SDK credentials in `.env`
- Check FCM token is valid (not expired)
- Ensure service account has proper permissions

## 📚 API Documentation

### POST /auth/verify-otp (Customer)
```json
{
  "otp": "1234",
  "txnId": "uuid-here",
  "fcmToken": "fcm-token-here",
  "deviceType": "android",
  "deviceModel": "Pixel 6",
  "deviceId": "device-id-here",
  "appVersion": "1.0.0"
}
```

### POST /driver/auth/verify-otp (Driver)
```json
{
  "otp": "1234",
  "txnId": "uuid-here",
  "fcmToken": "fcm-token-here",
  "deviceType": "android",
  "deviceModel": "Samsung S21",
  "deviceId": "device-id-here",
  "appVersion": "1.0.0"
}
```

### Socket Events

**Customer Emits:**
- `cancel_ride_user` - Cancel active booking

**Customer Listens:**
- `ride_accepted` - Driver accepted ride
- `driver_arrived` - Driver reached pickup
- `ride_started` - Ride in progress
- `ride_completed` - Ride finished
- `ride_cancelled` - Driver cancelled

**Driver Emits:**
- `driver_online` - Go online
- `driver_offline` - Go offline
- `location_update` - Update current location
- `accept_ride` - Accept ride request
- `reject_ride` - Reject ride request
- `arrived_at_pickup` - Reached pickup point
- `start_ride` - Start ride with OTP
- `complete_ride` - Complete ride
- `cancel_ride_driver` - Cancel ride

**Driver Listens:**
- `new_ride_request` - New booking available
- **`ride_taken`** - Another driver accepted (close notification)
- `ride_cancelled` - Customer cancelled
- `status_updated` - Online/offline status changed

## 🚀 Next Steps

1. **Test thoroughly** in development environment
2. **Configure Firebase** for production
3. **Update API base URLs** for production
4. **Set up monitoring** for FCM delivery rates
5. **Implement analytics** for booking flow
6. **Add retry logic** for failed notifications
7. **Set up APNs** for iOS production

## 📄 License
Internal documentation for KEBU project.
