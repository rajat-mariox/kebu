import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/DriverModule/HomeScreen/home_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/technician_dashboard.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelHomeScreen/parcel_home_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/SupportChatScreen/support_chat_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check status once on entry. If already approved, move the driver forward
    // automatically — the Figma screen exposes no manual "check" action.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
    // Keep polling while the driver waits on this screen, so an approval (or
    // rejection) made on the admin panel advances them without needing to
    // background/reopen the app.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _checkStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check whenever the driver returns to the app, so an approval that
    // happens while they are away advances them without a manual refresh.
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _checkStatus({bool notifyWhenPending = false}) async {
    // A previous check may already be navigating away; don't fire again.
    if (_navigated) return;

    final res = await DriverApiService.getDashboard();
    if (!mounted || _navigated) return;

    if (res.success && res.data != null) {
      final driver = res.data['driver'];
      final status = driver?['status'] ?? '';
      final serviceType = driver?['serviceType'] ?? '';

      if (status == 'approved') {
        _navigated = true;
        _pollTimer?.cancel();
        if (serviceType == 'cleaning') {
          replaceRoute(context, const TechnicianDashboard());
        } else if (serviceType == 'parcel') {
          replaceRoute(context, const ParcelHomeScreen());
        } else {
          replaceRoute(context, const HomeScreen());
        }
      } else if (status == 'rejected') {
        // Stop polling and show the reason once, instead of spamming the toast
        // every poll tick.
        _navigated = true;
        _pollTimer?.cancel();
        final reason = driver?['rejectionReason'] ?? '';
        showCustomToast(
            context,
            reason.isNotEmpty
                ? 'Application rejected: $reason'
                : 'Your application has been rejected. Please contact support.');
      } else if (notifyWhenPending) {
        showCustomToast(
            context, 'Your application is still under review. Please wait.');
      }
    } else if (notifyWhenPending) {
      showCustomToast(context, 'Unable to check status. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: HexColor("#F0F5FA"),
        body: Column(
          children: [
            // Yellow header
            Container(
              width: double.infinity,
              color: HexColor("#FFD546"),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  child: Text(
                    'Verification',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 25 / 20,
                      color: HexColor("#132235"),
                    ),
                  ),
                ),
              ),
            ),

            // Illustration + status text (baked into the design asset)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 39),
                  child: Image.asset(
                    'assets/verification_image.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Chat with Staff button
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: GestureDetector(
                onTap: () {
                  pushTo(context, const SupportChatScreen());
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HexColor("#FFD546"),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Text(
                    'Chat with Staff',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 22 / 17,
                      color: HexColor("#191919"),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
