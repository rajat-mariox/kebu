import 'dart:async';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/LoginScreen/Controller/auth_controller.dart';
import 'package:kebu_customer/Screens/Screens/DashboardScreen/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Utils/CustomToast/custome_toast.dart';
import 'package:pinput/pinput.dart';

class OtpScreen extends StatefulWidget {
  final String mobileNumber;
  final String token;
  const OtpScreen({super.key, required this.mobileNumber, required this.token});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  int _secondsRemaining = 60;
  Timer? _timer;
  String pinValue = "";
  late String _activeToken;
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _activeToken = widget.token;
    startTimer();
  }

  Future<void> _onResendOtp() async {
    if (_secondsRemaining > 0) {
      showCustomToast(context, 'Please wait $_secondsRemaining sec to resend OTP.');
      return;
    }

    final res = await _authController.resendOtp(widget.mobileNumber);
    if (!mounted) return;

    if ((res.code ?? 0) == 200 && (res.data?.txnId ?? '').isNotEmpty) {
      _activeToken = res.data?.txnId ?? _activeToken;
      startTimer();
      showCustomToast(context, 'OTP sent successfully.');
    } else {
      showCustomToast(context, res.message ?? 'Unable to resend OTP.');
    }
  }

  Future<void> _onVerify() async {
    if (pinValue.toString().length < 6) {
      showCustomToast(context, "Please enter valid OTP.");
      return;
    }
    final res = await _authController.verifyOtp(
      otp: pinValue.toString(),
      token: _activeToken,
      mobileNumber: widget.mobileNumber,
    );
    if (!mounted) return;

    if ((res.code ?? 0) == 200) {
      replaceRoute(context, const DashboardScreen());
    } else {
      showCustomToast(context, res.message ?? 'Invalid OTP.');
    }
  }

  void startTimer() {
    _timer?.cancel();
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 46,
      height: 54,
      textStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HexColor("#D3DDE7"), width: 1.5),
      ),
    );

    final focusedPinTheme = PinTheme(
      width: 46,
      height: 54,
      textStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
      decoration: BoxDecoration(
        color: HexColor("#FFF8F8"),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HexColor("#FF4A82"), width: 1.5),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),

                  // ── Back ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios_new,
                                size: 18, color: Color(0xFF414141)),
                            const SizedBox(width: 4),
                            Text("Back",
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: const Color(0xFF414141))),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Title ──
                  Text("Phone verification",
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2A2A2A))),

                  const SizedBox(height: 8),

                  // ── Subtitle ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "We've sent a 6-digit verification code to your mobile number or email. Please enter the code below to verify your identity.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: const Color(0xFFA0A0A0),
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // ── OTP boxes ──
                  Pinput(
                    length: 6,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: focusedPinTheme,
                    onChanged: (value) {
                      pinValue = value;
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Resend ──
                  InkWell(
                    onTap: _onResendOtp,
                    child: Text.rich(
                      TextSpan(
                        text: "Didn’t receive code?  ",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w400),
                        children: [
                          TextSpan(
                            text: _secondsRemaining > 0
                                ? "Resend in $_secondsRemaining s"
                                : "Resend again",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: HexColor("#FF4E80"),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // ── Verify (gradient) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: _onVerify,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFFFD546), Color(0xFFFF155E)],
                          ),
                        ),
                        child: Text("Verify",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Terms ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: "By continuing you agree to our ",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFA6A6A6),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13)),
                          TextSpan(
                              text: "Terms of Services",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF0082DF),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13)),
                          TextSpan(
                              text: " and ",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFFA6A6A6),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13)),
                          TextSpan(
                              text: "Privacy Policy",
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF0082DF),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Loading overlay ──
            Obx(() {
              if (!_authController.isLoading.value) {
                return const SizedBox.shrink();
              }
              return const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
