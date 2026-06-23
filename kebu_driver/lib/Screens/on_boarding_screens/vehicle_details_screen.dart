import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/CommonWidgets/edit_text_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/vehicle_images_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();

  @override
  void initState() {
    super.initState();
    _controller.fetchVehicleTypes();
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
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Select Vehicle Type",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          title: Text(name),
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
      registrationNumber:
          _controller.registrationNumberController.text.trim(),
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const VehicleImagesScreen());
    } else {
      showCustomToast(
          context, res.message ?? 'Failed to save vehicle details.');
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Container(
        height: 82,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Obx(() => ButtonWidget(
                    onTap:
                        _controller.isLoading.value ? null : _saveAndContinue,
                    borderRadius: BorderRadius.circular(8),
                    text: _controller.isLoading.value
                        ? "Saving..."
                        : "Save & Continue",
                    textColor: HexColor("#000000"),
                    backgroundColor: HexColor("#A2BF49"),
                  )),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
              height: 110,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.only(left: 16),
                        width: 40,
                        height: 35,
                        alignment: Alignment.center,
                        child: Image.asset("assets/back_arrow.png",
                            color: HexColor("#000000")),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text("OnBoarding",
                        style: TextStyle(
                            color: HexColor("#000000"),
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text("save",
                        style: TextStyle(
                            color: HexColor("#000000"),
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Vehicle icon
            const Icon(Icons.directions_car_rounded,
                size: 80, color: Colors.grey),
            const SizedBox(height: 10),

            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 17),
                  _sectionHeader("VEHICLE DETAILS"),
                  const SizedBox(height: 17),

                  // Vehicle Type selector
                  Container(
                    margin: const EdgeInsets.only(left: 15, right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 3),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("Vehicle Type",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: const Text("*",
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _showVehicleTypeSelector,
                          child: Container(
                            height: 50,
                            padding:
                                const EdgeInsets.only(left: 15, right: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border:
                                  Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Obx(() => Text(
                                        _controller.selectedVehicleTypeName
                                                .value ??
                                            "-- Select Vehicle Type --",
                                        style: TextStyle(
                                            color: _controller
                                                        .selectedVehicleTypeName
                                                        .value !=
                                                    null
                                                ? Colors.black
                                                : Colors.grey,
                                            fontSize: 13),
                                      )),
                                ),
                                const Icon(Icons.arrow_drop_down_rounded,
                                    size: 35),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    margin: const EdgeInsets.only(left: 15, right: 15),
                    child: editTextWidget(
                      context: context,
                      controller:
                          _controller.registrationNumberController,
                      hintText: "Enter registration number",
                      isOptional: false,
                      labelText: "Registration Number",
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
              child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 10),
          Text(title,
              style:
                  const TextStyle(color: Colors.black, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
              child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
