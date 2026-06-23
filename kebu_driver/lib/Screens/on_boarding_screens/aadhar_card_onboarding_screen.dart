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
import 'package:kebu_driver/Screens/on_boarding_screens/address_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:kebu_driver/Utils/Validators/validators.dart';



class AadharCardOnboardingScreen extends StatefulWidget {
  const AadharCardOnboardingScreen({super.key});

  @override
  State<AadharCardOnboardingScreen> createState() => _AadharCardOnboardingScreenState();
}

class _AadharCardOnboardingScreenState extends State<AadharCardOnboardingScreen> {
  final OnboardingController _controller = Get.find<OnboardingController>();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(Rxn<File> target) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      target.value = File(image.path);
    }
  }

  Future<void> _saveAndContinue() async {
    // Validate Aadhar
    final aadharError = Validators.validateAadhar(_controller.aadharNumberController.text);
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

    // Validate PAN
    final panError = Validators.validatePAN(_controller.panNumberController.text);
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
      pushTo(context, const AddressOnboardingScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to save document details.');
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
            Image.asset('assets/documents_sc.png'),

            Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── AADHAR CARD SECTION ──
                  const SizedBox(height: 17,),
                  _sectionHeader("AADHAR CARD"),
                  const SizedBox(height: 17,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.aadharNumberController, hintText: "Enter aadhar card number", isOptional: false, labelText: "Aadhar Card Number")
                  ),

                  const SizedBox(height: 14,),

                  _imageUploadSection("Front Side of Card", _controller.aadharFrontImage, () => _pickImage(_controller.aadharFrontImage)),

                  const SizedBox(height: 14,),

                  _imageUploadSection("Back Side of Card", _controller.aadharBackImage, () => _pickImage(_controller.aadharBackImage)),

                  // ── PAN CARD SECTION ──
                  const SizedBox(height: 25,),
                  _sectionHeader("PAN CARD"),
                  const SizedBox(height: 17,),

                  Container(
                      margin: const EdgeInsets.only(left: 15, right: 15),
                      child: editTextWidget(context: context, controller: _controller.panNumberController, hintText: "Enter PAN card number", isOptional: false, labelText: "PAN Card Number")
                  ),

                  const SizedBox(height: 14,),

                  _imageUploadSection("Front Side of PAN", _controller.panFrontImage, () => _pickImage(_controller.panFrontImage)),
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
