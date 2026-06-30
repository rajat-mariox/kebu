import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/google_map_widget.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/CommonWidgets/swipe_button.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:kebu_driver/Screens/DriverModule/ActiveRideScreen/active_ride_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:vibration/vibration.dart';

/// Figma "Buzzer Booking For One Way" — appears when a new ride request
/// arrives. Full-bleed map, yellow "Take Booking" header, sliding bottom
/// sheet with pickup/destination/fare cards, red Ignore + yellow Accept
/// buttons.
class RideRequestScreen extends StatefulWidget {
  /// Optional booking id — when set, the screen fetches the booking via
  /// REST and populates the controller before showing the buzzer. Used
  /// when launched from a push-notification tap (driver wasn't already in
  /// the buzzer state).
  final String? bookingId;

  const RideRequestScreen({super.key, this.bookingId});

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final DriverBookingController _bc = Get.find<DriverBookingController>();
  int _countdown = 30;
  Timer? _timer;
  StreamSubscription? _rideTakenSub;
  StreamSubscription? _rideCancelledSub;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      _hydrateFromPush();
    }

    _startAlert();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _stopAlert();
        _bc.rejectRide();
        Navigator.pop(context);
      }
    });

    _rideTakenSub = SocketService().onRideTaken.listen((data) {
      if (!mounted) return;
      _stopAlert();
      Navigator.pop(context);
    });

    // Customer cancelled while we were still showing the buzzer — dismiss the
    // request immediately instead of leaving it on screen until the countdown
    // expires. Ignore cancellations for a different booking.
    _rideCancelledSub = SocketService().onRideCancelled.listen((data) {
      if (!mounted) return;
      final cancelledId = data['bookingId']?.toString() ?? '';
      if (cancelledId.isNotEmpty &&
          _bc.bookingId.value.isNotEmpty &&
          cancelledId != _bc.bookingId.value) {
        return;
      }
      _stopAlert();
      Navigator.pop(context);
    });
  }

  Future<void> _hydrateFromPush() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getBookingById(widget.bookingId!);
    if (!mounted) return;
    if (res.success && res.data is Map) {
      Map data = res.data as Map;
      if (data['booking'] is Map) {
        data = data['booking'] as Map;
      }
      _bc.populateFromPush(Map<String, dynamic>.from(data));
    } else {
      Fluttertoast.showToast(msg: 'Booking is no longer available');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startAlert() async {
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.alarm,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (_) {}
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(
          pattern: [0, 600, 400, 600, 400, 600],
          repeat: 0,
        );
      }
    } catch (_) {}
  }

  void _stopAlert() {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopAlert();
    _timer?.cancel();
    _rideTakenSub?.cancel();
    _rideCancelledSub?.cancel();
    super.dispose();
  }

  // ─────────────── helpers ───────────────

  String _formatPickupTime() {
    try {
      final dt = _bc.scheduledAt.value ?? DateTime.now();
      var hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}$amPm';
    } catch (_) {
      return '';
    }
  }

  String _minsText(int mins) => mins > 0 ? '$mins Mins' : '—';

  /// ETA to pickup: live Google route duration, else estimated from the
  /// driver→pickup distance (~3 min/km). Never a hardcoded constant.
  String _pickupEta() {
    final live = _bc.routeDurationMin.value;
    if (live != null && live > 0) return _minsText(live);
    final meters = _bc.distanceToPickupMeters;
    if (meters != null && meters > 0) {
      return _minsText((meters / 1000 * 3).ceil());
    }
    return '—';
  }

  /// Trip duration: backend's quoted durationMin, else derived from distance.
  String _tripDuration() {
    final backend = _bc.tripDurationMin.value;
    if (backend > 0) return _minsText(backend);
    final km = _bc.tripDistanceKm.value;
    if (km > 0) return _minsText((km * 3).ceil());
    return '—';
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor('#F0F5FA'),
      body: Obx(() {
        return Stack(
          children: [
            // Full-bleed map underneath
            Positioned.fill(
              child: GoogleMapWidget(
                pickupLat: _bc.pickupLat.value,
                pickupLng: _bc.pickupLng.value,
                dropLat: _bc.dropLat.value,
                dropLng: _bc.dropLng.value,
                driverLat: _bc.currentLat.value,
                driverLng: _bc.currentLng.value,
                routePolyline: _bc.tripRoutePolyline.value,
                // Let the driver pan/zoom the visible map with their finger.
                interactive: true,
                // Keep pickup/drop framed above the bottom sheet.
                bottomPadding: MediaQuery.of(context).size.height * 0.5,
              ),
            ),

            // Yellow header
            _header(),

            // Bottom sheet — draggable so the driver can pull it down to
            // reveal and interact with the lower part of the map, then pull it
            // back up. The empty area above the sheet is transparent, so map
            // gestures there pass straight through.
            _bottomSheet(),

            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ─────────────── header ───────────────

  Widget _header() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: HexColor('#FFD546'),
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 12, 16, 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Take Booking',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 25 / 20,
                  color: HexColor('#132235'),
                ),
              ),
            ),
            // Countdown pill (auto-reject timer)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${_countdown}s',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── bottom sheet ───────────────

  Widget _bottomSheet() {
    return DraggableScrollableSheet(
      // Opens roughly where the static sheet used to sit; can be dragged down
      // to ~28% (revealing most of the map) or up to ~90%.
      initialChildSize: 0.58,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.28, 0.58, 0.9],
      builder: (context, scrollController) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 7.5,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            // Scrollable so the sheet's own drag gesture (collapse/expand) is
            // driven by this controller and the content stays reachable when
            // the sheet is dragged short on small screens.
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sheetHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        _pickupCard(),
                        const SizedBox(height: 8),
                        _destinationCard(),
                        const SizedBox(height: 8),
                        _earningsCard(),
                      ],
                    ),
                  ),
                  _ignoreButton(),
                  const SizedBox(height: 16),
                  _acceptButton(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Stack(
        children: [
          // Full width so the handle + title center across the sheet.
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HexColor('#94A3B3'),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  // Trip type only (defaults to "One Way") — not the vehicle.
                  _bc.tripType.value.isNotEmpty ? _bc.tripType.value : 'One Way',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 25 / 20,
                    color: HexColor('#132235'),
                  ),
                ),
              ],
            ),
          ),
          // "Grab now" pill
          Positioned(
            right: 0,
            top: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: HexColor('#FFD546'),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AssetIcon('assets/booking_buzzer/flash.svg',
                    width: 16,
                    height: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Grab now',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 16 / 12,
                      color: Colors.white,
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

  // ─────────────── cards ───────────────

  Widget _pickupCard() {
    final distanceMeters = _bc.distanceToPickupMeters;
    final distanceText = distanceMeters != null
        ? (distanceMeters < 1000
            ? '${distanceMeters.toStringAsFixed(0)} m'
            : '${(distanceMeters / 1000).toStringAsFixed(2)} km')
        : '—';

    return _infoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AssetIcon('assets/booking_buzzer/pickup_marker.svg',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pickup',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 22 / 17,
                          color: HexColor('#132235'),
                        ),
                      ),
                    ),
                    _metricsRow([
                      _formatPickupTime(),
                      distanceText,
                      _pickupEta(),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _bc.pickupAddress.value.isNotEmpty
                      ? _bc.pickupAddress.value
                      : 'Pickup location',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: HexColor('#364B63'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationCard() {
    // Destination metrics describe the trip itself (pickup→drop), so prefer
    // the backend's quoted trip distance; fall back to the driver→drop
    // straight-line distance only when the booking didn't carry one.
    final tripKm = _bc.tripDistanceKm.value;
    final fallbackMeters = _bc.distanceToDropMeters;
    final distanceText = tripKm > 0
        ? '${tripKm.toStringAsFixed(2)}KM'
        : (fallbackMeters != null
            ? (fallbackMeters < 1000
                ? '${fallbackMeters.toStringAsFixed(0)}M'
                : '${(fallbackMeters / 1000).toStringAsFixed(2)}KM')
            : '—');

    return _infoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AssetIcon('assets/booking_buzzer/location_pin.svg',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Destination',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 22 / 17,
                          color: HexColor('#132235'),
                        ),
                      ),
                    ),
                    _metricsRow([distanceText, _tripDuration()]),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _bc.dropAddress.value.isNotEmpty
                      ? _bc.dropAddress.value
                      : 'Drop location',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: HexColor('#364B63'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsCard() {
    final fare = _bc.estimatedFare.value;
    return _infoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AssetIcon('assets/booking_buzzer/rupee.svg',
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 22 / 17,
                    color: HexColor('#132235'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your estimated earnings',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: HexColor('#364B63'),
                  ),
                ),
              ],
            ),
          ),
          if (fare > 0)
            Text(
              '+ ₹${(fare * 0.1).toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 20 / 15,
                color: HexColor('#FFD546'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HexColor('#E1E6EF')),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metricsRow(List<String> values) {
    final children = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      if (i > 0) {
        children.add(Container(
          width: 1,
          height: 12,
          color: HexColor('#D3DDE7'),
          margin: const EdgeInsets.symmetric(horizontal: 9),
        ));
      }
      children.add(Text(
        values[i],
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 18 / 13,
          color: HexColor('#364B63'),
        ),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  // ─────────────── action buttons ───────────────

  Widget _ignoreButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      // Slide left to ignore (thumb on the right, chevron points left).
      child: SliderButtonWidget(
        text: 'Ignore Booking',
        reverse: true,
        height: 48,
        thumbSize: 44,
        thumbMargin: 2,
        thumbBorderRadius: 10,
        backgroundColor: HexColor('#E02D3C'),
        textColor: Colors.white,
        thumbColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        textStyle: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 22 / 17,
          color: Colors.white,
        ),
        // Exported chevron points right; mirror it to point left.
        thumbIcon: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(3.1415926535),
          child: const AssetIcon(
            'assets/booking_buzzer/chevron_left.svg',
            width: 32,
            height: 32,
          ),
        ),
        onSlideComplete: () {
          _stopAlert();
          _bc.rejectRide();
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _acceptButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SwipeButton(
        label: 'Swipe to Accept Booking',
        loading: _bc.isLoading.value,
        onConfirmed: _onAccept,
      ),
    );
  }

  Future<void> _onAccept() async {
    _stopAlert();
    await _bc.acceptRide();
    if (mounted &&
        _bc.rideState.value == DriverRideState.navigatingToPickup) {
      Navigator.pop(context);
      pushTo(context, const ActiveRideScreen());
    }
  }
}
