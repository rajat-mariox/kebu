import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the camera and returns the captured file, or null if cancelled/failed.
Future<File?> capturePhoto({
  CameraDevice camera = CameraDevice.rear,
}) async {
  try {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: camera,
      imageQuality: 70,
    );
    return x == null ? null : File(x.path);
  } catch (_) {
    Fluttertoast.showToast(msg: "Could not open camera");
    return null;
  }
}

/// A titled photo-capture row used on the service-details and photos screens:
/// a label above an outlined box holding a preview thumbnail and a
/// "Capture …" button that flips to a green check once a photo is taken.
class PhotoCaptureRow extends StatelessWidget {
  final String title;
  final File? file;
  final String captureLabel;
  final String capturedLabel;
  final VoidCallback onTap;

  const PhotoCaptureRow({
    super.key,
    required this.title,
    required this.file,
    required this.captureLabel,
    required this.capturedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final captured = file != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 12,
              color: HexColor("#000000"),
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: HexColor("#CCCCCC").withValues(alpha: 0.4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: captured
                      ? Image.file(file!, fit: BoxFit.cover)
                      : Image.asset("assets/business_man_icon.png",
                          fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.black.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            captured
                                ? Icons.check_circle
                                : Icons.camera_alt_outlined,
                            size: 24,
                            color: captured ? HexColor("#3CAE5C") : Colors.black),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            captured ? capturedLabel : captureLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
