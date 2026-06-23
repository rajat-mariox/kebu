
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/LoginScreen/Controller/auth_controller.dart';
import 'package:kebu_driver/Screens/OtpScreen/otp_screen.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();
  final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneController.text.toString() == "") {
      showCustomToast(context, "Please enter mobile number.");
    } else if (_phoneController.text.toString().length != 10) {
      showCustomToast(context, "Please enter valid mobile number.");
    } else {
      final res = await _authController.requestOtp(_phoneController.text.toString());

      if (!mounted) {
        return;
      }

      if (res.code == 200 && res.txnId.isNotEmpty) {
        pushTo(
          context,
          OtpScreen(
            mobileNumber: _phoneController.text.toString(),
            txnId: res.txnId,
          ),
        );
      } else {
        showCustomToast(context, res.message.isEmpty ? 'Unable to request OTP.' : res.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor("#F8FAFC"),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Note / consent text
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Note:",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 16 / 12,
                        color: HexColor("#364B63"),
                      ),
                    ),
                    TextSpan(
                      text:
                          " By proceeding, you consent to get calls, WhatsApp or SMS messages, including by automated means, from Kebu One and its affiliates to the number provided.",
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        height: 16 / 12,
                        color: HexColor("#607080"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Gradient "Get Verification Code" button
              InkWell(
                onTap: _submit,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [HexColor("#FFD546"), HexColor("#FF155E")],
                    ),
                  ),
                  child: const Text(
                    "Get Verification Code",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      height: 22 / 17,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Back arrow
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back,
                        size: 24,
                        color: HexColor("#132235"),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title
                  Text(
                    "Enter Phone number for verification",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      height: 34 / 28,
                      letterSpacing: -0.4,
                      color: HexColor("#132235"),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    "We’ll text a code to verify your phone number",
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      height: 20 / 15,
                      color: HexColor("#364B63"),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Phone number input row
                  IntrinsicHeight(
                    child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Country code field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: HexColor("#D3DDE7")),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Image.asset(
                                "assets/india_flags.png",
                                width: 23,
                                height: 17,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "+91",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 17,
                                height: 22 / 17,
                                color: HexColor("#132235"),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: HexColor("#607080"),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Phone number field
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _phoneFocus.hasFocus
                                  ? HexColor("#2F6FED")
                                  : HexColor("#D3DDE7"),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                offset: Offset(0, 1),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                          child: TextField(
                            focusNode: _phoneFocus,
                            controller: _phoneController,
                            maxLength: 10,
                            cursorColor: HexColor("#2F6FED"),
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                            ],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              height: 22 / 17,
                              color: HexColor("#132235"),
                            ),
                            decoration: InputDecoration(
                              counterText: "",
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              hintText: "Phone number",
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 17,
                                color: HexColor("#A6B2BF"),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            Obx(() {
              if (!_authController.isLoading.value) {
                return const SizedBox.shrink();
              }

              return const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ),
              );
            })
          ],
        ),
      ),
    );
  }
}
