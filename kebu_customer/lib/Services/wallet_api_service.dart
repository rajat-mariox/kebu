import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

class WalletApiService {
  /// POST /wallet/add
  static Future<ApiResponse> addToWallet({required double amount, required String referenceId}) async {
    return await ApiClient.post('/wallet/add', body: {
      'amount': amount,
      'referenceId': referenceId,
    });
  }

  /// GET /wallet
  static Future<ApiResponse> getWallet() async {
    return await ApiClient.get('/wallet');
  }
}
