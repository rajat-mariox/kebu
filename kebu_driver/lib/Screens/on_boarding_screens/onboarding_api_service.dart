import 'dart:io';
import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class OnboardingApiService {
  static Future<ApiResponse> saveBasicDetails({
    required String name,
    required String email,
    required String dateOfBirth,
    required String gender,
    required String bloodGroup,
    required String emergencyContact,
    String serviceType = '',
  }) async {
    return ApiClient.post('/driver/app/onboarding/basic-details', body: {
      'name': name,
      'email': email,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'emergencyContact': emergencyContact,
      if (serviceType.isNotEmpty) 'serviceType': serviceType,
    });
  }

  static Future<ApiResponse> saveDrivingLicence({
    required String licenceNumber,
    required String issueDate,
    required String expiryDate,
    required File frontImage,
    required File backImage,
  }) async {
    return ApiClient.multipart(
      '/driver/app/onboarding/driving-licence',
      fields: {
        'licenceNumber': licenceNumber,
        'issueDate': issueDate,
        'expiryDate': expiryDate,
      },
      files: {
        'frontImage': frontImage,
        'backImage': backImage,
      },
    );
  }

  static Future<ApiResponse> saveDocuments({
    required String aadharNumber,
    required File aadharFrontImage,
    required File aadharBackImage,
    required String panNumber,
    required File panFrontImage,
  }) async {
    return ApiClient.multipart(
      '/driver/app/onboarding/documents',
      fields: {
        'aadharNumber': aadharNumber,
        'panNumber': panNumber,
      },
      files: {
        'aadharFrontImage': aadharFrontImage,
        'aadharBackImage': aadharBackImage,
        'panFrontImage': panFrontImage,
      },
    );
  }

  static Future<ApiResponse> saveAddress({
    required String address,
    required String apartment,
    required String state,
    required String city,
    required String country,
    required String zipCode,
  }) async {
    return ApiClient.post('/driver/app/onboarding/address', body: {
      'address': address,
      'apartment': apartment,
      'state': state,
      'city': city,
      'country': country,
      'zipCode': zipCode,
    });
  }

  static Future<ApiResponse> saveBankDetails({
    required String bank,
    required String accountNumber,
    required String ifscCode,
  }) async {
    return ApiClient.post('/driver/app/onboarding/bank-details', body: {
      'bank': bank,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
    });
  }

  static Future<ApiResponse> saveVehicleDetails({
    required String vehicleTypeId,
    required String registrationNumber,
  }) async {
    return ApiClient.post('/driver/app/onboarding/vehicle-details', body: {
      'vehicleTypeId': vehicleTypeId,
      'registrationNumber': registrationNumber,
    });
  }

  static Future<ApiResponse> getOnboardingServiceCategories() async {
    return ApiClient.get('/driver/app/onboarding/service-categories');
  }

  /// Household partner onboarding — fetch the backend-driven "Personal Details"
  /// form schema (fields, dropdown options) plus any already-saved values.
  static Future<ApiResponse> getHouseholdPersonalInfo() async {
    return ApiClient.get('/driver/app/onboarding/household/personal-info');
  }

  /// Household partner onboarding — save the "Personal Details" step.
  static Future<ApiResponse> saveHouseholdPersonalInfo({
    required Map<String, dynamic> body,
  }) async {
    return ApiClient.post(
      '/driver/app/onboarding/household/personal-info',
      body: body,
    );
  }

  /// Household partner onboarding — fetch the backend-driven "Address" form
  /// schema (current + permanent address sections) plus any saved values.
  static Future<ApiResponse> getHouseholdAddress() async {
    return ApiClient.get('/driver/app/onboarding/household/address');
  }

  /// Household partner onboarding — save the "Address" step.
  static Future<ApiResponse> saveHouseholdAddress({
    required Map<String, dynamic> body,
  }) async {
    return ApiClient.post(
      '/driver/app/onboarding/household/address',
      body: body,
    );
  }

  /// Household partner onboarding — fetch the backend-driven "Work Details" form
  /// schema plus the live service category tree (for cascading dropdowns).
  static Future<ApiResponse> getHouseholdWorkDetails() async {
    return ApiClient.get('/driver/app/onboarding/household/work-details');
  }

  /// Household partner onboarding — save the "Work Details" step.
  static Future<ApiResponse> saveHouseholdWorkDetails({
    required Map<String, dynamic> body,
  }) async {
    return ApiClient.post(
      '/driver/app/onboarding/household/work-details',
      body: body,
    );
  }

  /// Household partner onboarding — fetch the backend-driven "Bank Details" form
  /// schema (final step) plus any saved values.
  static Future<ApiResponse> getHouseholdBankDetails() async {
    return ApiClient.get('/driver/app/onboarding/household/bank-details');
  }

  /// Household partner onboarding — save the "Bank Details" step (final step).
  static Future<ApiResponse> saveHouseholdBankDetails({
    required Map<String, dynamic> body,
  }) async {
    return ApiClient.post(
      '/driver/app/onboarding/household/bank-details',
      body: body,
    );
  }

  static Future<ApiResponse> saveOnboardingServiceCategories({
    required List<String> categoryIds,
  }) async {
    return ApiClient.post(
      '/driver/app/onboarding/service-categories',
      body: {'categoryIds': categoryIds},
    );
  }

  static Future<ApiResponse> uploadVehicleImages({
    required File selfieImage,
    required File frontImage,
    required File rightImage,
    required File leftImage,
    required File backImage,
  }) async {
    return ApiClient.multipart(
      '/driver/app/onboarding/vehicle-images',
      files: {
        'selfieImage': selfieImage,
        'frontImage': frontImage,
        'rightImage': rightImage,
        'leftImage': leftImage,
        'backImage': backImage,
      },
    );
  }
}
