import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class LoginApiResult {
  final int code;
  final String message;
  final String txnId;

  LoginApiResult({
    required this.code,
    required this.message,
    required this.txnId,
  });
}

class LoginApiService {
  Future<LoginApiResult> loginApi(String mobileNumber) async {

    var params = {
      "countryCode": "+91",
      "mobileNumber": mobileNumber
    };

    final response = await ApiClient.post('/driver/login', body: params, auth: false);
    final data = (response.data is Map<String, dynamic>)
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};

    return LoginApiResult(
      code: response.success ? 200 : (response.statusCode ?? 400),
      message: response.message ?? '',
      txnId: data['txnId']?.toString() ?? '',
    );
  }
}