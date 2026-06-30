import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class OnboardingController extends GetxController {
  // ── Basic Details ──
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final dobController = TextEditingController();
  final emergencyContactController = TextEditingController();
  var selectedGender = ''.obs;
  var selectedBloodGroup = Rxn<String>();

  // ── Driving Licence ──
  final dlNumberController = TextEditingController();
  final dlIssueDateController = TextEditingController();
  final dlExpiryDateController = TextEditingController();
  var dlFrontImage = Rxn<File>();
  var dlBackImage = Rxn<File>();

  // ── Aadhar Card ──
  final aadharNumberController = TextEditingController();
  var aadharFrontImage = Rxn<File>();
  var aadharBackImage = Rxn<File>();

  // ── PAN Card ──
  final panNumberController = TextEditingController();
  var panFrontImage = Rxn<File>();

  // ── Address ──
  final addressController = TextEditingController();
  final apartmentController = TextEditingController();
  final zipCodeController = TextEditingController();
  var selectedState = Rxn<String>();
  var selectedCity = Rxn<String>();
  var selectedCountry = 'India'.obs;

  // ── Bank Details ──
  final accountNumberController = TextEditingController();
  final ifscCodeController = TextEditingController();
  var selectedBank = Rxn<String>();

  // ── Vehicle Details ──
  final registrationNumberController = TextEditingController();
  var selectedVehicleTypeId = Rxn<String>();
  var selectedVehicleTypeName = Rxn<String>();
  var vehicleTypes = <Map<String, dynamic>>[].obs;

  // ── Service type (cab, cleaning, parcel) ──
  var serviceType = ''.obs;

  // ── Cleaning Vendor: selected service categories (parent + subcategory IDs) ──
  var householdCategoryIds = <String>{}.obs;
  var householdCategoryTree = <Map<String, dynamic>>[].obs;
  var loadingCategories = false.obs;

  // ── Loading state ──
  var isLoading = false.obs;

  // ── State / City lists (can be fetched from API later) ──
  final states = <String>[
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
  ];

  final banks = <String>[
    'State Bank of India', 'HDFC Bank', 'ICICI Bank', 'Punjab National Bank',
    'Bank of Baroda', 'Canara Bank', 'Union Bank of India', 'Bank of India',
    'Indian Bank', 'Central Bank of India', 'Indian Overseas Bank',
    'UCO Bank', 'Kotak Mahindra Bank', 'Axis Bank', 'IDBI Bank',
    'Yes Bank', 'Federal Bank', 'IndusInd Bank', 'South Indian Bank',
  ];

  final bloodGroups = <String>['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];

  Map<String, dynamic> getBasicDetailsBody() {
    return {
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'dateOfBirth': dobController.text.trim(),
      'gender': selectedGender.value,
      'bloodGroup': selectedBloodGroup.value ?? '',
      'emergencyContact': emergencyContactController.text.trim(),
    };
  }

  Map<String, dynamic> getAddressBody() {
    return {
      'address': addressController.text.trim(),
      'apartment': apartmentController.text.trim(),
      'state': selectedState.value ?? '',
      'city': selectedCity.value ?? '',
      'country': selectedCountry.value,
      'zipCode': zipCodeController.text.trim(),
    };
  }

  Map<String, dynamic> getBankDetailsBody() {
    return {
      'bank': selectedBank.value ?? '',
      'accountNumber': accountNumberController.text.trim(),
      'ifscCode': ifscCodeController.text.trim(),
    };
  }

  /// Fetch vehicle types for the onboarding selector. Pass [category] (e.g.
  /// 'CARGO') to restrict the list — parcel partners only get cargo vehicles
  /// (Cargo Bike / Pickup / Large Truck); cab onboarding omits it.
  Future<void> fetchVehicleTypes({String? category}) async {
    try {
      final res = await ApiClient.get(
        '/driver/app/vehicle-types',
        queryParams: (category != null && category.isNotEmpty)
            ? {'category': category}
            : null,
      );
      if (res.success && res.data != null) {
        final list = res.data['vehicleTypes'] as List<dynamic>? ?? [];
        vehicleTypes.value = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Failed to fetch vehicle types: $e');
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    dobController.dispose();
    emergencyContactController.dispose();
    dlNumberController.dispose();
    dlIssueDateController.dispose();
    dlExpiryDateController.dispose();
    aadharNumberController.dispose();
    panNumberController.dispose();
    addressController.dispose();
    apartmentController.dispose();
    zipCodeController.dispose();
    accountNumberController.dispose();
    ifscCodeController.dispose();
    registrationNumberController.dispose();
    super.onClose();
  }
}
