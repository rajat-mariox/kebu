import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/Screens/DashboardScreen/dashboard_screen.dart';

/// Feedback-thanks confirmation (Figma node 1:2494) — shown after Skip / Pay
/// Tip. A static success screen; "OK" returns to the dashboard.
class FeedBackThanksScreen extends StatelessWidget {
  const FeedBackThanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final yellow = HexColor('#FFD546');
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: yellow,
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
        child: SafeArea(
          top: false,
          child: GestureDetector(
            onTap: () {
              // Clear the whole ride flow and return to the dashboard. The
              // dashboard is the app root (set at splash), so pop back to it
              // when it exists; otherwise push a fresh one.
              if (Navigator.canPop(context)) {
                Navigator.popUntil(context, (route) => route.isFirst);
              } else {
                replaceRoute(context, const DashboardScreen());
              }
            },
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: yellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('OK',
                  style: GoogleFonts.poppins(
                      color: HexColor('#3C4043'), fontSize: 16)),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 10, 12, 14),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios,
                      size: 20, color: Colors.black),
                ),
                const SizedBox(width: 6),
                Text('Completed Ride',
                    style: GoogleFonts.inter(
                        color: HexColor('#2D3134'),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const NotificationIconButton(height: 30),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: HexColor('#22B24C'),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 24),
                    Text('Thanks for your feedback!',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: HexColor('#121212'))),
                    const SizedBox(height: 8),
                    Text('See you on your next trip!',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: HexColor('#707070'))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
