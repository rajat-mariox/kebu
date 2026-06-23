import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// What the user picks in the "What would you like to do?" sheet that appears
/// after tapping Proceed on the Send Parcel screen.
enum DeliveryMode { instant, scheduled }

/// Shows the delivery-mode bottom sheet and resolves with the chosen mode, or
/// null if the user dismisses it.
Future<DeliveryMode?> showDeliveryModeSheet(BuildContext context) {
  return showModalBottomSheet<DeliveryMode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (_) => const _DeliveryModeSheet(),
  );
}

class _DeliveryModeSheet extends StatelessWidget {
  const _DeliveryModeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What would you like to do?",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 20),
              _instantCard(
                onTap: () => Navigator.pop(context, DeliveryMode.instant),
              ),
              const SizedBox(height: 21),
              _scheduleCard(
                onTap: () => Navigator.pop(context, DeliveryMode.scheduled),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Instant Delivery card (teal illustration background)
  // ---------------------------------------------------------------------------
  Widget _instantCard({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 152,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage("assets/figma_instant_delivery.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 13,
              top: 14,
              child: SvgPicture.asset(
                "assets/figma_thunderbolt.svg",
                width: 50,
                height: 50,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
            Positioned(
              left: 13,
              top: 72,
              right: 120,
              child: _cardText(
                title: "Instant Delivery",
                subtitle: "Courier takes only your\npackage and delivers instantly",
                subtitleSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule Delivery card (yellow→pink gradient + scooter/clock illustration)
  // ---------------------------------------------------------------------------
  Widget _scheduleCard({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 152,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          // Figma gradient is yellow(16.9%)→pink(144.4%) at 170° (near-vertical,
          // slight tilt). Because the pink stop sits well past the card, the
          // visible bottom reads as a warm orange — so we use the on-card
          // endpoint colors with the same gentle tilt.
          gradient: const LinearGradient(
            begin: Alignment(0.25, -1),
            end: Alignment(-0.25, 1),
            colors: [Color(0xFFFFD546), Color(0xFFFF5856)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 22,
              bottom: 4,
              child: Image.asset(
                "assets/figma_schedule_delivery.png",
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
              ),
            ),
            Positioned(
              left: 13,
              top: 16,
              child: SvgPicture.asset(
                "assets/figma_timer.svg",
                width: 43,
                height: 43,
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
            Positioned(
              left: 13,
              top: 70,
              right: 90,
              child: _cardText(
                title: "Schedule Delivery",
                subtitle: "Courier comes to pick up on\nyour specified date and time",
                subtitleSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardText({
    required String title,
    required String subtitle,
    required double subtitleSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: subtitleSize,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
