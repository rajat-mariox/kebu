import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

class DeliveryApiService {
  /// GET /delivery/vehicle-types
  static Future<ApiResponse> getVehicleTypes() async {
    return await ApiClient.get('/delivery/vehicle-types');
  }

  /// POST /delivery/fare-estimate
  static Future<ApiResponse> getFareEstimate({
    required Map<String, dynamic> pickup,
    required List<Map<String, dynamic>> drops,
    required String vehicleTypeId,
  }) async {
    return await ApiClient.post('/delivery/fare-estimate', body: {
      'pickup': pickup,
      'drops': drops,
      'vehicleTypeId': vehicleTypeId,
    });
  }

  /// POST /delivery
  static Future<ApiResponse> createDelivery({
    required Map<String, dynamic> pickup,
    required List<Map<String, dynamic>> drops,
    required String vehicleTypeId,
    String deliveryType = 'PARCEL',
    String deliveryMode = 'INSTANT',
    int workers = 0,
    String? packageDescription,
    String? packageWeight,
    String? packageSize,
    String paymentMethod = 'CASH',
    String proofOfDelivery = 'OTP',
    String? scheduledAt,
  }) async {
    final body = <String, dynamic>{
      'pickup': pickup,
      'drops': drops,
      'vehicleTypeId': vehicleTypeId,
      'deliveryType': deliveryType,
      'deliveryMode': deliveryMode,
      'workers': workers,
      'paymentMethod': paymentMethod,
      'proofOfDelivery': proofOfDelivery,
    };
    if (packageDescription != null) body['packageDescription'] = packageDescription;
    if (packageWeight != null) body['packageWeight'] = packageWeight;
    if (packageSize != null) body['packageSize'] = packageSize;
    if (scheduledAt != null) body['scheduledAt'] = scheduledAt;
    return await ApiClient.post('/delivery', body: body);
  }

  /// GET /delivery/active
  static Future<ApiResponse> getActiveDelivery() async {
    return await ApiClient.get('/delivery/active');
  }

  /// GET /delivery/history
  static Future<ApiResponse> getDeliveryHistory({int page = 0, int limit = 10}) async {
    return await ApiClient.get('/delivery/history', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
  }

  /// GET /delivery/:deliveryId
  static Future<ApiResponse> getDeliveryDetails(String deliveryId) async {
    return await ApiClient.get('/delivery/$deliveryId');
  }

  /// GET /delivery/:deliveryId/track
  static Future<ApiResponse> trackDelivery(String deliveryId) async {
    return await ApiClient.get('/delivery/$deliveryId/track');
  }

  /// PUT /delivery/:deliveryId/cancel
  static Future<ApiResponse> cancelDelivery(String deliveryId, {String? reason}) async {
    return await ApiClient.put('/delivery/$deliveryId/cancel', body: {
      if (reason != null) 'reason': reason,
    });
  }

  /// POST /delivery/:deliveryId/rate
  static Future<ApiResponse> rateDelivery(String deliveryId, {required int rating, String? feedback}) async {
    return await ApiClient.post('/delivery/$deliveryId/rate', body: {
      'rating': rating,
      if (feedback != null) 'feedback': feedback,
    });
  }
}
