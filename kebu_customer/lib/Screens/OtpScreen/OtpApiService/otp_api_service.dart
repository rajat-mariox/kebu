import 'package:flutter/foundation.dart';
import 'package:kebu_customer/Screens/LoginScreen/Model/login_response.dart';
import 'package:kebu_customer/Screens/OtpScreen/Model/otp_response.dart';
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';
import 'package:kebu_customer/Services/fcm_notification_service.dart';


class OtpApiService {
  Future<LoginResponse> resendOtp(String mobileNumber) async {

    var params = {
      "countryCode": "+91",
      "mobileNumber": mobileNumber
    };

    final response = await ApiClient.post('/auth/login', body: params, auth: false);

    final payload = <String, dynamic>{
      'code': response.success ? 200 : (response.statusCode ?? 400),
      'message': response.message ?? '',
      'data': response.data,
    };

    return LoginResponse.fromJson(payload);
  }

  Future<OtpResponse> verifyOtp({required String otp, required String token}) async {
    // Get FCM token and device info (graceful if Firebase not configured)
    String fcmToken = '';
    Map<String, String> deviceInfo = {};
    try {
      final fcm = FCMNotificationService();
      fcmToken = fcm.fcmToken ?? '';
      deviceInfo = await fcm.getDeviceInfo();
    } catch (e) {
      debugPrint('FCM not available: $e');
    }

    final response = await ApiClient.post('/auth/verifyOtp', body: {
      'txnId': token,
      'otp': otp,
      'fcmToken': fcmToken,
      'deviceType': deviceInfo['deviceType'] ?? '',
      'deviceModel': deviceInfo['deviceModel'] ?? '',
      'deviceId': deviceInfo['deviceId'] ?? '',
      'appVersion': deviceInfo['appVersion'] ?? '',
    }, auth: false);

    final payload = <String, dynamic>{
      'code': response.success ? 200 : (response.statusCode ?? 400),
      'message': response.message ?? '',
      'data': response.data,
    };

    return OtpResponse.fromJson(payload);
  }
}