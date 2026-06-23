import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/CommonWidgets/google_map_widget.dart';
import 'package:kebu_driver/CommonWidgets/slider_button_widget.dart';
import 'package:kebu_driver/Screens/DriverModule/ActiveRideScreen/active_ride_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Figma "Buzzer Booking For One Way" (node 131:10242).
///
/// Yellow "Take Booking" header over a full-bleed map, with a bottom sheet
/// showing the trip type, pickup / destination / earnings cards and two
/// slide-to-act buttons — slide left to Ignore, slide right to Accept.
///
/// Every value is bound to [DriverBookingController], which is populated from
/// the backend (socket `new_ride_request`, REST `/driver/app/booking/:id`, or
/// `/driver/app/booking/active`). Nothing on this screen is hardcoded.
class TakeBookingsScreen extends StatefulWidget {
  /// Optional booking id. When provided the screen hydrates the controller
  /// from the backend before rendering (e.g. opened from a notification or a
  /// bookings list). When null it binds to whatever booking the controller
  /// already holds, fetching the active booking as a fallback.
  final String? bookingId;

  const TakeBookingsScreen({super.key, this.bookingId});

  @override
  State<TakeBookingsScreen> createState() => _TakeBookingsScreenState();
}

class _TakeBookingsScreenState extends State<TakeBookingsScreen> {
  final DriverBookingController _bc = Get.find<DriverBookingController>();
  bool _loading = false;

  // ── Draggable sheet sizing (fractions of screen height) ──
  // Free drag: the sheet follows the finger and stays where released (no snap).
  static const double _minFrac = 0.18;
  static const double _maxFrac = 0.92;
  static const double _initialFrac = 0.62;

