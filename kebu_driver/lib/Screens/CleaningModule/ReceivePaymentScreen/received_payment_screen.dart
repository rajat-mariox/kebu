import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/technician_dashboard.dart';

/// "Received Payment" — success screen shown after the partner collects payment
/// (cash slide-to-collect or an online scan). Matches the Figma design: a green
/// success check, confirmation copy and an orange "Done" button that returns
/// the partner to their dashboard.
class ReceivedPaymentScreen extends StatelessWidget {
  const ReceivedPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  const Text("Received Payment",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 120),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _successCheck(),
                  const SizedBox(height: 28),
                  Text(
                    "Payment received",
                    style: TextStyle(
                      color: HexColor("#16243B"),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Your payment was successful!",
                    style: TextStyle(
                      color: HexColor("#5A6472"),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HexColor("#E8722A"),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        // Return to the dashboard (the first route in the stack).
                        // Service fully done → land the partner back on the
                        // dashboard (clearing the in-service screens).
                        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const TechnicianDashboard()),
                          (route) => false,
                        ),
                        child: const Text(
                          "Done",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Green success circle with a white check and a few accent sparkles.
  Widget _successCheck() {
    final green = HexColor("#34A853");
    return SizedBox(
      height: 120,
      width: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _sparkle(green, top: 8, left: 14, size: 7),
          _sparkle(green, top: 30, right: 6, size: 9, diamond: true),
          _sparkle(green, bottom: 18, left: 4, size: 6),
          _sparkle(green, bottom: 8, right: 24, size: 6, diamond: true),
          Container(
            height: 92,
            width: 92,
            decoration: BoxDecoration(color: green, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 46),
          ),
        ],
      ),
    );
  }

  Widget _sparkle(Color color,
      {double? top,
      double? bottom,
      double? left,
      double? right,
      double size = 6,
      bool diamond = false}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: diamond ? 0.785398 : 0, // 45° for a diamond
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(diamond ? 1 : size),
          ),
        ),
      ),
    );
  }
}
