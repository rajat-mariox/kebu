import 'package:kebu_driver/Utils/ApiClient/api_client.dart';
import 'package:kebu_driver/Services/fcm_notification_service.dart';

class OtpApiResult {
  final int code;
  final String message;
  final String token;
  final String userId;
  final String status;
  final String serviceType;
  final int onboardingStep;
  final bool isNewDriver;

  OtpApiResult({
    required this.code,
    required this.message,
    required this.token,
    required this.userId,
    this.status = '',
    this.serviceType = '',
    this.onboardingStep = 0,
    this.isNewDriver = true,
  });
}

class OtpApiService {
  Future<OtpApiResult> otpVerifyApi({
    required String otp,
    required String txnId,
  }) async {
    // Get FCM token and device info
    final fcm = FCMNotificationService();
    final deviceInfo = await fcm.getDeviceInfo();
    
    final response = await ApiClient.post('/driver/verify-otp', body: {
      'txnId': txnId,
      'otp': otp,
      'fcmToken': fcm.fcmToken ?? '',
      'deviceType': deviceInfo['deviceType'] ?? '',
      'deviceModel': deviceInfo['deviceModel'] ?? '',
      'deviceId': deviceInfo['deviceId'] ?? '',
      'appVersion': deviceInfo['appVersion'] ?? '',
    }, auth: false);

    final data = (response.data is Map<String, dynamic>)
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};

    return OtpApiResult(
      code: response.success ? 200 : (response.statusCode ?? 400),
      message: response.message ?? '',
      token: data['token']?.toString() ?? '',
      userId: data['driverId']?.toString() ?? data['userId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      serviceType: data['serviceType']?.toString() ?? '',
      onboardingStep: int.tryParse(data['onboardingStep']?.toString() ?? '0') ?? 0,
      isNewDriver: data['isNewDriver'] == true,
    );
  }
}
