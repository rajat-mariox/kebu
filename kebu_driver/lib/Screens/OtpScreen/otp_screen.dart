import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/LoginScreen/Controller/auth_controller.dart';
import 'package:kebu_driver/Screens/WelcomeScreen/welcome_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/HomeScreen/home_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/technician_dashboard.dart';
import 'package:kebu_driver/Screens/DriverModule/VerificationScreen/verification_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/basic_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/driving_licence_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/aadhar_card_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/address_onboarding_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/bank_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/onboarding_controller.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/service_categories_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/vehicle_details_screen.dart';
import 'package:kebu_driver/Screens/on_boarding_screens/vehicle_images_screen.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:pinput/pinput.dart';



class OtpScreen extends StatefulWidget {
  final String mobileNumber;
  final String txnId;

  const OtpScreen({super.key, required this.mobileNumber, required this.txnId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  int _secondsRemaining = 60;
  Timer? _timer;
  String pinValue = "";
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer?.cancel();
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      }
      else
      {
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

  void _navigateAfterLogin(dynamic res) {
    Widget destination;
    final String svcType = (res.serviceType ?? '').toString();

    // If driver already has a service and is approved/active, go to that service's home
    if (res.status == 'approved') {
      if (svcType == 'cleaning') {
        destination = const TechnicianDashboard();
      } else {
        destination = const HomeScreen();
      }
    }
    // Onboarding complete but not yet approved - show verification screen
    else if (res.status == 'documents_uploaded' ||
        res.status == 'under_verification') {
      destination = const VerificationScreen();
    }
    // If driver has started onboarding (has a service but not approved yet),
    // resume from the step they left off — including for cleaning vendors.
    else if (svcType.isNotEmpty) {
      try {
        Get.find<OnboardingController>().serviceType.value = svcType;
      } catch (_) {
        Get.put(OnboardingController()).serviceType.value = svcType;
      }
      destination = _getOnboardingScreen(res.onboardingStep, svcType);
    }
    // New driver - show welcome/service selection
    else {
      destination = const WelcomeScreen();
    }

    replaceRoute(context, destination);
  }

  /// Routes to the NEXT screen after the last completed step.
  /// Cab flow:      0 -> basic, 1 -> licence, 2 -> docs, 3 -> address,
  ///                4 -> bank,  5 -> vehicle, 6 -> images, 7 -> verification
  /// Cleaning flow: 0 -> basic, 1/2 -> docs (DL skipped), 3 -> address,
  ///                4 -> bank,  5/6 -> service categories, 7 -> verification
  Widget _getOnboardingScreen(int completedStep, String serviceType) {
    if (serviceType == 'cleaning') {
      switch (completedStep) {
        case 0:
          return const BasicDetailsScreen();
        case 1:
        case 2:
          return const AadharCardOnboardingScreen();
        case 3:
          return const AddressOnboardingScreen();
        case 4:
          return const BankDetailsScreen();
        case 5:
        case 6:
          return const ServiceCategoriesScreen();
        case 7:
          return const VerificationScreen();
        default:
          return const BasicDetailsScreen();
      }
    }

    switch (completedStep) {
      case 0:
        return const BasicDetailsScreen();
      case 1:
        return const DrivingLicenceScreen();
      case 2:
        return const AadharCardOnboardingScreen();
      case 3:
        return const AddressOnboardingScreen();
      case 4:
        return const BankDetailsScreen();
      case 5:
        return const VehicleDetailsScreen();
      case 6:
        return const VehicleImagesScreen();
      case 7:
        return const VerificationScreen();
      default:
        return const BasicDetailsScreen();
    }
  }

  String get _formattedNumber {
    final n = widget.mobileNumber;
    if (n.length == 10) {
      return "+91 ${n.substring(0, 5)} ${n.substring(5)}";
    }
    return "+91 $n";
  }

  Future<void> _verify() async {
    if (pinValue.toString().length < 6) {
      showCustomToast(context, "Please enter valid OTP.");
    } else {
      final res = await _authController.verifyOtp(
        otp: pinValue.toString(),
        txnId: widget.txnId,
        mobileNumber: widget.mobileNumber,
      );

      if (!mounted) {
        return;
      }

      if (res.code == 200) {
        _navigateAfterLogin(res);
      } else {
        showCustomToast(context, res.message.isEmpty ? 'Invalid OTP.' : res.message);
      }
    }
  }

  // OTP boxes that flex to fit 6 digits across the available width.
  Widget _buildOtpField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 5 gaps of 8px between the 6 boxes. Clamp so a zero/!finite width
        // on the first layout frame can never produce a negative width.
        final double available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0;
        final double boxWidth = ((available - 5 * 8) / 6).clamp(36.0, 60.0);

        final defaultPinTheme = PinTheme(
          width: boxWidth,
          height: 66,
          textStyle: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w400,
            color: HexColor("#132235"),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HexColor("#D3DDE7")),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        );

        final focusedPinTheme = defaultPinTheme.copyDecorationWith(
          border: Border.all(color: HexColor("#2F6FED"), width: 1.5),
        );

        return Pinput(
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: defaultPinTheme,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          onChanged: (value) {
            pinValue = value;
            setState(() {});
          },
          onCompleted: (pin) {
            pinValue = pin;
          },
        );
      },
    );
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
            children: [
              // Resend
              InkWell(
                onTap: _secondsRemaining == 0
                    ? () async {
                        await _authController.requestOtp(widget.mobileNumber);
                        startTimer();
                      }
                    : null,
                child: Text.rich(
                  TextSpan(
                    text: "Haven't got the confirmation code yet? ",
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w400,
                      color: HexColor("#364B63"),
                    ),
                    children: [
                      TextSpan(
                        text: _secondsRemaining > 0
                            ? "Resend in ${_secondsRemaining}s"
                            : "Resend",
                        style: TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          fontWeight: FontWeight.w700,
                          color: HexColor("#2F6FED"),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Verify Code gradient button
              InkWell(
                onTap: _verify,
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
                    "Verify Code",
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
                    "Verify Phone Number",
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
                  Text.rich(
                    TextSpan(
                      text: "Please enter the 6 digit code sent to\n",
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        height: 20 / 15,
                        color: HexColor("#364B63"),
                      ),
                      children: [
                        TextSpan(
                          text: _formattedNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            fontSize: 15,
                            height: 20 / 15,
                            color: HexColor("#132235"),
                          ),
                        ),
                        const TextSpan(text: " through SMS"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Edit your phone number
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      "Edit your phone number?",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        height: 22 / 17,
                        color: HexColor("#2F6FED"),
                        decoration: TextDecoration.underline,
                        decorationColor: HexColor("#2F6FED"),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // OTP boxes (6 digits)
                  _buildOtpField(),

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
