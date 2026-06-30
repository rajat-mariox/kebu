import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/CommonWidgets/photo_capture_row.dart';
import 'package:kebu_driver/CommonWidgets/slide_to_confirm.dart';
import 'package:kebu_driver/Screens/CleaningModule/OngoingServiceScreen/ongoing_service_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Second step of starting a service (after the selfie on the service-details
/// screen): the partner captures the device photo, the device serial-number
/// photo and an optional extra photo, then slides "Start the service" which
/// uploads everything (selfie + these) and marks the booking IN_PROGRESS.
class CaptureServicePhotosScreen extends StatefulWidget {
  /// The booking payload carried forward from the service-details screen.
  final Map<String, dynamic> data;

  /// The selfie captured on the previous screen.
  final File selfie;

  const CaptureServicePhotosScreen({
    super.key,
    required this.data,
    required this.selfie,
  });

  @override
  State<CaptureServicePhotosScreen> createState() =>
      _CaptureServicePhotosScreenState();
}

class _CaptureServicePhotosScreenState
    extends State<CaptureServicePhotosScreen> {
  late final DirectionData _d = DirectionData(widget.data);
  // Selfie carried from the service-details screen; still changeable here
  // (Figma screen 2 shows it as "Change your selfie" at the top).
  late File _selfie = widget.selfie;
  File? _devicePhoto;
  File? _serialPhoto;
  File? _otherPhoto;

  static final Color _primary = HexColor("#2C54C1");

  Future<void> _pick(void Function(File) onPicked) async {
    final file = await capturePhoto();
    if (file != null && mounted) setState(() => onPicked(file));
  }

  Future<void> _changeSelfie() async {
    final file = await capturePhoto(camera: CameraDevice.front);
    if (file != null && mounted) setState(() => _selfie = file);
  }

  /// Validates the required photos and starts the service. Returns true on
  /// success (navigates to the ongoing screen); false on any failure so the
  /// slide handle springs back to the start.
  Future<bool> _startService() async {
    if (_devicePhoto == null || _serialPhoto == null) {
      Fluttertoast.showToast(
          msg: "Please capture the device and serial number photos");
      return false;
    }
    final id = _d.bookingId;
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: "Booking not found");
      return false;
    }

    final res = await DriverApiService.startServiceBooking(
      bookingId: id,
      selfie: _selfie,
      devicePhoto: _devicePhoto!,
      serialPhoto: _serialPhoto!,
      otherPhoto: _otherPhoto,
    );
    if (!mounted) return false;

    if (res.success) {
      // Carry the updated booking (now IN_PROGRESS, with startedAt) into the
      // ongoing-services screen, keeping the rest of the accept payload.
      final updated = Map<String, dynamic>.from(widget.data);
      if (res.data is Map && (res.data as Map)['booking'] != null) {
        updated['booking'] = (res.data as Map)['booking'];
      }
      // Service started (IN_PROGRESS, irreversible) → replace so Back doesn't
      // return to the capture screens (resumable from "On Going").
      pushReplace(context, OngoingServiceScreen(data: updated));
      return true;
    }
    Fluttertoast.showToast(
        msg: res.message.isNotEmpty ? res.message : "Could not start service");
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          cleaningAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text("Service details",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.only(top: 120),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 7),
                  PhotoCaptureRow(
                    title: "Upload your own photo",
                    file: _selfie,
                    captureLabel: "Capture your selfie",
                    capturedLabel: "Change your selfie",
                    onTap: _changeSelfie,
                  ),
                  const SizedBox(height: 18),
                  PhotoCaptureRow(
                    title: "Upload device photo",
                    file: _devicePhoto,
                    captureLabel: "Capture device photo",
                    capturedLabel: "Change device photo",
                    onTap: () => _pick((f) => _devicePhoto = f),
                  ),
                  const SizedBox(height: 18),
                  PhotoCaptureRow(
                    title: "Upload a photo of the device serial no",
                    file: _serialPhoto,
                    captureLabel: "Capture serial number photo",
                    capturedLabel: "Change serial number photo",
                    onTap: () => _pick((f) => _serialPhoto = f),
                  ),
                  const SizedBox(height: 18),
                  PhotoCaptureRow(
                    title: "Upload other photo (optional)",
                    file: _otherPhoto,
                    captureLabel: "Capture photo",
                    capturedLabel: "Change photo",
                    onTap: () => _pick((f) => _otherPhoto = f),
                  ),
                  const SizedBox(height: 30),
                  _startButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    final ready = _devicePhoto != null && _serialPhoto != null;
    return SlideToConfirm(
      label: "Start the service",
      onConfirmed: _startService,
      trackColor: ready ? _primary : HexColor("#D3D3D3"),
      textColor: ready ? Colors.white : HexColor("#333333"),
      handleIconColor: ready ? _primary : HexColor("#D3D3D3"),
    );
  }
}
