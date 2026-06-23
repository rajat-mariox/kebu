import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kebu_customer/Utils/ApiClient/api_config.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';

class ApiClient {
  static const String baseUrl = ApiConfig.baseUrl;

  static Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && Prefs.auth_token.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${Prefs.auth_token}';
    }
    return headers;
  }

  static Future<ApiResponse> get(String endpoint, {bool auth = true, Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse("$baseUrl$endpoint");
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _headers(auth: auth));
      return _handleResponse(response);
    } catch (e) {
      debugPrint("API GET Error: $e");
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> post(String endpoint, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(auth: auth),
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint("API POST Error: $e");
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> put(String endpoint, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(auth: auth),
        body: body != null ? json.encode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint("API PUT Error: $e");
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> delete(String endpoint, {bool auth = true}) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(auth: auth),
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint("API DELETE Error: $e");
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static ApiResponse _handleResponse(http.Response response) {
    debugPrint("API Response [${response.statusCode}]: ${response.body}");
    try {
      final data = json.decode(response.body);
      return ApiResponse(
        success: response.statusCode == 200 && (data['code'] == 1 || data['code'] == 200),
        statusCode: response.statusCode,
        message: data['message'] ?? '',
        data: data['data'],
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: 'Failed to parse response',
      );
    }
  }
}

class ApiResponse {
  final bool success;
  final int? statusCode;
  final String? message;
  final dynamic data;

  ApiResponse({
    required this.success,
    this.statusCode,
    this.message,
    this.data,
  });
}
