import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:pinput/pinput.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kebu_driver/CommonWidgets/osm_nav_view.dart';
import 'package:kebu_driver/CommonWidgets/swipe_button.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:kebu_driver/Screens/DriverModule/CollectCashScreen/collect_cash_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/TripSummeryPage/trip_summery_page.dart';
import 'package:kebu_driver/Screens/DriverModule/FaqScreen/faq_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/HomeScreen/home_screen.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';

/// Reusable Figma palette constants. Kept local to this screen so the
/// visual tokens stay close to the layout that consumes them.
class _FigmaTokens {
  static final yellow = HexColor("#FFD546");
  static final gray1 = HexColor("#132235"); // titles
  static final gray2 = HexColor("#364B63"); // body
  static final gray4 = HexColor("#94A3B3"); // drag handle
  static final border = HexColor("#E1E6EF");
  static final background = HexColor("#F0F5FA");
  static final error = HexColor("#E02D3C");
  static final otpBoxBg = HexColor("#F5F5F5");
}

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({super.key});
  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final DriverBookingController _bc = Get.find<DriverBookingController>();
  final TextEditingController _otpController = TextEditingController();
  final List<Worker> _workers = [];

  // ── Draggable "On Route" sheet sizing (fractions of screen height) ──
  // Free drag (no snap): follows the finger, stays where released.
  static const double _minFrac = 0.30;
  static const double _maxFrac = 0.92;
  static const double _initialFrac = 0.66;

  @override
  void initState() {
    super.initState();
    _workers.add(ever<DriverRideState>(_bc.rideState, (state) {
      if (!mounted) return;
      if (state == DriverRideState.completed) {
        // Cash rides are completed from the CollectCashScreen itself (after
        // the driver swipes "Collected Fare"), so don't navigate here for
        // cash — that screen is already on top and drives reset → Home.
        // Non-cash (UPI/wallet/card) payments are already cleared by the
        // customer side, so jump straight to the summary.
        if (_bc.paymentMethod.value.toUpperCase() != 'CASH') {
          pushTo(context, const TripSummeryPage());
        }
      } else if (state == DriverRideState.idle) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }));
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _otpController.dispose();
    super.dispose();
  }

  // ───────────────────────── helpers ─────────────────────────

  String _shortBookingId() {
    final id = _bc.bookingId.value;
    if (id.isEmpty) return '#--------';
    return '#${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Scheduled pickup/start time formatted like "10:15 PM" for the "Start In"
  /// row. Reads the raw booking payload; falls back to "—" when not scheduled.
  String _startInText() {
    final req = _bc.pendingRequest.value;
    final raw = req?['scheduledFor'] ??
        req?['scheduledTime'] ??
        req?['pickupTime'];
    if (raw == null) return '—';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _callCustomer() async {
    final phone = _bc.customerPhone.value.trim();
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: 'Customer phone not available');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: 'Could not start dialer');
    }
  }

  /// Trip-end action. Cash rides are NOT completed here — we open the
  /// collect-cash screen with the ride still active so the customer stays
  /// attached until the driver collects the fare; completion (and customer
  /// detach) happens there. Prepaid rides complete immediately.
  void _onCompleteTrip() {
    if (_bc.isLoading.value) return;
    if (_bc.paymentMethod.value.toUpperCase() == 'CASH') {
      pushTo(context, const CollectCashScreen());
    } else {
      _bc.completeRide();
    }
  }

  void _openDirections() {
    final isPickupPhase = _bc.rideState.value != DriverRideState.inProgress;
    final lat = isPickupPhase ? _bc.pickupLat.value : _bc.dropLat.value;
    final lng = isPickupPhase ? _bc.pickupLng.value : _bc.dropLng.value;
    final label =
        isPickupPhase ? _bc.pickupAddress.value : _bc.dropAddress.value;
    _bc.openExternalNavigation(lat, lng,
        label: label.isNotEmpty ? label : (isPickupPhase ? 'Pickup' : 'Drop'));
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    // Guard the system/gesture back too: if this screen is the only route on
    // the stack (e.g. opened straight from a push notification) popping would
    // leave a black screen, so fall back to the Home screen instead.
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          replaceRoute(context, const HomeScreen());
        }
      },
      child: Scaffold(
      backgroundColor: _FigmaTokens.background,
      body: Obx(() {
        final state = _bc.rideState.value;
        final showOtpSheet = state == DriverRideState.arrivedAtPickup;
        final isInProgress = state == DriverRideState.inProgress;
        final screenHeight = MediaQuery.of(context).size.height;

        // Live navigation: draw the active route from the driver's current
        // position to the leg destination (it shrinks as they progress);
        // fall back to the full pickup→drop route until the active one loads.
        final route = (_bc.routePolyline.value?.isNotEmpty ?? false)
            ? _bc.routePolyline.value
            : _bc.tripRoutePolyline.value;

        // The destination the driver is heading to right now: the pickup
        // while en route to collect, the drop once the trip is in progress.
        final focusLat = isInProgress ? _bc.dropLat.value : _bc.pickupLat.value;
        final focusLng = isInProgress ? _bc.dropLng.value : _bc.pickupLng.value;

        return Stack(
          children: [
            // Full-screen free OpenStreetMap navigation (no token/billing):
            // live-tracks the driver toward the destination with the route
            // drawn. Replaces the Google map on the start-trip screen.
            Positioned.fill(
              child: OsmNavView(
                driverLat: _bc.currentLat.value,
                driverLng: _bc.currentLng.value,
                destLat: focusLat,
                destLng: focusLng,
                pickupLat: _bc.pickupLat.value,
                pickupLng: _bc.pickupLng.value,
                dropLat: _bc.dropLat.value,
                dropLng: _bc.dropLng.value,
                routePolyline: route,
                bottomPadding: screenHeight * 0.5,
              ),
            ),

            // Frosted scrim while OTP sheet is up (matches Figma node 131:10458)
            if (showOtpSheet)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),

            // Top yellow app bar
            _appBar(state),

            // Floating destination pill (Figma 131:10576) — shown during
            // the trip-in-progress phase so the driver always sees where
            // they're heading even when the bottom sheet is compact.
            if (isInProgress) _destinationPill(),

            // Bottom sheet — content depends on phase. The "On Route" sheet
            // is draggable; the OTP/complete sheets stay pinned.
            if (showOtpSheet)
              Align(alignment: Alignment.bottomCenter, child: _otpSheet())
            else if (isInProgress)
              Align(
                  alignment: Alignment.bottomCenter,
                  child: _completeRideSheet())
            else
              DraggableScrollableSheet(
                initialChildSize: _initialFrac,
                minChildSize: _minFrac,
                maxChildSize: _maxFrac,
                builder: (context, scrollController) =>
                    _onRouteSheet(state, scrollController),
              ),
          ],
        );
      }),
      ),
    );
  }

  // ───────────────────────── app bar ─────────────────────────

  Widget _appBar(DriverRideState state) {
    final title = state == DriverRideState.arrivedAtPickup
        ? 'Start Trip'
        : state == DriverRideState.inProgress
            ? 'On Trip'
            : 'On Route';

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 12, 16, 18),
        color: _FigmaTokens.yellow,
        child: Row(
          children: [
            InkWell(
              onTap: () => safeBack(context, const HomeScreen()),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: AssetIcon('assets/active_ride/arrow_left.svg',
                  width: 28,
                  height: 28,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 25 / 20,
                  color: _FigmaTokens.gray1,
                ),
              ),
            ),
            const AssetIcon('assets/active_ride/filter.svg',
              width: 28,
              height: 28,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── on-route / in-progress sheet ─────────────────────────

  Widget _onRouteSheet(DriverRideState state, ScrollController scrollController) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
      // Driven by DraggableScrollableSheet's controller → dragging anywhere
      // on the sheet moves it (free, no snap); content scrolls when expanded.
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.only(bottom: 12 + bottomInset),
        children: [
          _sheetHeader(
            title: state == DriverRideState.inProgress
                ? 'In Progress'
                : 'One Way',
            subtitle:
                _bc.vehicleType.value.isNotEmpty ? _bc.vehicleType.value : '—',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _infoCard(),
                const SizedBox(height: 16),
                _actionRow(),
                const SizedBox(height: 16),
                _earningsCard(),
                const SizedBox(height: 16),
                _supportRow(),
                const SizedBox(height: 12),
                _atPickupButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Figma "At Pickup" CTA (131:10413): yellow button with a white chevron
  /// box on the left, the label centred and a faded decoration on the right.
  Widget _atPickupButton() {
    final loading = _bc.isLoading.value;
    return GestureDetector(
      onTap: loading ? null : _onAtPickupTap,
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _FigmaTokens.yellow,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.2,
                  child: Image.asset('assets/dashboard/button_rect.png',
                      width: 64, height: 64, fit: BoxFit.contain),
                ),
              ),
            ),
            Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF132234)),
                      ),
                    )
                  : Text(
                      'At Pickup',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 22 / 17,
                        color: const Color(0xFF132234),
                      ),
                    ),
            ),
            Positioned(
              left: 2,
              top: 2,
              bottom: 2,
              width: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const AssetIcon('assets/dashboard/chevron.svg',
                    width: 24, height: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAtPickupTap() {
    if (_bc.isLoading.value) return;
    // No geofence guard here: the customer-supplied OTP on the next sheet is
    // the actual proof of presence. Blocking the button would just trap the
    // driver when GPS is noisy or the pickup pin is slightly off the road.
    _bc.arrivedAtPickup();
  }

  // ───────────────────────── destination pill (Figma 131:10576) ─────────────────────────

  /// White rounded pill floating just under the app bar that shows the
  /// drop address while the trip is in progress.
  Widget _destinationPill() {
    final addr = _bc.dropAddress.value.isNotEmpty
        ? _bc.dropAddress.value
        : 'Drop location';
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 12 + 60, // below app bar
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _FigmaTokens.yellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: AssetIcon('assets/active_ride/location.svg',
                  width: 16, height: 16, color: _FigmaTokens.yellow),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                addr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 18 / 14,
                  color: HexColor('#282F39'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── complete-ride sheet (Figma 131:10583) ─────────────────────────

  /// Compact bottom sheet shown while the trip is in progress: time +
  /// distance to drop on the left, a small call button on the right, and
  /// a yellow COMPLETE button below. Replaces the full info-card stack
  /// once the customer is in the car.
  Widget _completeRideSheet() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _bc.routeDurationMin.value != null
                                  ? '${_bc.routeDurationMin.value} min'
                                  : '— min',
                              style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: HexColor('#282F39'),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              _formatDistance(_bc.distanceToDropMeters),
                              style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: HexColor('#282F39'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bc.dropAddress.value.isNotEmpty
                              ? 'To ${_bc.dropAddress.value.split(',').first}'
                              : 'To Drop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: HexColor('#7F7F7F'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Call button — square with yellow border (Figma 131:10599)
                  InkWell(
                    onTap: _callCustomer,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _FigmaTokens.yellow),
                      ),
                      alignment: Alignment.center,
                      child: AssetIcon(
                        'assets/active_ride/call_calling.svg',
                        width: 18,
                        height: 18,
                        color: _FigmaTokens.yellow,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwipeButton(
                label: 'Swipe to COMPLETE',
                loading: _bc.isLoading.value,
                onConfirmed: _onCompleteTrip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── sheet header ─────────────────────────

  Widget _sheetHeader({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _FigmaTokens.gray4,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 25 / 20,
                      color: _FigmaTokens.gray1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 20 / 15,
                      color: _FigmaTokens.gray1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 26,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _FigmaTokens.yellow,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _shortBookingId(),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 13 / 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── info card (clock/customer/location) ─────────────────────────

  Widget _infoCard() {
    final addressLabel = _bc.pickupAddress.value.isNotEmpty
        ? _bc.pickupAddress.value
        : 'Pickup location';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _FigmaTokens.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(
            icon: 'assets/active_ride/clock.svg',
            label: 'Start In',
            value: _startInText(),
          ),
          _divider(),
          _infoRow(
            icon: 'assets/active_ride/profile_circle.svg',
            label: 'Customer Name',
            value: _bc.customerName.value.isNotEmpty
                ? _bc.customerName.value
                : (_bc.customerPhone.value.isNotEmpty
                    ? _bc.customerPhone.value
                    : '—'),
          ),
          _divider(),
          _infoRowMultiline(
            icon: 'assets/active_ride/location.svg',
            text: addressLabel,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AssetIcon(icon, width: 20, height: 20, color: _FigmaTokens.yellow),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 20 / 15,
              color: _FigmaTokens.gray1,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 18 / 13,
            color: _FigmaTokens.gray2,
          ),
        ),
      ],
    );
  }

  Widget _infoRowMultiline({required String icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssetIcon(icon, width: 20, height: 20, color: _FigmaTokens.yellow),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 18 / 13,
              color: _FigmaTokens.gray2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(height: 1, color: _FigmaTokens.border),
      );

  // ───────────────────────── action row (Contact / Get Directions / ID Card) ─────────────────────────

  Widget _actionRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _FigmaTokens.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _actionItem(
                icon: 'assets/active_ride/call_calling.svg',
                label: 'Contact',
                onTap: _callCustomer,
              ),
            ),
            VerticalDivider(
                width: 1,
                thickness: 1,
                color: _FigmaTokens.border,
                indent: 0,
                endIndent: 0),
            Expanded(
              child: _actionItem(
                icon: 'assets/active_ride/route_square.svg',
                label: 'Get Directions',
                onTap: _openDirections,
              ),
            ),
            VerticalDivider(
                width: 1,
                thickness: 1,
                color: _FigmaTokens.border,
                indent: 0,
                endIndent: 0),
            Expanded(
              child: _actionItem(
                icon: 'assets/active_ride/user_tag.svg',
                label: 'ID Card',
                onTap: () =>
                    Fluttertoast.showToast(msg: 'ID card coming soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionItem({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _FigmaTokens.yellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: AssetIcon(icon,
                  width: 18, height: 18, color: _FigmaTokens.yellow),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: HexColor('#132234'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── earnings card ─────────────────────────

  Widget _earningsCard() {
    final fare = _bc.estimatedFare.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _FigmaTokens.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: AssetIcon('assets/active_ride/rupee.svg',
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
                    color: _FigmaTokens.gray1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your estimated earnings',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: _FigmaTokens.gray2,
                  ),
                ),
              ],
            ),
          ),
          // The "+ ₹150" tip indicator from Figma — only shown when fare > 0.
          if (fare > 0)
            Text(
              '+ ₹${(fare * 0.1).toStringAsFixed(0)}',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 20 / 15,
                color: _FigmaTokens.yellow,
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────── support row (Help / Raise Ticket) ─────────────────────────

  Widget _supportRow() {
    return Row(
      children: [
        Expanded(
          child: _supportTile(
            icon: 'assets/active_ride/call_linear.svg',
            label: 'Help & Support',
            color: HexColor('#132234'),
            onTap: () => pushTo(context, const FaqScreen()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _supportTile(
            icon: 'assets/active_ride/ticket.svg',
            label: 'Raise Ticket',
            color: _FigmaTokens.error,
            onTap: () => pushTo(context, const FaqScreen()),
          ),
        ),
      ],
    );
  }

  Widget _supportTile({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _FigmaTokens.border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AssetIcon(icon, width: 20, height: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── OTP sheet (arrivedAtPickup state) ─────────────────────────

  Widget _otpSheet() {
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sheet header — "Please Enter the OTP" / "to confirm your ride."
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _FigmaTokens.gray4,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Please Enter the OTP',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 25 / 20,
                              color: _FigmaTokens.gray1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'to confirm your ride.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 20 / 15,
                              color: _FigmaTokens.gray1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _FigmaTokens.yellow,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        _shortBookingId(),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 13 / 11,
                          color: HexColor('#132234'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // OTP input — 4 boxes spread evenly across the sheet width.
            // The Figma design ships with 6 boxes; with our 4-digit OTP the
            // visual fix is to widen each box and use generous spacing so
            // the row reads as a balanced "Enter OTP" group rather than
            // four squares clumped on one side.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter OTP',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 18 / 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Pinput(
                      controller: _otpController,
                      length: 4,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      separatorBuilder: (_) => const SizedBox(width: 16),
                      defaultPinTheme: _otpBoxTheme(focused: false),
                      focusedPinTheme: _otpBoxTheme(focused: true),
                      submittedPinTheme: _otpBoxTheme(focused: false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _earningsCard(),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SwipeButton(
                label: 'Swipe to Verify Ride',
                loading: _bc.isLoading.value,
                onConfirmed: _verifyOtp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      Fluttertoast.showToast(msg: 'Please enter 4-digit OTP');
      return;
    }
    final ok = await _bc.startRide(otp);
    if (!ok && mounted) {
      Fluttertoast.showToast(msg: 'Invalid OTP, please try again');
    }
  }

  /// Shared theme for the 4 OTP boxes — wider than the Figma's 50px so the
  /// row balances visually across the sheet width with only 4 inputs.
  PinTheme _otpBoxTheme({required bool focused}) {
    return PinTheme(
      width: 64,
      height: 56,
      textStyle: GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _FigmaTokens.gray1,
      ),
      decoration: BoxDecoration(
        color: _FigmaTokens.otpBoxBg,
        borderRadius: BorderRadius.circular(8),
        border: focused
            ? Border.all(color: _FigmaTokens.yellow, width: 1.5)
            : null,
      ),
    );
  }
}
