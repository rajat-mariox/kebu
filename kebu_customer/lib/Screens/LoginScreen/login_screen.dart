import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/LoginScreen/Controller/auth_controller.dart';
import 'package:kebu_customer/Screens/OtpScreen/otp_screen.dart';
import 'package:kebu_customer/Utils/CustomToast/custome_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  Future<void> _onGetOtp() async {
    final phone = _phoneController.text.toString();
    if (phone == "") {
      showCustomToast(context, "Please enter mobile number.");
      return;
    }
    if (phone.length != 10) {
      showCustomToast(context, "Please enter valid mobile number.");
      return;
    }
    final res = await _authController.requestOtp(phone);
    if (!mounted) return;

    if ((res.code ?? 0) == 200 && (res.data?.txnId ?? '').isNotEmpty) {
      pushTo(
        context,
        OtpScreen(mobileNumber: phone, token: res.data?.txnId ?? ''),
      );
    } else {
      showCustomToast(context, res.message ?? 'Unable to request OTP.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Back ──
                  InkWell(
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
                                  fontSize: 16, color: const Color(0xFF414141))),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Title ──
                  Center(
                    child: Text("Sign in",
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A2A2A))),
                  ),

                  const SizedBox(height: 8),

                  // ── Illustration ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 39),
                    child: Image.asset("assets/sign_in_icon.png"),
                  ),

                  const SizedBox(height: 40),

                  // ── Phone input ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFB8B8B8)),
                      ),
                      child: Center(
                        child: TextField(
                          maxLength: 10,
                          controller: _phoneController,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          ],
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.black),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: "Email or Phone Number",
                            hintStyle: GoogleFonts.poppins(
                                color: const Color(0xFFD0D0D0),
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── Get OTP (gradient) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: _onGetOtp,
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
                        child: Text("Get OTP",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

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
