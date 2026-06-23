import 'package:get/get.dart';

class HouseholdBookingController extends GetxController {
  // Selected category
  final categoryId = ''.obs;
  final categoryName = ''.obs;

  // Selected service type
  final serviceType = ''.obs;

  // Selected package (duration) — pricing flows from the backend packages API
  final packageId = ''.obs;
  final packageName = ''.obs;
  final servicePrice = 0.0.obs;
  final serviceOriginalPrice = 0.0.obs;
  final durationMinutes = 0.obs;

  // Selected date & time
  final selectedDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>(); // multiple-booking range end
  final selectedTimeSlot = ''.obs;
  final selectedDuration = ''.obs;

  // Selected address
  final selectedAddress = ''.obs;
  final addressLabel = ''.obs;
  final selectedLat = 0.0.obs;
  final selectedLng = 0.0.obs;

  // Payment
  final paymentMethod = 'online'.obs;

  void setCategory(String id, String name) {
    categoryId.value = id;
    categoryName.value = name;
  }

  void setServiceType(String type) {
    serviceType.value = type;
  }

  void setPackage({
    required String id,
    required String name,
    required double price,
    double? originalPrice,
    int? minutes,
  }) {
    packageId.value = id;
    packageName.value = name;
    servicePrice.value = price;
    serviceOriginalPrice.value = originalPrice ?? price;
    if (minutes != null) durationMinutes.value = minutes;
  }

  void setAddressLabel(String label) {
    addressLabel.value = label;
  }

  void setDate(DateTime date) {
    selectedDate.value = date;
  }

  void setDateRange(DateTime start, DateTime? end) {
    selectedDate.value = start;
    endDate.value = end;
  }

  void setTimeSlot(String slot) {
    selectedTimeSlot.value = slot;
  }

  void setDuration(String duration) {
    selectedDuration.value = duration;
  }

  void setAddress(String address, double lat, double lng) {
    selectedAddress.value = address;
    selectedLat.value = lat;
    selectedLng.value = lng;
  }

  void setPaymentMethod(String method) {
    paymentMethod.value = method;
  }

  void reset() {
    categoryId.value = '';
    categoryName.value = '';
    serviceType.value = '';
    packageId.value = '';
    packageName.value = '';
    servicePrice.value = 0.0;
    serviceOriginalPrice.value = 0.0;
    durationMinutes.value = 0;
    selectedDate.value = null;
    endDate.value = null;
    selectedTimeSlot.value = '';
    selectedDuration.value = '';
    selectedAddress.value = '';
    addressLabel.value = '';
    selectedLat.value = 0.0;
    selectedLng.value = 0.0;
    paymentMethod.value = 'online';
  }
}
