import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kebu_customer/Services/user_api_service.dart';
import 'package:kebu_customer/Services/maps_api_service.dart';

class AddressController extends GetxController {
  final RxList<Map<String, dynamic>> addresses = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  // Place search
  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxBool isSearching = false.obs;

  // Selected location for add/edit
  final RxString selectedAddress = ''.obs;
  final RxDouble selectedLat = 0.0.obs;
  final RxDouble selectedLng = 0.0.obs;

  // Reverse-geocoded address components
  final RxString reverseHouseNo = ''.obs;
  final RxString reverseArea = ''.obs;
  final RxString reverseCity = ''.obs;
  final RxString reverseState = ''.obs;
  final RxString reversePinCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    isLoading.value = true;
    final response = await UserApiService.getAddresses();
    if (response.success && response.data != null) {
      final list = response.data['addresses'] ??
          response.data['data'] ??
          response.data;
      if (list is List) {
        addresses.value = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        addresses.clear();
      }
    } else {
      addresses.clear();
    }
    isLoading.value = false;
  }

  Future<bool> addAddress({
    required String fullName,
    required String mobileNumber,
    required String houseNo,
    required String area,
    required String city,
    required String state,
    required int pinCode,
    required String addressType,
    double? latitude,
    double? longitude,
  }) async {
    isLoading.value = true;
    final response = await UserApiService.addAddress({
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'houseNo': houseNo,
      'area': area,
      'city': city,
      'state': state,
      'pinCode': pinCode,
      'addressType': addressType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    isLoading.value = false;

    if (response.success) {
      await loadAddresses();
      Fluttertoast.showToast(msg: 'Address added successfully');
      return true;
    }
    Fluttertoast.showToast(msg: response.message ?? 'Failed to add address');
    return false;
  }

  Future<bool> updateAddress({
    required String id,
    required String fullName,
    required String mobileNumber,
    required String houseNo,
    required String area,
    required String city,
    required String state,
    required int pinCode,
    required String addressType,
    double? latitude,
    double? longitude,
  }) async {
    isLoading.value = true;
    final response = await UserApiService.updateAddress(id, {
      'fullName': fullName,
      'mobileNumber': mobileNumber,
      'houseNo': houseNo,
      'area': area,
      'city': city,
      'state': state,
      'pinCode': pinCode,
      'addressType': addressType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    isLoading.value = false;

    if (response.success) {
      await loadAddresses();
      Fluttertoast.showToast(msg: 'Address updated successfully');
      return true;
    }
    Fluttertoast.showToast(msg: response.message ?? 'Failed to update address');
    return false;
  }

  Future<bool> deleteAddress(String id) async {
    isLoading.value = true;
    final response = await UserApiService.deleteAddress(id);
    isLoading.value = false;

    if (response.success) {
      addresses.removeWhere((a) => a['_id'] == id);
      Fluttertoast.showToast(msg: 'Address deleted');
      return true;
    }
    Fluttertoast.showToast(msg: response.message ?? 'Failed to delete address');
    return false;
  }

  Future<void> searchPlaces(String query) async {
    if (query.trim().length < 3) {
      searchResults.clear();
      return;
    }
    isSearching.value = true;
    final response = await MapsApiService.searchPlaces(query);
    if (response.success && response.data != null) {
      final predictions = response.data['predictions'] as List? ?? [];
      searchResults.value =
          predictions.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    }
    isSearching.value = false;
  }

  Future<bool> selectPlace(Map<String, dynamic> prediction) async {
    final placeId = prediction['placeId'] ?? '';
    final description = prediction['description'] ?? '';
    if (placeId.isEmpty) return false;

    final response = await MapsApiService.getPlaceDetails(placeId);
    if (response.success && response.data != null) {
      final place = response.data['place'] ?? response.data;
      final lat = (place['lat'] ?? 0).toDouble();
      final lng = (place['lng'] ?? 0).toDouble();
      selectedLat.value = lat;
      selectedLng.value = lng;
      selectedAddress.value = place['address'] ?? description;
      searchResults.clear();
      // Reverse geocode to fill address components
      await _reverseGeocodeLocation(lat, lng);
      return true;
    }
    return false;
  }

  /// Detect device current location and reverse geocode it
  Future<void> detectCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        if (!await Geolocator.isLocationServiceEnabled()) return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      if (permission == LocationPermission.denied) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      selectedLat.value = position.latitude;
      selectedLng.value = position.longitude;

      await _reverseGeocodeLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('AddressController: Error detecting location: $e');
    }
  }

  /// Reverse geocode coordinates and fill address component fields
  Future<void> _reverseGeocodeLocation(double lat, double lng) async {
    final response = await MapsApiService.reverseGeocode(lat: lat, lng: lng);
    if (response.success && response.data != null) {
      final data = response.data;
      selectedAddress.value = data['address'] ?? data['display_name'] ?? '';
      reverseHouseNo.value = data['houseNo'] ?? '';
      reverseArea.value = data['area'] ?? '';
      reverseCity.value = data['city'] ?? '';
      reverseState.value = data['state'] ?? '';
      reversePinCode.value = (data['pinCode'] ?? '').toString();
    }
  }

  void clearSearch() {
    searchResults.clear();
    isSearching.value = false;
  }

  void resetSelection() {
    selectedAddress.value = '';
    selectedLat.value = 0;
    selectedLng.value = 0;
    reverseHouseNo.value = '';
    reverseArea.value = '';
    reverseCity.value = '';
    reverseState.value = '';
    reversePinCode.value = '';
    searchResults.clear();
  }

  IconData getAddressTypeIcon(String type) {
    switch (type) {
      case 'Home':
        return Icons.home;
      case 'Work':
        return Icons.work;
      default:
        return Icons.location_on;
    }
  }
}
