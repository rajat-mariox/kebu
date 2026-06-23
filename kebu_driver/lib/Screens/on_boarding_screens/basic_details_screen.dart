import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/CommonWidgets/edit_text_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/aadhar_card_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/driving_licence_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';



class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
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
    // Validate all fields
    final nameError = Validators.validateName(_controller.nameController.text);
    if (nameError != null) {
      showCustomToast(context, nameError);
      return;
    }

    final emailError = Validators.validateEmail(_controller.emailController.text);
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

    final phoneError = Validators.validatePhone(_controller.emergencyContactController.text);
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
      // Cleaning vendors skip the driving licence step.
      if (_controller.serviceType.value == 'cleaning') {
        pushTo(context, const AadharCardOnboardingScreen());
      } else {
        pushTo(context, const DrivingLicenceScreen());
      }
    } else {
      showCustomToast(context, res.message ?? 'Failed to save basic details.');
    }
  }

  @override
  Widget build(BuildContext context) {

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
      )
    );

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Container(
        height: 82,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Column(
          children: [
            const SizedBox(height: 15,),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Obx(() => ButtonWidget(
                onTap: _controller.isLoading.value ? null : _saveAndContinue,
                borderRadius: BorderRadius.circular(8),
                text: _controller.isLoading.value ? "Saving..." : "Save & Continue",
                textColor: HexColor("#000000"),
                backgroundColor: HexColor("#A2BF49"),
              )),
            ),
            const SizedBox(height: 15,),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            commonAppBar(
                height : 110,
                context : context,
                child: Container(
                  padding: const EdgeInsets.only(top: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () { Navigator.pop(context); },
                        child: Container(
                          padding: const EdgeInsets.only(left: 16),
                          width: 40, height: 35, alignment: Alignment.center,
                          child: Image.asset("assets/back_arrow.png", color: HexColor("#000000"),),
                        ),
                      ),
                      const SizedBox(width: 6,),
                      Text("OnBoarding", style: TextStyle(color: HexColor("#000000"), fontSize: 17, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text("save", style: TextStyle(color: HexColor("#000000"), fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15,)
                    ],
                  ),
                )
            ),

            const SizedBox(height: 25,),
            Image.asset('assets/basic_details_sc.png'),

            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 17,),
                  _sectionHeader("BASIC DETAILS"),
                  const SizedBox(height: 17,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.nameController, hintText: "Enter driver name", isOptional: false, labelText: "Driver Name")
                  ),
                  const SizedBox(height: 14,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.emailController, hintText: "Enter email address", isOptional: false, labelText: "Email Address")
                  ),
                  const SizedBox(height: 14,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: editTextWidget(
                            context: context,
                            controller: _controller.dobController,
                            hintText: "Select date of birth",
                            isOptional: false,
                            labelText: "Date of Birth",
                            suffixIcon: const Icon(Icons.calendar_month),
                          ),
                        ),
                      )
                  ),
                  const SizedBox(height: 14,),

                  Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 10,),
                      _genderOption("Male"),
                      const SizedBox(width: 30,),
                      _genderOption("Female"),
                      const SizedBox(width: 30,),
                      _genderOption("Other"),
                      const SizedBox(width: 50,),
                    ],
                  )),
                  const SizedBox(height: 10,),

                  Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Obx(() => DropdownButton<String>(
                      underline: const SizedBox.shrink(),
                      hint: const Text("Select blood group"),
                      style: const TextStyle(color: Colors.black),
                      padding: const EdgeInsets.only(left: 15, right: 15),
                      value: _controller.selectedBloodGroup.value,
                      items: _controller.bloodGroups.map((group) => DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      )).toList(),
                      onChanged: (value) {
                        _controller.selectedBloodGroup.value = value;
                      },
                    )),
                  ),
                  const SizedBox(height: 14,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.emergencyContactController, hintText: "Enter 10-digit number", isOptional: false, labelText: "Emergency Contact Number")
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20,),
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
          const SizedBox(width: 16,),
          Expanded(child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 10,),
          Text(title, style: const TextStyle(color: Colors.black, fontSize: 13)),
          const SizedBox(width: 10,),
          Expanded(child: Container(height: 1, color: HexColor("#E1E6EF"))),
          const SizedBox(width: 16,),
        ],
      ),
    );
  }

  Widget _genderOption(String gender) {
    final isSelected = _controller.selectedGender.value == gender;
    return InkWell(
      onTap: () { _controller.selectedGender.value = gender; },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: isSelected ? Colors.black : Colors.grey),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Container(
              height: 8, width: 8,
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(width: 10,),
          Text(gender, style: const TextStyle(fontSize: 15, color: Colors.black)),
        ],
      ),
    );
  }
}
