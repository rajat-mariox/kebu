import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/CommonWidgets/photo_capture_row.dart';
import 'package:kebu_driver/CommonWidgets/slide_to_confirm.dart';
import 'package:kebu_driver/Screens/CleaningModule/ServiceDetailsScreen/capture_service_photos_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';

/// "Service details" — shown after the arrival OTP is verified (booking is now
/// PROVIDER_ARRIVED). Fully data-driven from the accept payload ([DirectionData]):
/// service number, status, customer address and the price breakdown. Matches
/// the Figma "Service details" design: the partner captures a selfie and slides
/// "Start the service", which carries the selfie forward to the device/serial
/// photo-capture screen where the service is actually started.
class ServiceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const ServiceDetailsScreen({super.key, this.data = const {}});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  late final DirectionData _d = DirectionData(widget.data);
  File? _selfie;

  static final Color _primary = HexColor("#2C54C1");

  String _arrivalTimeLabel() {
    final raw = _d.booking['providerArrivedAt'];
    DateTime dt;
    try {
      dt = raw != null ? DateTime.parse(raw.toString()).toLocal() : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    var h = dt.hour % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return "Today $h:$m $ampm";
  }

  int get _itemCount =>
      _d.priceBreakdown.where((r) => r['quantity'] != null).length;

  Future<void> _captureSelfie() async {
    final file = await capturePhoto(camera: CameraDevice.front);
    if (file != null && mounted) setState(() => _selfie = file);
  }

  /// Validates the selfie and moves on to the device/serial photo-capture
  /// screen (which actually starts the service). Returns true on success so the
  /// slide handle stays put; false (with a toast) so it springs back.
  Future<bool> _continue() async {
    if (_selfie == null) {
      Fluttertoast.showToast(msg: "Please capture your selfie");
      return false;
    }
    if (_d.bookingId.isEmpty) {
      Fluttertoast.showToast(msg: "Booking not found");
      return false;
    }
    pushReplace(
      context,
      CaptureServicePhotosScreen(data: widget.data, selfie: _selfie!),
    );
    return true;
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
                  _serviceNumberCard(),
                  const SizedBox(height: 16),
                  _customerAddress(),
                  const SizedBox(height: 20),
                  Text(
                    "Job details $_itemCount item${_itemCount == 1 ? '' : 's'}",
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  _breakdownCard(),
                  const SizedBox(height: 20),
                  _photoSection(),
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

  Widget _serviceNumberCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _arrivalTimeLabel(),
                style: const TextStyle(
                    fontSize: 12, color: Colors.black, fontWeight: FontWeight.w400),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: HexColor("#275FC8")),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text("Reached",
                    style: TextStyle(
                        fontSize: 10,
                        color: HexColor("#275FC8"),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Your service number is ${_d.bookingNumber}",
            style: const TextStyle(
                fontSize: 13, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _customerAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Customer Address.",
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black)),
        const SizedBox(height: 6),
        Opacity(
          opacity: 0.8,
          child: Text(
            _d.fullAddress,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                color: Colors.black,
                height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _breakdownCard() {
    final rows = _d.priceBreakdown;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HexColor("#F6F7F9"),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _breakdownRow(rows[i]),
            const SizedBox(height: 10),
            Divider(color: HexColor("#EBEBEB"), height: 1),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Text("Total Amount",
                  style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1C1F34),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                _d.totalAmountLabel,
                style: TextStyle(
                    fontSize: 16,
                    color: _primary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(Map<String, dynamic> row) {
    final label = (row['label'] ?? '').toString();
    final qty = row['quantity'];
    final amount = (row['amount'] is num) ? row['amount'] as num : 0;
    final amountText = amount < 0 ? "-₹${-amount}" : "₹$amount";
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1C1F34),
                fontWeight: FontWeight.w500),
          ),
        ),
        if (qty != null) ...[
          Text("$qty",
              style: TextStyle(fontSize: 14, color: HexColor("#1C1F34"))),
          const SizedBox(width: 24),
        ],
        Text(
          amountText,
          style: TextStyle(
              fontSize: 14,
              color: HexColor("#6C757D"),
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _photoSection() {
    // Figma shows a single "Upload your own photo" (selfie). The device &
    // serial photos are captured on the next screen.
    return PhotoCaptureRow(
      title: "Upload your own photo",
      file: _selfie,
      captureLabel: "Capture your selfie",
      capturedLabel: "Change your selfie",
      onTap: _captureSelfie,
    );
  }

  Widget _startButton() {
    // Solid blue once the selfie is captured; greyed otherwise (the Figma
    // "Start the service" state). Sliding always validates first.
    final ready = _selfie != null;
    return SlideToConfirm(
      label: "Start the service",
      onConfirmed: _continue,
      trackColor: ready ? _primary : HexColor("#D3D3D3"),
      textColor: ready ? Colors.white : HexColor("#333333"),
      handleIconColor: ready ? _primary : HexColor("#D3D3D3"),
    );
  }
}
