import 'dart:io';

import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class DriverApiResult {
  final bool success;
  final String message;
  final dynamic data;

  DriverApiResult({
    required this.success,
    required this.message,
    this.data,
  });
}

class DriverApiService {
  static Future<DriverApiResult> getDashboard() async {
    final response = await ApiClient.get('/driver/app/dashboard');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Household (cleaning) partner home dashboard — backend-driven aggregate of
  /// stats, monthly revenue chart, booking tabs and reviews.
  static Future<DriverApiResult> getHouseholdDashboard() async {
    final response = await ApiClient.get('/driver/app/household/dashboard');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> toggleStatus() async {
    final response = await ApiClient.put('/driver/app/status');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> updateLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) async {
    final response = await ApiClient.put('/driver/app/location', body: {
      'latitude': lat,
      'longitude': lng,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    });
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> getActiveBooking() async {
    final response = await ApiClient.get('/driver/app/booking/active');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Fetch a single booking by id. Used by the cancellation deep-link
  /// detail screen and the buzzer screen when opened from a push tap.
  static Future<DriverApiResult> getBookingById(String bookingId) async {
    final response =
        await ApiClient.get('/driver/app/booking/$bookingId');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> getBookingHistory({
    int page = 0,
    int limit = 20,
  }) async {
    final response = await ApiClient.get('/driver/app/bookings', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> acceptBooking(String bookingId) async {
    final response = await ApiClient.post('/driver/app/booking/$bookingId/accept');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> acceptServiceBooking(String bookingId) async {
    final response = await ApiClient.post('/household/booking/$bookingId/accept');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Available (PENDING, unassigned) service bookings the driver can accept —
  /// a reliable poll fallback for the live socket broadcast.
  static Future<DriverApiResult> getAvailableServiceBookings() async {
    final response = await ApiClient.get('/household/booking/available');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Full detail (accept-shaped) of a booking the driver is handling, so an
  /// in-progress job can be re-opened from the "On Going" list.
  static Future<DriverApiResult> getServiceBookingDetail(String bookingId) async {
    final response =
        await ApiClient.get('/household/booking/$bookingId/provider-detail');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Driving route between two points — returns the Google-encoded `polyline`
  /// (the shortest road path), plus `distanceKm` / `durationMin`. Used to draw
  /// the partner→customer route flow on the en-route map.
  static Future<DriverApiResult> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final response = await ApiClient.get('/driver/app/route', queryParams: {
      'originLat': originLat.toString(),
      'originLng': originLng.toString(),
      'destLat': destLat.toString(),
      'destLng': destLng.toString(),
    });
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Confirm collected payment (cash) — marks the booking PAID.
  static Future<DriverApiResult> markServicePaymentReceived(
      String bookingId) async {
    final response =
        await ApiClient.post('/household/booking/$bookingId/payment-received');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Cancel a household booking the driver is handling.
  static Future<DriverApiResult> cancelServiceBooking(String bookingId,
      {String? reason}) async {
    final response = await ApiClient.post(
      '/household/booking/$bookingId/provider-cancel',
      body: {if (reason != null) 'reason': reason},
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Provider uploads the start-of-service photos and starts the service
  /// (marks the booking IN_PROGRESS). Selfie, device photo and serial-number
  /// photo are required; [otherPhoto] is optional.
  static Future<DriverApiResult> startServiceBooking({
    required String bookingId,
    required File selfie,
    required File devicePhoto,
    required File serialPhoto,
    File? otherPhoto,
  }) async {
    final response = await ApiClient.multipart(
      '/household/booking/$bookingId/start',
      files: {
        'selfie': selfie,
        'devicePhoto': devicePhoto,
        'serialPhoto': serialPhoto,
        if (otherPhoto != null) 'otherPhoto': otherPhoto,
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Provider updates the booking's extra charge while the work is in progress.
  static Future<DriverApiResult> updateBookingExtraAmount({
    required String bookingId,
    required double extraAmount,
    String? extraReason,
  }) async {
    final response = await ApiClient.put(
      '/household/booking/$bookingId/extra-amount',
      body: {
        'extraAmount': extraAmount,
        if (extraReason != null && extraReason.isNotEmpty)
          'extraAmountReason': extraReason,
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Provider ends the work — uploads the finished-work photo (+ optional extra
  /// amount) and marks the booking COMPLETED.
  static Future<DriverApiResult> completeServiceBooking({
    required String bookingId,
    required File finishedPhoto,
    double? extraAmount,
    String? extraReason,
  }) async {
    final response = await ApiClient.multipart(
      '/household/booking/$bookingId/complete',
      fields: {
        if (extraAmount != null && extraAmount > 0)
          'extraAmount': extraAmount.toString(),
        if (extraReason != null && extraReason.isNotEmpty)
          'extraAmountReason': extraReason,
      },
      files: {'finishedPhoto': finishedPhoto},
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Provider updates a household booking's live status while handling it
  /// (PROVIDER_EN_ROUTE / PROVIDER_ARRIVED / IN_PROGRESS / COMPLETED).
  static Future<DriverApiResult> updateServiceBookingStatus({
    required String bookingId,
    required String status,
    String? otp,
  }) async {
    final response = await ApiClient.put(
      '/household/booking/$bookingId/provider-status',
      body: {
        'status': status,
        if (otp != null && otp.isNotEmpty) 'otp': otp,
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> updateBookingStatus({
    required String bookingId,
    required String status,
    String? otp,
    String? reason,
  }) async {
    final response = await ApiClient.put(
      '/driver/app/booking/$bookingId/status',
      body: {
        'status': status,
        if (otp != null) 'otp': otp,
        if (reason != null) 'reason': reason,
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final response = await ApiClient.put(
      '/driver/app/booking/$bookingId/cancel',
      body: {
        if (reason != null) 'reason': reason,
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> getEarnings({
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final response = await ApiClient.get(
      '/driver/app/earnings',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> getVehicle() async {
    final response = await ApiClient.get('/driver/app/vehicle');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// The authenticated partner's profile (name, phone, avatar) for the profile
  /// drawer — `{ fullName, mobileNumber, countryCode, profileImage, ... }`.
  static Future<DriverApiResult> getDriverProfile() async {
    final response = await ApiClient.get('/driver/app/profile');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> uploadProfileImage(File imageFile) async {
    final response = await ApiClient.multipart(
      '/driver/app/profile-image',
      files: {'profileImage': imageFile},
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await ApiClient.get('/driver/app/notifications', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> markNotificationRead(String notificationId) async {
    final response =
        await ApiClient.put('/driver/app/notifications/$notificationId/read');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> markAllNotificationsRead() async {
    final response =
        await ApiClient.put('/driver/app/notifications/all/read');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  // ─────────────── Parcel delivery ───────────────

  /// Parcel partner home dashboard — backend-driven aggregate of partner info,
  /// available balance and the list of incoming/available delivery requests.
  static Future<DriverApiResult> getParcelDashboard() async {
    final response = await ApiClient.get('/driver/app/delivery/dashboard');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Available (SEARCHING, unassigned) parcel requests near the driver — a
  /// reliable poll fallback for the live `new_delivery_request` socket event.
  static Future<DriverApiResult> getAvailableDeliveries() async {
    final response = await ApiClient.get('/driver/app/delivery/available');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Partner's parcel delivery history, grouped into date sections.
  static Future<DriverApiResult> getDeliveryHistory() async {
    final response = await ApiClient.get('/driver/app/delivery/history');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Full backend-driven detail of a single parcel request (detail screen).
  static Future<DriverApiResult> getDeliveryDetail(String deliveryId) async {
    final response =
        await ApiClient.get('/driver/app/delivery/$deliveryId/detail');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Accept a parcel delivery request (SEARCHING → ASSIGNED).
  static Future<DriverApiResult> acceptDelivery(String deliveryId) async {
    final response =
        await ApiClient.post('/driver/app/delivery/$deliveryId/accept');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Advance a parcel delivery the partner is handling
  /// (PICKED_UP / IN_TRANSIT / DELIVERED).
  static Future<DriverApiResult> updateDeliveryStatus(
      String deliveryId, String status) async {
    final response = await ApiClient.put(
      '/driver/app/delivery/$deliveryId/status',
      body: {'status': status},
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Reject/dismiss a parcel delivery request.
  static Future<DriverApiResult> rejectDelivery(String deliveryId) async {
    final response =
        await ApiClient.post('/driver/app/delivery/$deliveryId/reject');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  // ─────────────── Wallet ───────────────

  static Future<DriverApiResult> getWallet() async {
    final response = await ApiClient.get('/driver/app/wallet');
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  /// Fetch wallet transactions. Pass `type: 'CREDIT'` for received amounts,
  /// `type: 'DEBIT'` for sent. Omit for the full statement.
  static Future<DriverApiResult> getWalletTransactions({
    String? type,
    int page = 0,
    int limit = 50,
  }) async {
    final response = await ApiClient.get(
      '/driver/app/wallet/transactions',
      queryParams: {
        if (type != null) 'type': type,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> rechargeWallet(double amount) async {
    final response = await ApiClient.post(
      '/driver/app/wallet/recharge',
      body: {'amount': amount},
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }

  static Future<DriverApiResult> sendFromWallet({
    required double amount,
    String? description,
  }) async {
    final response = await ApiClient.post(
      '/driver/app/wallet/send',
      body: {
        'amount': amount,
        if (description != null) 'description': description,
      },
    );
    return DriverApiResult(
      success: response.success,
      message: response.message ?? '',
      data: response.data,
    );
  }
}
