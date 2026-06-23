import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

class BookingApiService {
  /// POST /booking/fare-estimate
  static Future<ApiResponse> getFareEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    required String vehicleTypeId,
  }) async {
    return await ApiClient.post('/booking/fare-estimate', body: {
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'vehicleTypeId': vehicleTypeId,
    });
  }

  /// POST /booking/fare-estimates (all vehicle types)
  static Future<ApiResponse> getAllFareEstimates({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) async {
    return await ApiClient.post('/booking/fare-estimates', body: {
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropLat': dropLat,
      'dropLng': dropLng,
    });
  }

  /// POST /booking
  static Future<ApiResponse> createBooking({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropAddress,
    required double dropLat,
    required double dropLng,
    required String vehicleTypeId,
    String paymentMethod = 'CASH',
    String? scheduledAt,
    String? promoCode,
    String? riderId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
  }) async {
    final body = <String, dynamic>{
      'pickupAddress': pickupAddress,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropAddress': dropAddress,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'vehicleTypeId': vehicleTypeId,
      'paymentMethod': paymentMethod,
    };
    if (scheduledAt != null) body['scheduledAt'] = scheduledAt;
    if (promoCode != null && promoCode.isNotEmpty) body['promoCode'] = promoCode;
    if (riderId != null && riderId.isNotEmpty) body['riderId'] = riderId;
    if (razorpayOrderId != null) body['razorpay_order_id'] = razorpayOrderId;
    if (razorpayPaymentId != null) body['razorpay_payment_id'] = razorpayPaymentId;
    if (razorpaySignature != null) body['razorpay_signature'] = razorpaySignature;
    return await ApiClient.post('/booking', body: body);
  }

  /// GET /booking/active
  static Future<ApiResponse> getActiveBooking() async {
    return await ApiClient.get('/booking/active');
  }

  /// GET /booking/nearby-drivers
  static Future<ApiResponse> getNearbyDrivers({required double lat, required double lng, double maxDistance = 5}) async {
    return await ApiClient.get('/booking/nearby-drivers', queryParams: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'maxDistance': maxDistance.toString(),
    });
  }

  /// GET /booking/history
  static Future<ApiResponse> getBookingHistory({int page = 0, int limit = 10, String? status}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;
    return await ApiClient.get('/booking/history', queryParams: queryParams);
  }

  /// GET /booking/:bookingId
  static Future<ApiResponse> getBookingDetails(String bookingId) async {
    return await ApiClient.get('/booking/$bookingId');
  }

  /// GET /booking/:bookingId/track
  static Future<ApiResponse> trackBooking(String bookingId) async {
    return await ApiClient.get('/booking/$bookingId/track');
  }

  /// PUT /booking/:bookingId/cancel
  static Future<ApiResponse> cancelBooking(String bookingId, {String? reason}) async {
    return await ApiClient.put('/booking/$bookingId/cancel', body: {
      if (reason != null) 'reason': reason,
    });
  }

  /// POST /booking/:bookingId/rate
  static Future<ApiResponse> rateBooking(String bookingId, {required int rating, String? feedback}) async {
    return await ApiClient.post('/booking/$bookingId/rate', body: {
      'rating': rating,
      if (feedback != null) 'feedback': feedback,
    });
  }
}