  // ── Design tokens (from the Figma variables) ──
  static final _gray1 = HexColor('#132235'); // primary text
  static final _gray2 = HexColor('#364B63'); // secondary text
  static final _gray4 = HexColor('#94A3B3'); // drag handle
  static final _gray5 = HexColor('#D3DDE7'); // metric divider
  static final _border = HexColor('#E1E6EF');
  static final _yellow = HexColor('#FFD546');
  static final _red = HexColor('#E02D3C');
  static final _bg = HexColor('#F0F5FA');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Make sure the controller holds a booking to render. Prefer an explicit
  /// id, then whatever is already loaded, then the driver's active booking.
  Future<void> _bootstrap() async {
    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      await _hydrateFromId(widget.bookingId!);
      return;
    }
    if (_bc.bookingId.value.isEmpty) {
      setState(() => _loading = true);
      await _bc.checkActiveBooking();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hydrateFromId(String id) async {
    setState(() => _loading = true);
    final res = await DriverApiService.getBookingById(id);
    if (!mounted) return;
    if (res.success && res.data is Map) {
      Map data = res.data as Map;
      if (data['booking'] is Map) data = data['booking'] as Map;
      _bc.populateFromPush(Map<String, dynamic>.from(data));
    } else {
      Fluttertoast.showToast(msg: 'Booking is no longer available');
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─────────────── formatting helpers ───────────────

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}$amPm';
  }

  String _kmFromMeters(double? meters) {
    if (meters == null || meters <= 0) return '—';
    return meters < 1000
        ? '${meters.toStringAsFixed(0)}M'
        : '${(meters / 1000).toStringAsFixed(2)}KM';
  }

  String _kmText(double km) => km > 0 ? '${km.toStringAsFixed(2)}KM' : '—';

  String _minsText(int mins) => mins > 0 ? '$mins Mins' : '—';

  /// ETA to pickup: prefer the live Google route duration; otherwise estimate
  /// from the driver→pickup distance (~3 min/km, same heuristic the backend
  /// uses when Google is unavailable). Never a hardcoded constant.
  String _pickupEta() {
    final live = _bc.routeDurationMin.value;
    if (live != null && live > 0) return _minsText(live);
    final meters = _bc.distanceToPickupMeters;
    if (meters != null && meters > 0) {
      return _minsText((meters / 1000 * 3).ceil());
    }
    return '—';
  }

  /// Trip duration: prefer the backend's quoted durationMin; otherwise derive
  /// it from the trip distance.
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
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: _bg,
      // NOTE: the Stack itself is NOT wrapped in Obx. The map and the sheet
      // each have their own reactive scope, so frequent driver-GPS updates
      // only rebuild the map — they no longer reset the draggable sheet.
      body: Stack(
        children: [
          // Full-bleed map, framed pickup→destination with the route drawn.
          // Non-interactive so it never competes with the sheet drag (same as
          // the customer "Book a Ride" preview map). bottomPadding keeps the
          // markers above the sheet.
          Positioned.fill(
            child: Obx(() => GoogleMapWidget(
                  pickupLat: _bc.pickupLat.value,
                  pickupLng: _bc.pickupLng.value,
                  dropLat: _bc.dropLat.value,
                  dropLng: _bc.dropLng.value,
                  driverLat: _bc.currentLat.value,
                  driverLng: _bc.currentLng.value,
                  routePolyline: _bc.tripRoutePolyline.value,
                  interactive: false,
                  bottomPadding: screenHeight * _initialFrac,
                )),
          ),

          _header(),

          // Draggable sheet — drag anywhere on it (free, no snap).
          DraggableScrollableSheet(
            initialChildSize: _initialFrac,
            minChildSize: _minFrac,
            maxChildSize: _maxFrac,
            builder: (context, scrollController) =>
                _bottomSheet(scrollController),
          ),

          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────── header ───────────────

  Widget _header() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        width: double.infinity,
        color: _yellow,
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 12, 16, 18),
        child: Text(
          'Take Booking',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 25 / 20,
            color: _gray1,
          ),
        ),
      ),
    );
  }

  // ─────────────── bottom sheet ───────────────

  Widget _bottomSheet(ScrollController scrollController) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 7.5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      // The ListView is driven by DraggableScrollableSheet's controller, so
      // dragging anywhere on the sheet (handle, cards, gaps) moves it. The
      // controller stays stable; only the card content is wrapped in Obx.
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.only(
            bottom: 12 + MediaQuery.of(context).padding.bottom),
        children: [
          _sheetHeader(),
          Obx(() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _pickupCard(),
                    const SizedBox(height: 8),
                    _destinationCard(),
                    const SizedBox(height: 8),
                    _earningsCard(),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          // Slide left to ignore (thumb right, chevron points left).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SliderButtonWidget(
              text: 'Ignore Booking',
              reverse: true,
              height: 48,
              thumbSize: 44,
              thumbMargin: 2,
              thumbBorderRadius: 10,
              backgroundColor: _red,
              textColor: Colors.white,
              thumbColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              textStyle: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 22 / 17,
                color: Colors.white,
              ),
              // Exported chevron points right; mirror it to point left,
              // matching the slide-left-to-ignore direction.
              thumbIcon: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: const AssetIcon(
                  'assets/booking_buzzer/chevron_left.svg',
                  width: 32,
                  height: 32,
                ),
              ),
              onSlideComplete: _onIgnore,
            ),
          ),
          const SizedBox(height: 16),
          // Slide right to accept (thumb left, chevron points right).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SliderButtonWidget(
              text: 'Accept Booking',
              height: 48,
              thumbSize: 44,
              thumbMargin: 2,
              thumbBorderRadius: 10,
              backgroundColor: _yellow,
              textColor: _gray1,
              thumbColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              textStyle: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 22 / 17,
                color: _gray1,
              ),
              thumbIcon: const AssetIcon(
                'assets/booking_buzzer/chevron_right.svg',
                width: 32,
                height: 32,
              ),
              onSlideComplete: _onAccept,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetHeader() {
    // Trip-type label only — backend has no trip-type field yet, so it
    // defaults to "One Way". The vehicle name ("bike") is intentionally NOT
    // shown here; this is the trip type, per the design.
    final type =
        _bc.tripType.value.isNotEmpty ? _bc.tripType.value : 'One Way';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Stack(
        children: [
          // Full width so the handle + title center across the sheet rather
          // than hugging the left edge.
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _gray4,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  type,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 25 / 20,
                    color: _gray1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _yellow,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AssetIcon('assets/booking_buzzer/flash.svg',
                      width: 16, height: 16),
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
    final pickupTime = _bc.scheduledAt.value ?? DateTime.now();
    return _locationCard(
      iconAsset: 'assets/booking_buzzer/pickup_marker.svg',
      title: 'Pickup',
      metrics: [
        _formatTime(pickupTime),
        _kmFromMeters(_bc.distanceToPickupMeters),
        _pickupEta(),
      ],
      address: _bc.pickupAddress.value.isNotEmpty
          ? _bc.pickupAddress.value
          : 'Pickup location',
    );
  }

  Widget _destinationCard() {
    return _locationCard(
      iconAsset: 'assets/booking_buzzer/location_pin.svg',
      title: 'Destination',
      metrics: [
        _kmText(_bc.tripDistanceKm.value),
        _tripDuration(),
      ],
      address: _bc.dropAddress.value.isNotEmpty
          ? _bc.dropAddress.value
          : 'Drop location',
    );
  }

  Widget _locationCard({
    required String iconAsset,
    required String title,
    required List<String> metrics,
    required String address,
  }) {
    return _infoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AssetIcon(iconAsset, width: 20, height: 20),
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
                        title,
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 22 / 17,
                          color: _gray1,
                        ),
                      ),
                    ),
                    _metricsRow(metrics),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: _gray2,
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
    final surge = _bc.surgeFare.value;
    return _infoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AssetIcon('assets/booking_buzzer/rupee.svg',
                width: 20, height: 20),
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
                    color: _gray1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your estimated earnings',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: _gray2,
                  ),
                ),
              ],
            ),
          ),
          if (surge > 0)
            Text(
              '+ ₹${surge.toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 20 / 15,
                color: _yellow,
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
        border: Border.all(color: _border),
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
          color: _gray5,
          margin: const EdgeInsets.symmetric(horizontal: 9),
        ));
      }
      children.add(Text(
        values[i],
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 18 / 13,
          color: _gray2,
        ),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  // ─────────────── actions ───────────────

  void _onIgnore() {
    _bc.rejectRide();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onAccept() async {
    if (_bc.bookingId.value.isEmpty) {
      Fluttertoast.showToast(msg: 'No booking to accept');
      return;
    }
    await _bc.acceptRide();
    if (mounted &&
        _bc.rideState.value == DriverRideState.navigatingToPickup) {
      Navigator.pop(context);
      pushTo(context, const ActiveRideScreen());
    }
  }
}
