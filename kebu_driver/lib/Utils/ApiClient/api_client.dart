import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kebu_driver/Utils/ApiClient/api_config.dart';
import 'package:kebu_driver/Utils/PrefsManager/prefs_manager.dart';

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

  static Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(auth: auth),
        body: body != null ? json.encode(body) : null,
      ).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('API POST Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool auth = true,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response =
          await http.get(uri, headers: _headers(auth: auth)).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('API GET Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(auth: auth),
        body: body != null ? json.encode(body) : null,
      ).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('API PUT Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(auth: auth),
        body: body != null ? json.encode(body) : null,
      ).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('API PATCH Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static Future<ApiResponse> multipart(
    String endpoint, {
    Map<String, String>? fields,
    Map<String, File>? files,
    bool auth = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      if (auth && Prefs.auth_token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${Prefs.auth_token}';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (files != null) {
        for (final entry in files.entries) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value.path),
          );
        }
      }

      // Uploads carry image payloads, so allow a more generous ceiling than
      // the plain JSON requests — but still bounded so a dead server can't hang.
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('API Multipart Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  static ApiResponse _handleResponse(http.Response response) {
    debugPrint('API Response [${response.statusCode}]: ${response.body}');
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final responseCode = data['code'];
      final successCode = responseCode == 1 || responseCode == 200;

      return ApiResponse(
        success: response.statusCode == 200 && successCode,
        statusCode: response.statusCode,
        message: data['message']?.toString() ?? '',
        data: data['data'],
      );
    } catch (_) {
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
