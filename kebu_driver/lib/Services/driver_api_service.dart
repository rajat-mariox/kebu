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
