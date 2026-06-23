import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

class HouseholdApiService {
  /// GET /services/categories
  static Future<ApiResponse> getCategories() async {
    return await ApiClient.get('/services/categories', auth: false);
  }

  /// GET /services/service-hours
  static Future<ApiResponse> getServiceHours() async {
    return await ApiClient.get('/services/service-hours', auth: false);
  }

  /// GET /services/booking-types — admin-configured pricing for Single/Multiple
  static Future<ApiResponse> getBookingTypeConfigs() async {
    return await ApiClient.get('/services/booking-types', auth: false);
  }

  /// GET /services/categories/:categoryId/providers
  static Future<ApiResponse> getProvidersByCategory(String categoryId, {int page = 0, int limit = 20}) async {
    return await ApiClient.get('/services/categories/$categoryId/providers', auth: false, queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
  }

  /// GET /services/active-experts — count of online experts near a location
  static Future<ApiResponse> getActiveExperts({
    required double lat,
    required double lng,
    double maxDistanceKm = 10,
    String? categoryId,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'maxDistanceKm': maxDistanceKm.toString(),
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['categoryId'] = categoryId;
    }
    return await ApiClient.get('/services/active-experts',
        auth: false, queryParams: queryParams);
  }

  /// POST /services/providers/nearby
  static Future<ApiResponse> findNearbyProviders({
    required String categoryId,
    required double lat,
    required double lng,
    double maxDistanceKm = 10,
  }) async {
    return await ApiClient.post('/services/providers/nearby', body: {
      'categoryId': categoryId,
      'lat': lat,
      'lng': lng,
      'maxDistanceKm': maxDistanceKm,
    });
  }

  /// GET /services/providers/:providerId
  static Future<ApiResponse> getProviderDetails(String providerId) async {
    return await ApiClient.get('/services/providers/$providerId', auth: false);
  }

  /// POST /services/booking
  static Future<ApiResponse> createBooking({
    required String categoryId,
    String? providerId,
    required String serviceType,
    String? description,
    required String preferredDate,
    required String preferredTimeSlot,
    required Map<String, dynamic> address,
    double? estimatedCost,
    String paymentMethod = 'CASH',
    String? userNotes,
    String? promoCode,
  }) async {
    final body = <String, dynamic>{
      'categoryId': categoryId,
      'serviceType': serviceType,
      'preferredDate': preferredDate,
      'preferredTimeSlot': preferredTimeSlot,
      'address': address,
      'paymentMethod': paymentMethod,
    };
    if (providerId != null) body['providerId'] = providerId;
    if (description != null) body['description'] = description;
    if (estimatedCost != null) body['estimatedCost'] = estimatedCost;
    if (userNotes != null) body['userNotes'] = userNotes;
    if (promoCode != null && promoCode.isNotEmpty) body['promoCode'] = promoCode;
    return await ApiClient.post('/services/booking', body: body);
  }

  /// GET /services/booking/active
  static Future<ApiResponse> getActiveBooking() async {
    return await ApiClient.get('/services/booking/active');
  }

  /// GET /services/bookings
  static Future<ApiResponse> getUserBookings({int page = 0, int limit = 10, String? status}) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;
    return await ApiClient.get('/services/bookings', queryParams: queryParams);
  }

  /// GET /services/booking/:bookingId
  static Future<ApiResponse> getBookingDetails(String bookingId) async {
    return await ApiClient.get('/services/booking/$bookingId');
  }

  /// PUT /services/booking/:bookingId/cancel
  static Future<ApiResponse> cancelBooking(String bookingId, {String? reason}) async {
    return await ApiClient.put('/services/booking/$bookingId/cancel', body: {
      if (reason != null) 'reason': reason,
    });
  }

  /// POST /services/booking/:bookingId/rate
  static Future<ApiResponse> rateService(String bookingId, {required int rating, String? feedback}) async {
    return await ApiClient.post('/services/booking/$bookingId/rate', body: {
      'rating': rating,
      if (feedback != null) 'feedback': feedback,
    });
  }

  /// GET /services/categories/:categoryId/packages
  static Future<ApiResponse> getServicePackages(String categoryId, {String? date}) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    return await ApiClient.get('/services/categories/$categoryId/packages', auth: false, queryParams: queryParams);
  }

  /// GET /services/categories/:categoryId/time-slots
  static Future<ApiResponse> getAvailableTimeSlots(String categoryId, {String? date}) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    return await ApiClient.get('/services/categories/$categoryId/time-slots', auth: false, queryParams: queryParams);
  }

  /// GET /services/categories/:categoryId/service-types
  static Future<ApiResponse> getServiceTypes(String categoryId) async {
    return await ApiClient.get('/services/categories/$categoryId/service-types', auth: false);
  }

  /// GET /services/categories/:categoryId/service-types/:serviceSlug
  static Future<ApiResponse> getServiceTypeDetails(String categoryId, String serviceSlug) async {
    return await ApiClient.get('/services/categories/$categoryId/service-types/$serviceSlug', auth: false);
  }

  /// GET /services/categories/:categoryId/available-dates
  static Future<ApiResponse> getAvailableDates(String categoryId, {String? startDate, String? endDate}) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    return await ApiClient.get('/services/categories/$categoryId/available-dates', queryParams: queryParams);
  }

  /// POST /services/booking/estimate
  static Future<ApiResponse> getBookingEstimate({
    required String packageId,
    int totalSessions = 1,
    String? promoCode,
  }) async {
    final body = <String, dynamic>{
      'packageId': packageId,
      'totalSessions': totalSessions,
    };
    if (promoCode != null) body['promoCode'] = promoCode;
    return await ApiClient.post('/services/booking/estimate', body: body);
  }

  /// POST /services/booking/multiple
  static Future<ApiResponse> createMultipleBooking({
    required String categoryId,
    required String serviceType,
    String? packageId,
    String bookingType = 'SINGLE',
    required String startDate,
    String? endDate,
    List<String>? selectedDates,
    int? durationMinutes,
    required String timeSlot,
    String? timeSlotType,
    required Map<String, dynamic> address,
    String? promoCode,
    String paymentMethod = 'CASH',
    bool useSubscription = false,
  }) async {
    final body = <String, dynamic>{
      'categoryId': categoryId,
      'serviceType': serviceType,
      'bookingType': bookingType,
      'startDate': startDate,
      'timeSlot': timeSlot,
      'address': address,
      'paymentMethod': paymentMethod,
      'useSubscription': useSubscription,
    };
    if (packageId != null) body['packageId'] = packageId;
    if (endDate != null) body['endDate'] = endDate;
    if (selectedDates != null) body['selectedDates'] = selectedDates;
    if (durationMinutes != null) body['durationMinutes'] = durationMinutes;
    if (timeSlotType != null) body['timeSlotType'] = timeSlotType;
    if (promoCode != null) body['promoCode'] = promoCode;
    return await ApiClient.post('/services/booking/multiple', body: body);
  }

  /// GET /services/categories/:categoryId/starter-packs
  static Future<ApiResponse> getStarterPacks(String categoryId) async {
    return await ApiClient.get('/services/categories/$categoryId/starter-packs', auth: false);
  }
}
