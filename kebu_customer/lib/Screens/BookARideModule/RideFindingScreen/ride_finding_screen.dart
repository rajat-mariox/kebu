import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/LiveTracking/live_tracking_screen.dart';
import 'package:kebu_customer/Services/socket_service.dart';

/// Shown right after the rider taps "Book". Pulses a radar "searching"
/// animation while we look for a nearby driver and poll the live status. Moves
/// to [LiveTrackingScreen] as soon as a driver accepts. Mirrors the household
/// ServiceWaitingScreen's clean centred-pulse look, themed for the ride flow.
class RideFindingScreen extends StatefulWidget {
  final String? bookingId;
  const RideFindingScreen({super.key, this.bookingId});
  @override
  State<RideFindingScreen> createState() => _RideFindingScreenState();
}

class _RideFindingScreenState extends State<RideFindingScreen>
    with SingleTickerProviderStateMixin {
  final BookingController _bc = Get.find<BookingController>();
  StreamSubscription? _noDriversSub;
  Worker? _stateWorker;
  Timer? _pollTimer;
  late final AnimationController _pulse;

  // Ride brand palette (matches the yellow Book-a-ride theme).
  static final Color _amber = HexColor('#FFB300');
  static final Color _yellow = HexColor('#FFD546');
  static final Color _darkText = HexColor('#2D3134');

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Keep the nearby-driver list + ETA fresh while we search.
    _bc.fetchNearbyDrivers();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _bc.fetchNearbyDrivers();
    });

    // Driver accepted → state flips to driverAssigned; hand off to live tracking.
    _stateWorker = ever(_bc.state, (BookingState s) {
      if (!mounted) return;
      if (s == BookingState.driverAssigned ||
          s == BookingState.driverArrived ||
          s == BookingState.inProgress) {
        replaceRouteKeepingRoot(context, const LiveTrackingScreen());
      } else if (s == BookingState.cancelled) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    // Backend says no one could be matched → bail out gracefully.
    _noDriversSub = SocketService().onNoDriversAvailable.listen((data) {
      if (!mounted) return;
      if (data['bookingId']?.toString() == _bc.bookingId.value) {
        Fluttertoast.showToast(
          msg:
              "No drivers available nearby. Please try again in a few minutes.",
          toastLength: Toast.LENGTH_LONG,
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _noDriversSub?.cancel();
    _stateWorker?.dispose();
    _pollTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _cancelBooking() async {
    final ok = await _bc.cancelBooking();
    if (ok && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  String _statusSubtitle() {
    // Prefer the backend-computed ETA for the nearest driver → "Approx X min".
    final eta = _bc.cabEtaMinutes.value;
    if (eta != null && eta > 0) {
      return 'Nearest driver approx $eta min away';
    }
    final n = _bc.nearbyDrivers.length;
    if (n <= 0) return 'Please wait while we connect you with a nearby driver.';
    return '$n driver${n == 1 ? '' : 's'} nearby — connecting you now.';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Leaving the search screen must cancel the request so it is removed
        // from every notified driver — otherwise a driver could accept a ride
        // the customer has already abandoned.
        if (!didPop) _cancelBooking();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Lightweight top bar with a back action and the screen title.
                Row(
                  children: [
                    InkWell(
                      onTap: _cancelBooking,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.arrow_back_ios,
                            size: 20, color: _darkText),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ride Finding',
                      style: TextStyle(
                        color: _darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Radar pulse: three expanding, fading rings behind a gradient
                // disc with the cab icon — the household waiting-screen look,
                // themed yellow for the ride flow.
                SizedBox(
                  height: 220,
                  width: 220,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          _ring(0.0),
                          _ring(0.33),
                          _ring(0.66),
                          Container(
                            height: 96,
                            width: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient:
                                  LinearGradient(colors: [_yellow, _amber]),
                              boxShadow: [
                                BoxShadow(
                                  color: _amber.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(Icons.local_taxi,
                                color: _darkText, size: 44),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Finding nearby drivers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Obx(() => Text(
                      _statusSubtitle(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade600,
                      ),
                    )),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _cancelBooking,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HexColor('#D81D0C'),
                      side: BorderSide(color: HexColor('#D81D0C'), width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel Booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.408,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One expanding, fading ring — three of them, phase-shifted, give a radar
  /// "searching" pulse.
  Widget _ring(double phaseOffset) {
    final t = (_pulse.value + phaseOffset) % 1.0;
    final size = 96 + t * 120;
    return Opacity(
      opacity: ((1 - t) * 0.45).clamp(0.0, 1.0),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _amber, width: 2),
        ),
      ),
    );
  }
}
