import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/CommonWidgets/edit_text_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/aadhar_card_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';


class DrivingLicenceScreen extends StatefulWidget {
  const DrivingLicenceScreen({super.key});

  @override
  State<DrivingLicenceScreen> createState() => _DrivingLicenceScreenState();
}

class _DrivingLicenceScreenState extends State<DrivingLicenceScreen> {
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
    final dlError = Validators.validateDrivingLicence(_controller.dlNumberController.text);
    if (dlError != null) {
      showCustomToast(context, dlError);
      return;
    }
    final issueDateError = Validators.validateDate(_controller.dlIssueDateController.text, fieldName: "Issue date");
    if (issueDateError != null) {
      showCustomToast(context, issueDateError);
      return;
    }
    final expiryDateError = Validators.validateDate(_controller.dlExpiryDateController.text, fieldName: "Expiry date");
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
      pushTo(context, const AadharCardOnboardingScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save driving licence.');
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
            Image.asset('assets/dl_details_sc.png'),

            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 17,),
                  _sectionHeader("DRIVING LICENSE"),
                  const SizedBox(height: 17,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.dlNumberController, hintText: "Enter driving license number", isOptional: false, labelText: "Driving License Number")
                  ),

                  const SizedBox(height: 14,),

                  Row(
                    children: [
                      const SizedBox(width: 15,),
                      SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5 - 20,
                          child: GestureDetector(
                            onTap: () => _pickDate(_controller.dlIssueDateController),
                            child: AbsorbPointer(
                              child: editTextWidget(context: context, controller: _controller.dlIssueDateController, hintText: "DD/MM/YYYY", isOptional: false, labelText: "Issue Date", suffixIcon: const Icon(Icons.calendar_month)),
                            ),
                          )
                      ),
                      const SizedBox(width: 10,),
                      SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5 - 20,
                          child: GestureDetector(
                            onTap: () => _pickDate(_controller.dlExpiryDateController),
                            child: AbsorbPointer(
                              child: editTextWidget(context: context, controller: _controller.dlExpiryDateController, hintText: "DD/MM/YYYY", isOptional: false, labelText: "Expiry Date", suffixIcon: const Icon(Icons.calendar_month)),
                            ),
                          )
                      ),
                    ],
                  ),

                  const SizedBox(height: 14,),

                  _imageUploadSection("Front Side of Card", _controller.dlFrontImage, () => _pickImage(_controller.dlFrontImage)),

                  const SizedBox(height: 14,),

                  _imageUploadSection("Back Side of Card", _controller.dlBackImage, () => _pickImage(_controller.dlBackImage)),
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

  Widget _imageUploadSection(String label, Rxn<File> imageFile, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 18,),
            Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600))
            ),
            Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: const Text("*", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600))
            ),
          ],
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(left: 15, right: 15),
            child: Obx(() {
              if (imageFile.value != null) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(imageFile.value!, height: 120, width: double.infinity, fit: BoxFit.cover),
                );
              }
              return Image.asset(label.contains("Front") ? 'assets/front_side_upload_icon.png' : 'assets/back_side_upload_icon.png');
            }),
          ),
        ),
      ],
    );
  }
}
