import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_driving_licence_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';

/// Parcel Delivery onboarding — Step 1: Basic Details.
/// Mirrors the cab driver Basic Details screen but uses the pink Figma design.
class ParcelBasicDetailsScreen extends StatefulWidget {
  const ParcelBasicDetailsScreen({super.key});

  @override
  State<ParcelBasicDetailsScreen> createState() =>
      _ParcelBasicDetailsScreenState();
}

class _ParcelBasicDetailsScreenState extends State<ParcelBasicDetailsScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _controller.dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _saveAndContinue() async {
    final nameError = Validators.validateName(_controller.nameController.text);
    if (nameError != null) {
      showCustomToast(context, nameError);
      return;
    }

    final emailError =
        Validators.validateEmail(_controller.emailController.text);
    if (emailError != null) {
      showCustomToast(context, emailError);
      return;
    }

    final dobError = Validators.validateDOB(_controller.dobController.text);
    if (dobError != null) {
      showCustomToast(context, dobError);
      return;
    }

    if (_controller.selectedGender.value.isEmpty) {
      showCustomToast(context, "Please select gender.");
      return;
    }

    if (_controller.selectedBloodGroup.value == null) {
      showCustomToast(context, "Please select blood group.");
      return;
    }

    final phoneError =
        Validators.validatePhone(_controller.emergencyContactController.text);
    if (phoneError != null) {
      showCustomToast(context, "Emergency contact: $phoneError");
      return;
    }

    _controller.isLoading.value = true;
    final res = await OnboardingApiService.saveBasicDetails(
      name: _controller.nameController.text.trim(),
      email: _controller.emailController.text.trim(),
      dateOfBirth: _controller.dobController.text.trim(),
      gender: _controller.selectedGender.value,
      bloodGroup: _controller.selectedBloodGroup.value ?? '',
      emergencyContact: _controller.emergencyContactController.text.trim(),
      serviceType: _controller.serviceType.value,
    );
    _controller.isLoading.value = false;

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const ParcelDrivingLicenceScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save basic details.');
    }
  }

  void _showBloodGroupSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Select Blood Group",
                    style: GoogleFonts.nunito(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _controller.bloodGroups
                      .map(
                        (group) => ListTile(
                          title: Text(group,
                              style: GoogleFonts.nunito(fontSize: 15)),
                          onTap: () {
                            _controller.selectedBloodGroup.value = group;
                            Navigator.pop(ctx);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
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
          const ParcelStepper(currentStep: 0),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    parcelSectionDivider("Basic Details"),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.nameController,
                      label: "Driver Name",
                      hint: "Enter driver name",
                    ),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.emailController,
                      label: "Email Address",
                      hint: "Enter email address",
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.dobController,
                      label: "Date of Birth",
                      hint: "Select birth of date",
                      readOnly: true,
                      onTap: _pickDate,
                      suffixIcon: Icon(Icons.calendar_today_outlined,
                          size: 18, color: ParcelColors.labelDark),
                    ),
                    const SizedBox(height: 20),
                    parcelFieldLabel("Select Gender", required: false),
                    const SizedBox(height: 4),
                    Obx(() => Row(
                          children: [
                            _genderOption("Male"),
                            const SizedBox(width: 40),
                            _genderOption("Female"),
                            const SizedBox(width: 40),
                            _genderOption("Other"),
                          ],
                        )),
                    const SizedBox(height: 20),
                    Obx(() => parcelSelector(
                          label: "Blood Group",
                          value: _controller.selectedBloodGroup.value ?? '',
                          placeholder: "Select blood group",
                          onTap: _showBloodGroupSelector,
                        )),
                    const SizedBox(height: 20),
                    parcelInput(
                      controller: _controller.emergencyContactController,
                      label: "Emergency Contact Number",
                      hint: "Enter number",
                      keyboardType: TextInputType.phone,
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

  Widget _genderOption(String gender) {
    final isSelected = _controller.selectedGender.value == gender;
    return InkWell(
      onTap: () => _controller.selectedGender.value = gender,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? ParcelColors.primary : ParcelColors.hint,
                width: 1.5,
              ),
            ),
            child: Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? ParcelColors.primary : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(gender,
              style: GoogleFonts.nunito(
                  fontSize: 15, color: ParcelColors.labelDark)),
        ],
      ),
    );
  }
}
