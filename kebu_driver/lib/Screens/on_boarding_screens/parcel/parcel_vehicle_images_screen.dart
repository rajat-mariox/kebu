import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/VerificationScreen/verification_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_api_service.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/parcel/parcel_onboarding_widgets.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

/// Parcel Delivery onboarding — Step 7: Vehicle Images (final upload).
class ParcelVehicleImagesScreen extends StatefulWidget {
  const ParcelVehicleImagesScreen({super.key});

  @override
  State<ParcelVehicleImagesScreen> createState() =>
      _ParcelVehicleImagesScreenState();
}

class _ParcelVehicleImagesScreenState extends State<ParcelVehicleImagesScreen> {
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
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: ParcelColors.background,
      appBar: parcelHeader(context: context, title: 'Vehicle Image'),
      bottomNavigationBar: ParcelBottomBar(
        nextLabel: _isLoading ? 'Uploading...' : 'Upload',
        onNext: _isLoading ? null : _uploadAndContinue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Required Imagery banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: ParcelColors.primary.withValues(alpha: 0.10),
              child: Center(
                child: RichText(
                  text: TextSpan(
                    text: "Required Imagery",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ParcelColors.labelDark,
                    ),
                    children: [
                      TextSpan(
                        text: " *",
                        style: TextStyle(color: ParcelColors.asterisk),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _imagePickerCard(
                          label: "Face and T-Shirt Selfie",
                          file: _selfieImage,
                          onTap: () => _pickImage('selfie'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _imagePickerCard(
                          label: "Front Side of Car/Bike",
                          file: _frontImage,
                          onTap: () => _pickImage('front'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _imagePickerCard(
                          label: "Right Side of Car/Bike",
                          file: _rightImage,
                          onTap: () => _pickImage('right'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _imagePickerCard(
                          label: "Left Side of Car/Bike",
                          file: _leftImage,
                          onTap: () => _pickImage('left'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _imagePickerCard(
                          label: "Back Side of Car/Bike",
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
    required File? file,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ParcelColors.labelDark,
            ),
            children: [
              TextSpan(
                text: " *",
                style: TextStyle(color: ParcelColors.asterisk),
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
                color: file != null ? ParcelColors.primary : ParcelColors.border,
                width: file != null ? 1.5 : 1,
              ),
              color: Colors.white,
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
                                color: ParcelColors.primary, size: 20),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32, color: ParcelColors.hint),
                          const SizedBox(height: 6),
                          Text("Tap to upload",
                              style: GoogleFonts.nunito(
                                  fontSize: 11, color: ParcelColors.hint)),
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
