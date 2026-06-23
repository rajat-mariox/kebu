import 'package:get/get.dart';
import 'package:kebu_customer/Screens/LoginScreen/LoginApiService/login_api_service.dart';
import 'package:kebu_customer/Screens/LoginScreen/Model/login_response.dart';
import 'package:kebu_customer/Screens/OtpScreen/Model/otp_response.dart';
import 'package:kebu_customer/Screens/OtpScreen/OtpApiService/otp_api_service.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;

  final LoginApiService _loginApiService = LoginApiService();
  final OtpApiService _otpApiService = OtpApiService();

  Future<LoginResponse> requestOtp(String mobileNumber) async {
    isLoading.value = true;
    try {
      return await _loginApiService.loginApi(mobileNumber);
    } finally {
      isLoading.value = false;
    }
  }

  Future<LoginResponse> resendOtp(String mobileNumber) async {
    isLoading.value = true;
    try {
      return await _otpApiService.resendOtp(mobileNumber);
    } finally {
      isLoading.value = false;
    }
  }

  Future<OtpResponse> verifyOtp({
    required String otp,
    required String mobileNumber,
    required String token,
  }) async {
    isLoading.value = true;
    try {
      final response = await _otpApiService.verifyOtp(otp: otp, token: token);

      if ((response.code ?? 0) == 200) {
        await Prefs.setBool('is_logged_in_new', true);
        await Prefs.setBool('check_log_in', true);
        await Prefs.setString('mobile_number', mobileNumber);
        await Prefs.setString('auth_token', response.data?.token ?? '');
        await Prefs.setString('user_id', response.data?.userId ?? '');
        Prefs.loadData();
      }

      return response;
    } finally {
      isLoading.value = false;
    }
  }
}
