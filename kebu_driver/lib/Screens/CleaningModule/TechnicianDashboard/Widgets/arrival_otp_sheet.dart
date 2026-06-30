import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/slide_to_confirm.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:pinput/pinput.dart';

/// OTP confirmation sheet shown when the partner taps "Reached location".
///
/// The customer shares the arrival OTP (generated on accept). Entering it and
/// tapping "Verify and mark arrived" marks the booking PROVIDER_ARRIVED on the
/// backend. The earnings line reads from the booking payload — fully
/// data-driven. Matches the Figma OTP sheet design.
class ArrivalOtpSheet extends StatefulWidget {
  final DirectionData data;

  /// Called once the OTP is verified and the booking is marked arrived.
  final VoidCallback onVerified;

  const ArrivalOtpSheet({
    super.key,
    required this.data,
    required this.onVerified,
  });

  @override
  State<ArrivalOtpSheet> createState() => _ArrivalOtpSheetState();
}

class _ArrivalOtpSheetState extends State<ArrivalOtpSheet> {
  final TextEditingController _otpController = TextEditingController();
  final SlideToConfirmController _slideController = SlideToConfirmController();

  static final Color _primary = HexColor("#2C54C1");

  @override
  void dispose() {
    _otpController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String get _earningsBonus {
    final v = widget.data.data['earningsBonus'];
    if (v is num && v > 0) return "+ ₹$v";
    return "";
  }

  /// Validates the OTP and marks the booking arrived. Returns true on success
  /// (the sheet is popped and [onVerified] fired); false on any failure so the
  /// slide handle springs back to the start.
  Future<bool> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      Fluttertoast.showToast(msg: "Please enter the 4-digit OTP");
      return false;
    }
    final id = widget.data.bookingId;
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: "Booking not found");
      return false;
    }

    final res = await DriverApiService.updateServiceBookingStatus(
      bookingId: id,
      status: "PROVIDER_ARRIVED",
      otp: otp,
    );
    if (!mounted) return false;

    if (res.success) {
      Navigator.of(context).pop(); // close the sheet
      widget.onVerified();
      return true;
    }
    Fluttertoast.showToast(
        msg: res.message.isNotEmpty ? res.message : "Invalid OTP");
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final defaultPin = PinTheme(
      width: 50,
      height: 42,
      textStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: HexColor("#132235"),
      ),
      decoration: BoxDecoration(
        color: HexColor("#F5F5F5"),
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: HexColor("#94A3B3"),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Please Enter the OTP",
                      style: TextStyle(
                        color: HexColor("#132235"),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 25 / 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "to confirm your services",
                      style: TextStyle(
                        color: HexColor("#132235"),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // OTP boxes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Pinput(
                  length: 4,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  defaultPinTheme: defaultPin,
                  focusedPinTheme: defaultPin.copyWith(
                    decoration: defaultPin.decoration!.copyWith(
                      border: Border.all(color: _primary, width: 1.2),
                    ),
                  ),
                  separatorBuilder: (_) => const SizedBox(width: 12),
                  // Once all 4 digits are in, drop the keyboard and auto-slide
                  // the handle across to verify — no manual drag needed.
                  onCompleted: (_) {
                    FocusScope.of(context).unfocus();
                    _slideController.slide();
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Earnings card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HexColor("#E1E6EF")),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 1.5,
                          offset: Offset(0, 1)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.currency_rupee,
                          size: 20, color: HexColor("#132235")),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.data.amount,
                              style: TextStyle(
                                color: HexColor("#132235"),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Your estimated earnings",
                              style: TextStyle(
                                color: HexColor("#364B63"),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_earningsBonus.isNotEmpty)
                        Text(
                          _earningsBonus,
                          style: TextStyle(
                            color: _primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Slide-to-verify: drag the handle to the right edge to confirm.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SlideToConfirm(
                  label: "Verify and mark arrived",
                  controller: _slideController,
                  onConfirmed: _verify,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
