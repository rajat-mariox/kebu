import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_documents_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';

/// Parcel Delivery onboarding — Step 2: Driving Licence (DL Details).
class ParcelDrivingLicenceScreen extends StatefulWidget {
  const ParcelDrivingLicenceScreen({super.key});

  @override
  State<ParcelDrivingLicenceScreen> createState() =>
      _ParcelDrivingLicenceScreenState();
}

class _ParcelDrivingLicenceScreenState
    extends State<ParcelDrivingLicenceScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _pickImage(Rxn<File> target) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      target.value = File(image.path);
    }
  }

  Future<void> _saveAndContinue() async {
    final dlError =
        Validators.validateDrivingLicence(_controller.dlNumberController.text);
    if (dlError != null) {
      showCustomToast(context, dlError);
      return;
    }
    final issueDateError = Validators.validateDate(
        _controller.dlIssueDateController.text,
        fieldName: "Issue date");
    if (issueDateError != null) {
      showCustomToast(context, issueDateError);
      return;
    }
    final expiryDateError = Validators.validateDate(
        _controller.dlExpiryDateController.text,
        fieldName: "Expiry date");
    if (expiryDateError != null) {
      showCustomToast(context, expiryDateError);
      return;
    }
    if (_controller.dlFrontImage.value == null) {
      showCustomToast(context, "Please upload front side of license.");
      return;
    }
    if (_controller.dlBackImage.value == null) {
      showCustomToast(context, "Please upload back side of license.");
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveDrivingLicence(
      licenceNumber: _controller.dlNumberController.text.trim(),
      issueDate: _controller.dlIssueDateController.text.trim(),
      expiryDate: _controller.dlExpiryDateController.text.trim(),
      frontImage: _controller.dlFrontImage.value!,
      backImage: _controller.dlBackImage.value!,
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const ParcelDocumentsScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save driving licence.');
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
          const ParcelStepper(currentStep: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    parcelSectionDivider("Driving License"),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.dlNumberController,
                      label: "Driving License Number",
                      hint: "Enter driving license number",
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: parcelInput(
                            controller: _controller.dlIssueDateController,
                            label: "Issue Date",
                            hint: "DD/MM/YYYY",
                            readOnly: true,
                            onTap: () =>
                                _pickDate(_controller.dlIssueDateController),
                            suffixIcon: Icon(Icons.calendar_today_outlined,
                                size: 18, color: ParcelColors.labelDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: parcelInput(
                            controller: _controller.dlExpiryDateController,
                            label: "Expiry Date",
                            hint: "DD/MM/YYYY",
                            readOnly: true,
                            onTap: () =>
                                _pickDate(_controller.dlExpiryDateController),
                            suffixIcon: Icon(Icons.calendar_today_outlined,
                                size: 18, color: ParcelColors.labelDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Obx(() => parcelUploadBox(
                          label: "Front Side of Card",
                          file: _controller.dlFrontImage.value,
                          onTap: () => _pickImage(_controller.dlFrontImage),
                        )),
                    const SizedBox(height: 20),
                    Obx(() => parcelUploadBox(
                          label: "Back Side of Card",
                          file: _controller.dlBackImage.value,
                          onTap: () => _pickImage(_controller.dlBackImage),
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
