# Testing Checklist - E2E Booking Flow

## 🧪 Pre-Testing Setup

### Environment Setup
- [ ] Backend running on port 9060
- [ ] MongoDB connected
- [ ] Redis connected
- [ ] Firebase Admin SDK initialized (check logs: "Firebase Admin initialized successfully")
- [ ] Customer app built with FCM
- [ ] Driver app built with FCM
- [ ] Two test devices/emulators ready

### Test Accounts
- [ ] Customer account: `+91XXXXXXXXXX`
- [ ] Driver 1 account: `+91XXXXXXXXXX`
- [ ] Driver 2 account: `+91XXXXXXXXXX`
- [ ] Master OTP configured in backend (check `.env`)

---

## 📱 Phase 1: Login & Device Info

### Test 1.1: Customer Login
- [ ] Open customer app
- [ ] Enter mobile number
- [ ] Request OTP
- [ ] Enter OTP
- [ ] **Verify:** Check backend logs for device info saved:
  ```
  Device Type: android/ios
  FCM Token: received
  Device Model: Samsung/iPhone
  ```
- [ ] **Database Check:** 
  ```javascript
  db.users.findOne({ mobileNumber: "XXXXXXXXXX" })
  // Should have: fcmToken, deviceType, deviceModel, deviceId, appVersion
  ```

### Test 1.2: Driver Login (Driver 1)
- [ ] Open driver app
- [ ] Enter mobile number
- [ ] Request OTP
- [ ] Enter OTP
- [ ] **Verify:** FCM token and device info saved in driver collection

### Test 1.3: Driver Login (Driver 2)
- [ ] Repeat for second driver on different device

---

## 🚗 Phase 2: Online Driver - Socket Events

### Test 2.1: Single Driver Online
**Setup:**
- [ ] Driver 1 app open and online
- [ ] Socket connected (check logs: "Socket connected: driver - ID")

**Test:**
- [ ] Customer creates booking
- [ ] **Expected:** Driver 1 instantly receives "new_ride_request" event
- [ ] **Verify:** Ride request popup appears with:
  - Pickup location
  - Drop location
  - Fare amount
  - Distance
  - 30-second timer

**Backend Logs Should Show:**
```
BookingController => createBooking
Found X nearby drivers
Socket event emitted to driver_<ID>
```

### Test 2.2: Driver Accepts Ride
- [ ] Driver 1 taps "Accept"
- [ ] **Expected:**
  - Booking status changes to "ASSIGNED"
  - Customer receives "ride_accepted" socket event
  - Customer sees driver details
  - Driver sees booking confirmed
- [ ] **Database Check:**
  ```javascript
  db.bookings.findOne({ _id: bookingId })
  // Should have: driverId, status: "ASSIGNED", assignedAt: <timestamp>
  ```

### Test 2.3: Driver Rejects Ride
**Setup:**
- [ ] Customer creates new booking
- [ ] Driver 1 receives request

**Test:**
- [ ] Driver 1 taps "Reject"
- [ ] **Expected:**
  - Booking remains in "SEARCHING" status
  - Driver can continue receiving requests

---

## 🔔 Phase 3: Offline Driver - FCM Push

### Test 3.1: Driver App in Background
**Setup:**
- [ ] Driver 1 logged in but app in background
- [ ] Check driver's FCM token exists in database

**Test:**
- [ ] Customer creates booking
- [ ] **Expected:**
  - FCM notification appears on driver's device
  - Notification shows: pickup, fare, distance
  - Notification plays sound/vibration
- [ ] Tap notification
- [ ] **Expected:** App opens to ride request screen

**Backend Logs Should Show:**
```
Driver <ID> is offline, sending FCM
Notification sent successfully: <FCM_MESSAGE_ID>
```

### Test 3.2: Driver App Closed (Terminated)
- [ ] Completely close driver app (swipe from recent apps)
- [ ] Customer creates booking
- [ ] **Expected:** Same as 3.1
- [ ] **Verify:** App opens fresh when notification tapped

---

## 👥 Phase 4: Multiple Drivers (CRITICAL TEST)

### Test 4.1: Two Drivers Online
**Setup:**
- [ ] Driver 1 app open and online
- [ ] Driver 2 app open and online
- [ ] Both drivers in 5km radius

**Test:**
- [ ] Customer creates booking
- [ ] **Expected:**
  - Both drivers receive "new_ride_request" simultaneously
  - Both see ride request popup
  - Both timers count down from 30 seconds

