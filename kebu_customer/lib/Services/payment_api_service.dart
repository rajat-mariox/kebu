import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

class PaymentApiService {
  /// POST /payment/order
  static Future<ApiResponse> createPaymentOrder({
    required double amount,
    required String type,
    String? referenceId,
  }) async {
    return await ApiClient.post('/payment/order', body: {
      'amount': amount,
      'type': type,
      if (referenceId != null) 'referenceId': referenceId,
    });
  }

  /// POST /payment/verify
  static Future<ApiResponse> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String type,
    String? referenceId,
    double? amount,
  }) async {
    return await ApiClient.post('/payment/verify', body: {
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'type': type,
      if (referenceId != null) 'referenceId': referenceId,
      if (amount != null) 'amount': amount,
    });
  }

  /// GET /payment/:paymentId
  static Future<ApiResponse> getPaymentDetails(String paymentId) async {
    return await ApiClient.get('/payment/$paymentId');
  }

  /// POST /payment/link
  static Future<ApiResponse> createPaymentLink({
    required double amount,
    required String description,
    String? bookingId,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'description': description,
    };
    if (bookingId != null) body['bookingId'] = bookingId;
    return await ApiClient.post('/payment/link', body: body);
  }
}
