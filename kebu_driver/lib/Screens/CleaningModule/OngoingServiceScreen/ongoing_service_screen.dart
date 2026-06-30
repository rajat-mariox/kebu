import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/Screens/CleaningModule/ReceivePaymentScreen/receive_payment_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';
import 'package:kebu_driver/Screens/CleaningModule/UpdateBookingScreen/update_booking_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// "Ongoing services" — shown while a service is IN_PROGRESS (status "Started").
/// Fully data-driven from the booking payload ([DirectionData]). The partner
/// captures the finished-work photo, can add an extra amount, and taps
/// "End work" which marks the booking COMPLETED on the backend. Matches the
/// Figma "Ongoing services" design.
class OngoingServiceScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const OngoingServiceScreen({super.key, this.data = const {}});

  @override
  State<OngoingServiceScreen> createState() => _OngoingServiceScreenState();
}

class _OngoingServiceScreenState extends State<OngoingServiceScreen> {
  late final DirectionData _d = DirectionData(widget.data);
  File? _finishedPhoto;
  double _extraAmount = 0;
  bool _descExpanded = false;
  bool _submitting = false;

  static final Color _primary = HexColor("#2C54C1");

  Future<void> _captureFinishedPhoto() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 70);
      if (x != null && mounted) setState(() => _finishedPhoto = File(x.path));
    } catch (_) {
      Fluttertoast.showToast(msg: "Could not open camera");
    }
  }

  Future<void> _addExtraAmount() async {
    final result = await pushTo(
      context,
      UpdateBookingScreen(data: widget.data, currentExtra: _extraAmount),
    );
    if (result is num && mounted) {
      setState(() => _extraAmount = result.toDouble());
    }
  }

  Future<void> _endWork() async {
    if (_finishedPhoto == null) {
      Fluttertoast.showToast(msg: "Please capture the finished work photo");
      return;
    }
    final id = _d.bookingId;
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: "Booking not found");
      return;
    }

    setState(() => _submitting = true);
    final res = await DriverApiService.completeServiceBooking(
      bookingId: id,
      finishedPhoto: _finishedPhoto!,
      extraAmount: _extraAmount > 0 ? _extraAmount : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.success) {
      // Work done → collect payment. Carry the complete-service response
      // (booking + payment summary) into the Receive Payment screen.
      final paymentData = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceivePaymentScreen(data: paymentData),
        ),
      );
    } else {
      Fluttertoast.showToast(
          msg: res.message.isNotEmpty ? res.message : "Could not end work");
    }
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
                  const Text("Ongoing services",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 7),
                          _serviceNumberCard(),
                          const SizedBox(height: 16),
                          _categoryAndDescription(),
                          const SizedBox(height: 16),
                          _customerAddress(),
                          const SizedBox(height: 16),
                          _finishedPhotoSection(),
                          const SizedBox(height: 20),
                          _priceSection(),
                        ],
                      ),
                    ),
                  ),
                  _bottomBar(),
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
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_d.startTimeLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.black)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: HexColor("#EBFFF5"),
                  border: Border.all(color: HexColor("#06A14E")),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text("Started",
                    style: TextStyle(
                        fontSize: 10,
                        color: HexColor("#06A14E"),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Your service number is ${_d.bookingNumber}",
              style: const TextStyle(
                  fontSize: 13, color: Colors.black, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _categoryAndDescription() {
    final desc = _d.serviceDetail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_d.category,
            style: const TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500)),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Opacity(
            opacity: 0.8,
            child: Text(
              desc,
              maxLines: _descExpanded ? null : 3,
              overflow: _descExpanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: Colors.black,
                  height: 1.6),
            ),
          ),
          if (desc.length > 120)
            GestureDetector(
              onTap: () => setState(() => _descExpanded = !_descExpanded),
              child: Text(_descExpanded ? "less" : ".. more",
                  style: TextStyle(fontSize: 12, color: HexColor("#3243FF"))),
            ),
        ],
      ],
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
          child: Text(_d.fullAddress,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: Colors.black,
                  height: 1.6)),
        ),
      ],
    );
  }

  Widget _finishedPhotoSection() {
    final captured = _finishedPhoto != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Finished Work Photo",
            style: TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _captureFinishedPhoto,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: HexColor("#CCCCCC").withOpacity(0.4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: captured
                      ? Image.file(_finishedPhoto!, fit: BoxFit.cover)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            captured
                                ? Icons.check_circle
                                : Icons.camera_alt_outlined,
                            size: 24,
                            color:
                                captured ? HexColor("#3CAE5C") : Colors.black),
                        const SizedBox(width: 8),
                        const Text("Finished Work Photo",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
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

  Widget _priceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Estimate Time",
                style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1C1F34),
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            if (_d.estimatedDurationLabel.isNotEmpty)
              Text(_d.estimatedDurationLabel,
                  style: TextStyle(fontSize: 12, color: HexColor("#6C757D"))),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HexColor("#F6F7F9"),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _priceRow("Subtotal", _d.subtotalLabel),
              if (_d.serviceCharge > 0) ...[
                const SizedBox(height: 10),
                _priceRow("Service charge", _d.serviceChargeLabel),
              ],
              if (_extraAmount > 0) ...[
                const SizedBox(height: 10),
                Divider(color: HexColor("#EBEBEB"), height: 1),
                const SizedBox(height: 10),
                _priceRow("Extra Charges", "₹$_extraAmount"),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceRow(String label, String value, {bool emphasize = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: emphasize ? 16 : 14,
                color: const Color(0xFF1C1F34),
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: emphasize ? 16 : 14,
                color: emphasize ? _primary : HexColor("#6C757D"),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _addExtraAmount,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("Extra Amount",
                      style: TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(builder: (_) {
                // Solid blue once the finished photo is captured (ready to end);
                // light blue beforehand.
                final ready = _finishedPhoto != null;
                final fg = ready ? Colors.white : _primary;
                return InkWell(
                  onTap: _submitting ? null : _endWork,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ready ? HexColor("#2F4DBC") : HexColor("#E3EAFF"),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _submitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: fg),
                          )
                        : Text("End Work",
                            style: TextStyle(
                                color: fg,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
