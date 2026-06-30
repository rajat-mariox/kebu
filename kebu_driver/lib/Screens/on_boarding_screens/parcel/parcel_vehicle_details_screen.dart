import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_vehicle_images_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

/// Parcel Delivery onboarding — Step 6: Vehicle Details.
class ParcelVehicleDetailsScreen extends StatefulWidget {
  const ParcelVehicleDetailsScreen({super.key});

  @override
  State<ParcelVehicleDetailsScreen> createState() =>
      _ParcelVehicleDetailsScreenState();
}

class _ParcelVehicleDetailsScreenState
    extends State<ParcelVehicleDetailsScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();

  @override
  void initState() {
    super.initState();
    // Parcel partners only choose cargo vehicles (Cargo Bike / Pickup / Large
    // Truck), so restrict the selector to the CARGO category.
    _controller.fetchVehicleTypes(category: 'CARGO');
  }

  void _showVehicleTypeSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Select Vehicle Type",
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Obx(() {
                    if (_controller.vehicleTypes.isEmpty) {
                      return const Center(
                        child: Text("No vehicle types available",
                            style: TextStyle(color: Colors.grey)),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: _controller.vehicleTypes.length,
                      itemBuilder: (_, i) {
                        final vt = _controller.vehicleTypes[i];
                        final name = vt['name'] ?? '';
                        final category = vt['category'];
                        final categoryName =
                            category is Map ? (category['name'] ?? '') : '';
                        return ListTile(
                          title: Text(name,
                              style: GoogleFonts.nunito(fontSize: 15)),
                          subtitle: categoryName.isNotEmpty
                              ? Text(categoryName,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey))
                              : null,
                          onTap: () {
                            _controller.selectedVehicleTypeId.value =
                                vt['_id'] ?? '';
                            _controller.selectedVehicleTypeName.value = name;
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveAndContinue() async {
    if (_controller.selectedVehicleTypeId.value == null ||
        _controller.selectedVehicleTypeId.value!.isEmpty) {
      showCustomToast(context, "Please select a vehicle type.");
      return;
    }
    if (_controller.registrationNumberController.text.trim().isEmpty) {
      showCustomToast(context, "Please enter vehicle registration number.");
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveVehicleDetails(
      vehicleTypeId: _controller.selectedVehicleTypeId.value!,
      registrationNumber: _controller.registrationNumberController.text.trim(),
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const ParcelVehicleImagesScreen());
    } else {
      showCustomToast(
          context, res.message ?? 'Failed to save vehicle details.');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: ParcelColors.background,
      appBar: parcelHeader(
        context: context,
        title: 'Vehicle Details',
        onSave: _saveAndContinue,
      ),
      bottomNavigationBar: Obx(() => ParcelBottomBar(
            onNext: _controller.isLoading.value ? null : _saveAndContinue,
          )),
      body: Column(
        children: [
          // Past the 5 documented steps — show the stepper fully complete.
          const ParcelStepper(currentStep: 5),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    parcelSectionDivider("Vehicle Details"),
                    const SizedBox(height: 20),
                    Obx(() => parcelSelector(
                          label: "Vehicle Type",
                          value:
                              _controller.selectedVehicleTypeName.value ?? '',
                          placeholder: "-- Select Vehicle Type --",
                          onTap: _showVehicleTypeSelector,
                        )),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.registrationNumberController,
                      label: "Registration Number",
                      hint: "Enter registration number",
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
