import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/app_bar.dart';
import 'package:kebu_driver/CommonWidgets/button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/VerificationScreen/verification_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

class VehicleImagesScreen extends StatefulWidget {
  const VehicleImagesScreen({super.key});

  @override
  State<VehicleImagesScreen> createState() => _VehicleImagesScreenState();
}

class _VehicleImagesScreenState extends State<VehicleImagesScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  File? _selfieImage;
  File? _frontImage;
  File? _rightImage;
  File? _leftImage;
  File? _backImage;

  Future<void> _pickImage(String field) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      switch (field) {
        case 'selfie':
          _selfieImage = File(picked.path);
          break;
        case 'front':
          _frontImage = File(picked.path);
          break;
        case 'right':
          _rightImage = File(picked.path);
          break;
        case 'left':
          _leftImage = File(picked.path);
          break;
        case 'back':
          _backImage = File(picked.path);
          break;
      }
    });
  }

  Future<void> _uploadAndContinue() async {
    if (_selfieImage == null ||
        _frontImage == null ||
        _rightImage == null ||
        _leftImage == null ||
        _backImage == null) {
      showCustomToast(context, "Please upload all 5 required images.");
      return;
    }

    setState(() => _isLoading = true);

    final res = await OnboardingApiService.uploadVehicleImages(
      selfieImage: _selfieImage!,
      frontImage: _frontImage!,
      rightImage: _rightImage!,
      leftImage: _leftImage!,
      backImage: _backImage!,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res.success) {
      pushTo(context, const VerificationScreen());
    } else {
      showCustomToast(context, res.message ?? 'Failed to upload images.');
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
              child: ButtonWidget(
                onTap: _isLoading ? null : _uploadAndContinue,
                borderRadius: BorderRadius.circular(8),
                text: _isLoading ? "Uploading..." : "Upload",
                textColor: HexColor("#000000"),
                backgroundColor: HexColor("#A2BF49"),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            commonAppBar(
              height: 110,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 50),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
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
                    Text("Vehicle Image",
                        style: TextStyle(
                            color: HexColor("#000000"),
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // Required Imagery banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: HexColor("#FFD546"),
              child: const Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Required Imagery",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: "*",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Image grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Row 1: Selfie + Front
                  Row(
                    children: [
                      Expanded(
                        child: _imagePickerCard(
                          label: "Face and T-Shirt Selfie",
                          placeholder: "assets/selfie_placeholder.png",
                          file: _selfieImage,
                          onTap: () => _pickImage('selfie'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _imagePickerCard(
                          label: "Front Side of Car/Bike",
                          placeholder: "assets/car_front_placeholder.png",
                          file: _frontImage,
                          onTap: () => _pickImage('front'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Right + Left
                  Row(
                    children: [
                      Expanded(
                        child: _imagePickerCard(
                          label: "Right Side of Car/Bike",
                          placeholder: "assets/car_right_placeholder.png",
                          file: _rightImage,
                          onTap: () => _pickImage('right'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _imagePickerCard(
                          label: "Left Side of Car/Bike",
                          placeholder: "assets/car_left_placeholder.png",
                          file: _leftImage,
                          onTap: () => _pickImage('left'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 3: Back
                  Row(
                    children: [
                      Expanded(
                        child: _imagePickerCard(
                          label: "Back Side of Car/Bike",
                          placeholder: "assets/car_back_placeholder.png",
                          file: _backImage,
                          onTap: () => _pickImage('back'),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerCard({
    required String label,
    required String placeholder,
    required File? file,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const TextSpan(
                text: "*",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: file != null
                    ? HexColor("#4CAF50")
                    : HexColor("#E1E6EF"),
                width: file != null ? 2 : 1,
              ),
              color: HexColor("#F8FAFC"),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: file != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle,
                                color: HexColor("#4CAF50"), size: 20),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo,
                              size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text("Tap to upload",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
