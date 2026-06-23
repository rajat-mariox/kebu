import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class UserApiService {
  /// GET /user/profile
  static Future<ApiResponse> getProfile() async {
    return await ApiClient.get('/user/profile');
  }

  /// PUT /user/profile
  static Future<ApiResponse> updateProfile(Map<String, dynamic> data) async {
    return await ApiClient.put('/user/profile', body: data);
  }

  static Future<ApiResponse> getSocialAccounts() async {
    return await ApiClient.get('/user/social-accounts');
  }

  static Future<ApiResponse> linkSocialAccount(Map<String, dynamic> data) async {
    return await ApiClient.put('/user/social-accounts', body: data);
  }

  static Future<ApiResponse> unlinkSocialAccount(String provider) async {
    return await ApiClient.delete('/user/social-accounts/$provider');
  }

  static Future<ApiResponse> updateProfileWithImage({
    required Map<String, String> data,
    File? profileImage,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiClient.baseUrl}/user/profile'),
      );

      request.headers['Authorization'] = 'Bearer ${Prefs.auth_token}';
      request.fields.addAll(data);

      if (profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profileImage', profileImage.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      try {
        final decoded = json.decode(response.body);
        return ApiResponse(
          success: response.statusCode == 200 &&
              (decoded['code'] == 1 || decoded['code'] == 200),
          statusCode: response.statusCode,
          message: decoded['message'] ?? '',
          data: decoded['data'],
        );
      } catch (_) {
        return ApiResponse(
          success: false,
          statusCode: response.statusCode,
          message: 'Failed to parse response',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// POST /user/address
  static Future<ApiResponse> addAddress(Map<String, dynamic> data) async {
    return await ApiClient.post('/user/address', body: data);
  }

  /// GET /user/address
  static Future<ApiResponse> getAddresses() async {
    return await ApiClient.get('/user/address');
  }

  /// GET /user/address/:id
  static Future<ApiResponse> getAddressDetail(String id) async {
    return await ApiClient.get('/user/address/$id');
  }

  /// PUT /user/address/:id
  static Future<ApiResponse> updateAddress(String id, Map<String, dynamic> data) async {
    return await ApiClient.put('/user/address/$id', body: data);
  }

  /// DELETE /user/address/:id
  static Future<ApiResponse> deleteAddress(String id) async {
    return await ApiClient.delete('/user/address/$id');
  }

  /// GET /user/notifications/switch
  static Future<ApiResponse> toggleNotification() async {
    return await ApiClient.get('/user/notifications/switch');
  }

  /// POST /user/gst
  static Future<ApiResponse> addOrUpdateGST(Map<String, dynamic> data) async {
    return await ApiClient.post('/user/gst', body: data);
  }

  /// GET /user/gst
  static Future<ApiResponse> getGST() async {
    return await ApiClient.get('/user/gst');
  }

  /// GET /user/rewards
  static Future<ApiResponse> getRewards() async {
    return await ApiClient.get('/user/rewards');
  }
}