### Test 4.2: One Accepts, Other Gets Notified
**Continuing from 4.1:**
- [ ] Driver 1 taps "Accept"
- [ ] **Expected for Driver 1:**
  - Sees "Ride Accepted" confirmation
  - Navigates to active ride screen
- [ ] **Expected for Driver 2:**
  - Receives "ride_taken" socket event
  - Ride request popup CLOSES immediately
  - Sees snackbar: "This ride was accepted by another driver"
  - Can continue receiving new requests

**Backend Logs Should Show:**
```
Driver <ID1> accepted booking <bookingId>
Emitting ride_taken to driver <ID2>
```

### Test 4.3: One Online, One Offline
**Setup:**
- [ ] Driver 1 app open and online
- [ ] Driver 2 app in background

**Test:**
- [ ] Customer creates booking
- [ ] **Expected:**
  - Driver 1 receives socket event (popup)
  - Driver 2 receives FCM notification
- [ ] Driver 1 accepts
- [ ] **Expected:**
  - Driver 2's FCM notification should be dismissed/updated
  - If Driver 2 taps notification later → "Ride no longer available"

### Test 4.4: Two Drivers Accept Simultaneously (Race Condition)
**Setup:**
- [ ] Driver 1 and Driver 2 both online
- [ ] Both receive same ride request

**Test:**
- [ ] Both drivers tap "Accept" at same time
- [ ] **Expected:**
  - First to reach server gets the ride
  - Second driver gets "ride_accept_failed" message
  - Second driver's popup closes

---

## 🚦 Phase 5: Complete Ride Flow

### Test 5.1: Driver Arrives at Pickup
- [ ] Driver accepts ride
- [ ] Driver navigates to pickup
- [ ] Driver taps "Arrived"
- [ ] Socket emits "arrived_at_pickup"
- [ ] **Expected for Customer:**
  - Receives "driver_arrived" event
  - UI updates to show "Driver has arrived"
  - Timer starts for pickup

### Test 5.2: Start Ride with OTP
- [ ] Driver taps "Start Ride"
- [ ] Driver enters 4-digit OTP (shown on customer app)
- [ ] Socket emits "start_ride" with OTP
- [ ] **Expected:**
  - Backend verifies OTP
  - Booking status → "IN_PROGRESS"
  - Customer sees "Ride Started"
  - Customer sees live location tracking

### Test 5.3: Complete Ride
- [ ] Driver reaches destination
- [ ] Driver taps "Complete Ride"
- [ ] Socket emits "complete_ride"
- [ ] **Expected:**
  - Booking status → "COMPLETED"
  - Customer sees payment screen
  - Driver sees rating screen
  - Driver's currentBookingId cleared

---

## 🚨 Phase 6: Cancellations

### Test 6.1: Customer Cancels Before Assignment
- [ ] Customer creates booking
- [ ] Drivers receive requests
- [ ] Customer taps "Cancel"
- [ ] **Expected:**
  - Booking status → "CANCELLED"
  - All notified drivers receive "ride_cancelled" event
  - Ride request popups close
  - Drivers can receive new requests

### Test 6.2: Customer Cancels After Assignment
- [ ] Driver accepts ride
- [ ] Customer cancels
- [ ] **Expected:**
  - Driver receives "ride_cancelled" event
  - Driver's currentBookingId cleared
  - Driver goes back to available state

### Test 6.3: Driver Cancels After Assignment
- [ ] Driver accepts ride
- [ ] Driver taps "Cancel" (with reason)
- [ ] **Expected:**
  - Customer receives "ride_cancelled" event
  - Booking status → "CANCELLED"
  - cancelledBy: "DRIVER"
  - Customer can book again

---

## 📍 Phase 7: Location Tracking

### Test 7.1: Driver Location Updates
- [ ] Driver accepts ride
- [ ] Driver moves (or use location simulation)
- [ ] Socket emits "location_update" every 5 seconds
- [ ] **Expected for Customer:**
  - Receives "driver_location" events
  - Map updates driver's position in real-time
  - ETA updates dynamically

### Test 7.2: Nearby Driver Search
- [ ] Customer at Location A
- [ ] Driver 1 at 2km radius
- [ ] Driver 2 at 7km radius
- [ ] Customer creates booking (5km search radius)
- [ ] **Expected:**
  - Only Driver 1 receives notification
  - Driver 2 does not receive (outside radius)

---

## 🔐 Phase 8: Edge Cases

### Test 8.1: Customer Offline During Acceptance
- [ ] Customer creates booking
- [ ] Turn off customer's internet
- [ ] Driver accepts ride
- [ ] Turn customer's internet back on
- [ ] **Expected:**
  - Socket reconnects automatically
  - Customer receives missed "ride_accepted" event
  - UI syncs with latest booking state

