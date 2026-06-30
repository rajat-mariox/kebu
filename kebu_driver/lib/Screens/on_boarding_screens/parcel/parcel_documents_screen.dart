import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_address_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';

/// Parcel Delivery onboarding — Step 3: Documents (Aadhar + PAN).
class ParcelDocumentsScreen extends StatefulWidget {
  const ParcelDocumentsScreen({super.key});

  @override
  State<ParcelDocumentsScreen> createState() => _ParcelDocumentsScreenState();
}

class _ParcelDocumentsScreenState extends State<ParcelDocumentsScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(Rxn<File> target) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      target.value = File(image.path);
    }
  }

  Future<void> _saveAndContinue() async {
    final aadharError =
        Validators.validateAadhar(_controller.aadharNumberController.text);
    if (aadharError != null) {
      showCustomToast(context, aadharError);
      return;
    }
    if (_controller.aadharFrontImage.value == null) {
      showCustomToast(context, "Please upload front side of Aadhar card.");
      return;
    }
    if (_controller.aadharBackImage.value == null) {
      showCustomToast(context, "Please upload back side of Aadhar card.");
      return;
    }

    final panError =
        Validators.validatePAN(_controller.panNumberController.text);
    if (panError != null) {
      showCustomToast(context, panError);
      return;
    }
    if (_controller.panFrontImage.value == null) {
      showCustomToast(context, "Please upload front side of PAN card.");
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveDocuments(
      aadharNumber: _controller.aadharNumberController.text.trim(),
      aadharFrontImage: _controller.aadharFrontImage.value!,
      aadharBackImage: _controller.aadharBackImage.value!,
      panNumber: _controller.panNumberController.text.trim(),
      panFrontImage: _controller.panFrontImage.value!,
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const ParcelAddressScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save document details.');
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
        title: 'Profile',
        onSave: _saveAndContinue,
      ),
      bottomNavigationBar: Obx(() => ParcelBottomBar(
            onNext: _controller.isLoading.value ? null : _saveAndContinue,
          )),
      body: Column(
        children: [
          const ParcelStepper(currentStep: 2),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    parcelSectionDivider("Aadhar Card"),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.aadharNumberController,
                      label: "Aadhar Card Number",
                      hint: "Enter aadhar card number",
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    Obx(() => parcelUploadBox(
                          label: "Front Side of Card",
                          file: _controller.aadharFrontImage.value,
                          onTap: () => _pickImage(_controller.aadharFrontImage),
                        )),
                    const SizedBox(height: 20),
                    Obx(() => parcelUploadBox(
                          label: "Back Side of Card",
                          file: _controller.aadharBackImage.value,
                          onTap: () => _pickImage(_controller.aadharBackImage),
                        )),
                    const SizedBox(height: 28),
                    parcelSectionDivider("PAN Card"),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.panNumberController,
                      label: "PAN Card Number",
                      hint: "Enter PAN card number",
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 20),
                    Obx(() => parcelUploadBox(
                          label: "Front Side of PAN",
                          file: _controller.panFrontImage.value,
                          onTap: () => _pickImage(_controller.panFrontImage),
                        )),
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
