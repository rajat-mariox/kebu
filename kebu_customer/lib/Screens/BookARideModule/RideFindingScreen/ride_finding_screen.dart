import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/book_a_ride_appbar.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/LiveTracking/live_tracking_screen.dart';
import 'package:kebu_customer/Services/socket_service.dart';

/// Shown right after the rider taps "Book". Searches for a nearby driver with
/// a live map (real pickup pin + real nearby driver cars from the backend) and
/// a live status. Moves to [LiveTrackingScreen] as soon as a driver accepts.
class RideFindingScreen extends StatefulWidget {
  final String? bookingId;
  const RideFindingScreen({super.key, this.bookingId});
  @override
  State<RideFindingScreen> createState() => _RideFindingScreenState();
}

class _RideFindingScreenState extends State<RideFindingScreen> {
  final BookingController _bc = Get.find<BookingController>();
  StreamSubscription? _noDriversSub;
  Worker? _stateWorker;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
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
      return 'Approx $eta min';
    }
    final n = _bc.nearbyDrivers.length;
    if (n <= 0) return 'Searching your area…';
    return '$n driver${n == 1 ? '' : 's'} nearby';
  }

  @override
  Widget build(BuildContext context) {
    final Color darkText = HexColor("#2D3134");
    final Color cancelRed = HexColor("#D81D0C");
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Leaving the search screen must cancel the request so it is removed
        // from every notified driver — otherwise a driver could accept a ride
        // the customer has already abandoned.
        if (!didPop) _cancelBooking();
      },
      child: Scaffold(
      backgroundColor: HexColor("#FFD546"),
      body: Stack(
        children: [
          // Yellow header with back button, title and notification bell.
          bookARideAppBar(
            height: 160,
            context: context,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.only(top: 14, left: 12, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: _cancelBooking,
                      child: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.arrow_back_ios,
                                size: 20, color: darkText),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Ride Finding",
                            style: TextStyle(
                              color: darkText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Image.asset("assets/ride_notification_icon.png",
                        height: 28),
                  ],
                ),
              ),
            ),
          ),

          // White rounded sheet: live map + status card + cancel button.
          Container(
            margin: const EdgeInsets.only(top: 115),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              child: Stack(
                children: [
                  // Live map: real pickup pin + the actual nearby vehicles from
                  // the backend (GET /booking/nearby-drivers) plotted at their
                  // real positions, refreshed every 5s.
                  Positioned.fill(
                    child: Obx(() => GoogleMapWidget(
                          centerLat: _bc.pickupLat.value,
                          centerLng: _bc.pickupLng.value,
                          zoom: 17,
                          // Blue pickup pin (instead of the default green).
                          pickupMarkerHue: BitmapDescriptor.hueAzure,
                          pickupLat: _bc.pickupLat.value,
                          pickupLng: _bc.pickupLng.value,
                          nearbyVehicles: _bc.nearbyDrivers.toList(),
                          interactive: false,
                          // Render a full (non-lite) map. Lite mode shows a
                          // static snapshot that renders blank/white here and
                          // whose camera doesn't follow the pickup, so it
                          // looked zoomed-in on the wrong spot.
                          liteModeEnabled: false,
                          showMyLocation: false,
                          showZoomButtons: false,
                        )),
                  ),

                  // Bottom panel: one cohesive white sheet docked to the
                  // bottom holding the search status + cancel action, so the
                  // text/button no longer float bare over the map tiles.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding:
                          EdgeInsets.fromLTRB(20, 22, 20, 18 + bottomInset),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Finding nearby drivers…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: darkText,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Obx(() => Text(
                                _statusSubtitle(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF6B7178),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              )),
                          const SizedBox(height: 14),
                          const Text(
                            'We are connecting you with the nearest driver 🚗',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9AA0A6),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Cancel Booking button (full width)
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: _cancelBooking,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cancelRed,
                                side: BorderSide(color: cancelRed, width: 1.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Cancel Booking",
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
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
