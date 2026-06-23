import 'package:get/get.dart';
import 'package:kebu_driver/Screens/LoginScreen/LoginApiService/login_api_service.dart';
import 'package:kebu_driver/Screens/OtpScreen/OtpApiService/otp_api_service.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;

  final LoginApiService _loginApiService = LoginApiService();
  final OtpApiService _otpApiService = OtpApiService();

  Future<LoginApiResult> requestOtp(String mobileNumber) async {
    isLoading.value = true;
    try {
      return await _loginApiService.loginApi(mobileNumber);
    } finally {
      isLoading.value = false;
    }
  }

  Future<OtpApiResult> verifyOtp({
    required String otp,
    required String txnId,
    required String mobileNumber,
  }) async {
    isLoading.value = true;
    try {
      final response = await _otpApiService.otpVerifyApi(otp: otp, txnId: txnId);

      if (response.code == 200) {
        await Prefs.setBool('is_logged_in_new', true);
        await Prefs.setBool('check_log_in', true);
        await Prefs.setString('mobile_number', mobileNumber);
        await Prefs.setString('auth_token', response.token);
        await Prefs.setString('user_id', response.userId);
        Prefs.loadData();
      }

      return response;
    } finally {
      isLoading.value = false;
    }
  }
}
