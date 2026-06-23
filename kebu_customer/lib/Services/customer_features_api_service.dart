import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

class CustomerFeaturesApiService {
  // ============ SCRATCH CARDS ============

  /// GET /customer/scratch-cards
  static Future<ApiResponse> getScratchCards() async {
    return await ApiClient.get('/customer/scratch-cards');
  }

  /// POST /customer/scratch-cards/:cardId/scratch
  static Future<ApiResponse> scratchCard(String cardId) async {
    return await ApiClient.post('/customer/scratch-cards/$cardId/scratch');
  }

  // ============ OFFERS ============

  /// GET /customer/offers
  static Future<ApiResponse> getOffers({String? type}) async {
    final queryParams = <String, String>{};
    if (type != null) queryParams['type'] = type;
    return await ApiClient.get('/customer/offers', queryParams: queryParams);
  }

  /// POST /customer/offers/apply
  static Future<ApiResponse> applyPromoCode({
    required String code,
    required String orderType,
    required double orderAmount,
  }) async {
    return await ApiClient.post('/customer/offers/apply', body: {
      'code': code,
      'orderType': orderType,
      'orderAmount': orderAmount,
    });
  }

  // ============ SUBSCRIPTION ============

  /// GET /customer/subscription/plans
  static Future<ApiResponse> getSubscriptionPlans() async {
    return await ApiClient.get('/customer/subscription/plans');
  }

  /// GET /customer/subscription
  static Future<ApiResponse> getMySubscription() async {
    return await ApiClient.get('/customer/subscription');
  }

  /// POST /customer/subscription
  static Future<ApiResponse> subscribeToPlan({
    required String planId,
    String? paymentId,
    bool isTrial = false,
  }) async {
    return await ApiClient.post('/customer/subscription', body: {
      'planId': planId,
      if (paymentId != null) 'paymentId': paymentId,
      'isTrial': isTrial,
    });
  }

  // ============ REFERRAL ============

  /// GET /customer/referral
  static Future<ApiResponse> getReferralInfo() async {
    return await ApiClient.get('/customer/referral');
  }

  /// POST /customer/referral/apply
  static Future<ApiResponse> applyReferralCode(String referralCode) async {
    return await ApiClient.post('/customer/referral/apply', body: {
      'referralCode': referralCode,
    });
  }

  // ============ NOTIFICATIONS ============

  /// GET /customer/notifications
  static Future<ApiResponse> getNotifications({int page = 1, int limit = 20}) async {
    return await ApiClient.get('/customer/notifications', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
  }

  /// PUT /customer/notifications/:notificationId/read
  static Future<ApiResponse> markNotificationRead(String notificationId) async {
    return await ApiClient.put('/customer/notifications/$notificationId/read');
  }

  /// Mark all notifications as read
  static Future<ApiResponse> markAllNotificationsRead() async {
    return await ApiClient.put('/customer/notifications/all/read');
  }

  // ============ FAQ ============

  /// GET /customer/faq
  static Future<ApiResponse> getFAQs({String? category}) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;
    return await ApiClient.get('/customer/faq', auth: false, queryParams: queryParams);
  }

  // ============ SUPPORT ============

  /// POST /customer/support/tickets
  static Future<ApiResponse> createSupportTicket({
    required String subject,
    required String description,
    String? category,
    String? bookingId,
  }) async {
    final body = <String, dynamic>{
      'subject': subject,
      'description': description,
    };
    if (category != null) body['category'] = category;
    if (bookingId != null) body['bookingId'] = bookingId;
    return await ApiClient.post('/customer/support/tickets', body: body);
  }

  /// GET /customer/support/tickets
  static Future<ApiResponse> getSupportTickets() async {
    return await ApiClient.get('/customer/support/tickets');
  }

  /// GET /customer/support/tickets/:ticketId
  static Future<ApiResponse> getTicketDetails(String ticketId) async {
    return await ApiClient.get('/customer/support/tickets/$ticketId');
  }

  /// POST /customer/support/tickets/:ticketId/message
  static Future<ApiResponse> addTicketMessage(String ticketId, String message) async {
    return await ApiClient.post('/customer/support/tickets/$ticketId/message', body: {
      'message': message,
    });
  }

  // ============ PAYMENT METHODS ============

  /// GET /customer/payment-methods
  static Future<ApiResponse> getPaymentMethods() async {
    return await ApiClient.get('/customer/payment-methods');
  }

  /// POST /customer/payment-methods
  static Future<ApiResponse> addPaymentMethod(Map<String, dynamic> data) async {
    return await ApiClient.post('/customer/payment-methods', body: data);
  }

  /// DELETE /customer/payment-methods/:methodId
  static Future<ApiResponse> deletePaymentMethod(String methodId) async {
    return await ApiClient.delete('/customer/payment-methods/$methodId');
  }

  // ============ RIDERS ============

  /// GET /customer/riders
  static Future<ApiResponse> getRiders() async {
    return await ApiClient.get('/customer/riders');
  }

  /// POST /customer/riders
  static Future<ApiResponse> addRider(Map<String, dynamic> data) async {
    return await ApiClient.post('/customer/riders', body: data);
  }

  /// PUT /customer/riders/:riderId
  static Future<ApiResponse> updateRider(String riderId, Map<String, dynamic> data) async {
    return await ApiClient.put('/customer/riders/$riderId', body: data);
  }

  /// DELETE /customer/riders/:riderId
  static Future<ApiResponse> deleteRider(String riderId) async {
    return await ApiClient.delete('/customer/riders/$riderId');
  }

  // ============ TIP ============

  /// POST /customer/tip
  static Future<ApiResponse> addTip({required String bookingId, required double amount}) async {
    return await ApiClient.post('/customer/tip', body: {
      'bookingId': bookingId,
      'amount': amount,
    });
  }
}
