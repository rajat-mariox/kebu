import 'dart:convert';

OtpResponse otpResponseFromJson(String str) => OtpResponse.fromJson(json.decode(str));

class OtpResponse {
  int? code;
  String? message;
  Data? data;

  OtpResponse({this.code, this.message, this.data});

  OtpResponse.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  String? token;
  String? userId;

  Data({this.token, this.userId});

  Data.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    userId = json['userId'];
  }

}