### Test 8.2: Driver Offline During Ride
- [ ] Ride in progress
- [ ] Turn off driver's internet for 30 seconds
- [ ] Turn back on
- [ ] **Expected:**
  - Socket reconnects
  - Driver can continue ride
  - Location updates resume

### Test 8.3: Multiple Bookings Prevention
- [ ] Customer has active booking
- [ ] Customer tries to create another booking
- [ ] **Expected:**
  - API returns error: "active_booking_exists"
  - Shows message: "You have an active ride"

### Test 8.4: FCM Token Refresh
- [ ] Login as driver
- [ ] Note FCM token in database
- [ ] Reinstall app
- [ ] Login again
- [ ] **Expected:**
  - New FCM token generated
  - Database updated with new token
  - Notifications still work

---

## 🔍 Phase 9: Database Verification

### Check After Complete Flow
```javascript
// Booking document should have:
db.bookings.findOne({ _id: bookingId })
/* Should contain:
{
  userId: ObjectId("..."),
  driverId: ObjectId("..."),
  status: "COMPLETED",
  notifiedDriverIds: [ObjectId("..."), ObjectId("...")],
  assignedAt: ISODate("..."),
  driverArrivedAt: ISODate("..."),
  pickedAt: ISODate("..."),
  completedAt: ISODate("..."),
  otp: "1234",
  finalFare: 150
}
*/

// User document:
db.users.findOne({ _id: userId })
/* Should have:
{
  fcmToken: "fcm_token_here",
  deviceType: "android",
  deviceModel: "Samsung S21",
  deviceId: "device_id_here",
  appVersion: "1.0.0"
}
*/

// Driver document:
db.drivers.findOne({ _id: driverId })
/* Should have:
{
  fcmToken: "fcm_token_here",
  deviceType: "android",
  currentBookingId: null, // cleared after completion
  isOnline: true,
  totalRides: incremented
}
*/
```

---

## 📊 Performance Tests

### Test 9.1: Load Test - Many Drivers
- [ ] Create 10+ driver accounts
- [ ] All online in same area
- [ ] Customer creates booking
- [ ] **Verify:**
  - All drivers notified within 2 seconds
  - No socket events lost
  - Backend handles load smoothly

### Test 9.2: Rapid Bookings
- [ ] Create 5 bookings rapidly (1 per second)
- [ ] **Verify:**
  - All bookings created successfully
  - Drivers notified for each
  - No race conditions

---

## ✅ Success Criteria

**All tests pass if:**

✅ **Authentication:**
- FCM tokens captured for 100% of logins
- Device info stored correctly

✅ **Online Drivers:**
- Receive socket events within 1 second
- Ride request popup appears immediately

✅ **Offline Drivers:**
- Receive FCM push within 5 seconds
- Notification tappable and navigates correctly

✅ **Multiple Drivers (CRITICAL):**
- All receive requests simultaneously
- When one accepts, others get "ride_taken" immediately
- No duplicate assignments

✅ **Ride Flow:**
- Complete flow works: create → assign → arrive → start → complete
- Customer and driver always in sync
- OTP verification works

✅ **Edge Cases:**
- Reconnection works automatically
- Cancellations handled gracefully
- No duplicate bookings

---

## 🐛 Bug Report Template

If any test fails, report with:

```
**Test:** [Test number and name]
**Expected:** [What should happen]
**Actual:** [What happened]
**Steps:**
1. Step 1
2. Step 2
3. ...

**Logs:**
[Backend logs]
[Flutter logs]

**Environment:**
- Device: [Android/iOS, Model]
- App version: [Version]
- Backend: [URL]
```

---

## 📈 Performance Benchmarks

**Target Metrics:**
- Socket event delivery: < 1 second
- FCM delivery: < 5 seconds
- Booking creation: < 2 seconds
- Location update frequency: 5 seconds
- ride_taken notification: < 1 second

**Monitor:**
- Socket connection stability
- FCM delivery rate (should be > 95%)
- Database query performance
- API response times

---

## ✨ Final Verification

Before marking as complete:

- [ ] All 50+ test cases pass
- [ ] No console errors in backend
- [ ] No crashes in Flutter apps
- [ ] Database has correct data structure
- [ ] Firebase console shows message delivery
- [ ] Socket events logged properly
- [ ] Multiple driver scenario works flawlessly
- [ ] Performance benchmarks met

**Status:** Ready for production after all tests ✅
