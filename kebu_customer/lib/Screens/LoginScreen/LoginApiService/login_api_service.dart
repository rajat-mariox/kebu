import 'package:kebu_customer/Screens/LoginScreen/Model/login_response.dart';
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';


class LoginApiService {
  Future<LoginResponse> loginApi(String mobileNumber) async {

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
}