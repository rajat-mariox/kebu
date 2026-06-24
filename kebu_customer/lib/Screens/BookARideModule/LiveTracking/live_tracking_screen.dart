import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/book_a_ride_appbar.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/DestinationSummeryScreen/destination_summery_screen.dart';
import 'package:kebu_customer/Services/socket_service.dart';
import 'package:kebu_customer/Utils/ApiClient/api_client.dart';

/// Shows real-time driver location, ETA, OTP, driver info (masked phone),
/// and cancel/SOS buttons while an active ride is ongoing.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});
  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final BookingController _bc = Get.find<BookingController>();

  @override
  void initState() {
    super.initState();
    // Navigate away when ride completes
    ever(_bc.state, (BookingState s) {
      if (!mounted) return;
      if (s == BookingState.completed) {
        replaceRouteKeepingRoot(context, DestinationSummeryScreen(bookingId: _bc.bookingId.value));
      } else if (s == BookingState.cancelled) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Ride',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to cancel this ride?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _bc.cancelBooking();
    }
  }

  /// Back navigation handler. While the ride has not started yet (still
  /// searching / driver assigned / driver arriving) leaving the screen must
  /// also cancel the booking, otherwise the request stays live and a driver
  /// could accept a ride the customer already abandoned. Once the ride is in
  /// progress we keep it running in the background and just return to the
  /// Dashboard.
  Future<void> _handleBack() async {
    final s = _bc.state.value;
    final canCancel = s == BookingState.searching ||
        s == BookingState.driverAssigned ||
        s == BookingState.driverArrived;
    if (canCancel) {
      await _bc.cancelBooking();
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      backgroundColor: HexColor('#FFD546'),
      body: Stack(
        children: [
          // ── Yellow app bar: back + "Book a cab" + notification bell ──
          bookARideAppBar(
            height: 150,
            context: context,
            child: Padding(
              padding: const EdgeInsets.only(top: 50, left: 12, right: 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: _handleBack,
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios,
                            size: 20, color: Colors.black),
                        const SizedBox(width: 4),
                        Text("Book a cab",
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Notification bell (with unread dot) — matches Figma header.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 28, color: Colors.black),
                      Positioned(
                        right: 3,
                        top: 2,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD40000),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Map area (rounded top corners) overlapping the app bar ──
          Container(
            margin: const EdgeInsets.only(top: 110),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32)),
              child: Stack(
                children: [
                  // Live Google Map — Navigation-SDK-style camera follows the
                  // driver in real time, with the vehicle marker rotating to the
                  // live heading so the customer sees exactly where the driver
                  // is and which way they're moving. Bottom padding keeps the
                  // vehicle framed above the info card.
                  Obx(() {
                    final st = _bc.state.value;
                    final inProgress = st == BookingState.inProgress;
                    // Keep the camera trailing the car for the whole live ride:
                    // toward the pickup before boarding, then toward the drop
                    // once the trip starts (Uber-style).
                    final tracking = st == BookingState.driverAssigned ||
                        st == BookingState.driverArrived ||
                        inProgress;
                    return GoogleMapWidget(
                      pickupLat: _bc.pickupLat.value,
                      pickupLng: _bc.pickupLng.value,
                      dropLat: _bc.dropLat.value,
                      dropLng: _bc.dropLng.value,
                      driverLat: _bc.driverLat.value,
                      driverLng: _bc.driverLng.value,
                      driverHeading: _bc.driverHeading.value,
                      driverVehicleType: _bc.bookedVehicleType.value,
                      // Live driver→destination road path drawn as the yellow
                      // route line. The controller already swaps this between
                      // driver→pickup and driver→drop as the ride progresses.
                      routePolyline: _bc.routePolyline.value,
                      followDriver: tracking,
                      // Turn-by-turn navigation camera while the driver is en
                      // route (rotating marker + tilted follow view).
                      navigationMode: tracking,
                      // Once the ride is in progress, frame the car against the
                      // drop so the camera tracks it all the way to the
                      // destination.
                      followTargetLat: inProgress ? _bc.dropLat.value : null,
                      followTargetLng: inProgress ? _bc.dropLng.value : null,
                      padding: const EdgeInsets.only(bottom: 300),
                      interactive: true,
                    );
                  }),

                  // ── Floating OTP pill (top-left over the map) ──
                  Positioned(top: 16, left: 16, child: _otpPill()),

                  // ── Floating Cancel Ride pill (top-right over the map) ──
                  Positioned(top: 16, right: 16, child: _cancelPill()),

                  // ── Bottom card ──
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomCard(),
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

  /// White OTP pill shown over the top-left of the map (Figma "OTP-565").
  Widget _otpPill() {
    return Obx(() {
      final otp = _bc.bookingOtp.value;
      if (otp.isEmpty) return const SizedBox.shrink();
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(69),
          border: Border.all(color: HexColor('#FFD546')),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text('OTP-$otp',
            style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HexColor('#2D3134'))),
      );
    });
  }

  /// White "Cancel Ride" pill (red text + close icon) over the top-right of the
  /// map. Only shown while the ride can still be cancelled.
  Widget _cancelPill() {
    return Obx(() {
      final canCancel = [
        BookingState.searching,
        BookingState.driverAssigned,
        BookingState.driverArrived,
      ].contains(_bc.state.value);
      if (!canCancel) return const SizedBox.shrink();
      return InkWell(
        onTap: _cancelRide,
        borderRadius: BorderRadius.circular(69),
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 8, right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(69),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, color: HexColor('#D40000'), size: 20),
              const SizedBox(width: 4),
              Text('Cancel Ride',
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: HexColor('#D40000'),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomCard() {
    return Obx(() {
      final st = _bc.state.value;
      if (st == BookingState.searching) return _searchingCard();
      if (st == BookingState.driverAssigned ||
          st == BookingState.driverArrived) {
        return _driverAssignedCard();
      }
      if (st == BookingState.inProgress) return _inProgressCard();
      return const SizedBox.shrink();
    });
  }

  // ── Searching for driver ──
  Widget _searchingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.amber),
          const SizedBox(height: 16),
          Text('Looking for nearby drivers…',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Please wait while we find you a ride',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelRide,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Cancel Booking',
                  style: GoogleFonts.poppins(
                      color: Colors.red.shade600, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Driver assigned / arrived ──
  Widget _driverAssignedCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Green "Reaching in X mins" header bar (attached to the card) ──
        Obx(() {
          final arrived = _bc.state.value == BookingState.driverArrived;
          final statusText = arrived
              ? 'Driver has arrived'
              : 'Reaching in ${_bc.etaMinutes.value > 0 ? '${_bc.etaMinutes.value} min${_bc.etaMinutes.value == 1 ? '' : 's'}' : '...'}';
          final bgColor = arrived ? HexColor('#2196F3') : HexColor('#38B763');
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(statusText,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),

        // ── Driver / fare info card (green bar above provides the rounded top) ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: HexColor('#FFD546'),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fare
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Text('To Pay',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Obx(() => Text(
                          '₹${_bc.finalFare.value.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w800))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Vehicle card
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Obx(() => Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _bc.driverInfo['vehicleName']?.toString() ??
                                        'Vehicle',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                    _bc.driverInfo['vehicleNumber']
                                            ?.toString() ??
                                        '',
                                    style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: HexColor('#0F6992'))),
                                if (_co2SavedKg() != null) ...[
                                  const SizedBox(height: 8),
                                  _co2Badge(_co2SavedKg()!),
                                ],
                              ],
                            ),
                          ),
                          _vehicleImage(),
                        ],
                      )),
                ),
                const SizedBox(height: 14),

                // Driver row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Obx(() => Row(
                        children: [
                          _driverAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    _bc.driverInfo['fullName']?.toString() ??
                                        'Driver',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                        '${_bc.driverInfo['rating'] ?? '4.5'}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 3),
                                    const Icon(Icons.star,
                                        color: Color(0xFFF5A623), size: 14),
                                    if (_ridesLabel() != null) ...[
                                      Text('   |   ',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.black45)),
                                      Text(_ridesLabel()!,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      )),
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.black.withValues(alpha: 0.10), height: 1),
                const SizedBox(height: 14),

                // Action buttons
                Row(
                  children: [
                    _actionButton(Icons.call, 'Call', HexColor('#38B562'),
                        onTap: () {
                      final phone =
                          _bc.driverInfo['mobileNumber']?.toString() ?? '';
                      if (phone.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: phone));
                        Get.snackbar('Copied', 'Driver number copied: $phone',
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    }),
                    const SizedBox(width: 10),
                    _actionButton(
                        Icons.chat_bubble_outline, 'Chat', HexColor('#015EA3'),
                        onTap: () {
                      Get.snackbar('Chat', 'Chat feature coming soon',
                          snackPosition: SnackPosition.BOTTOM);
                    }),
                    const SizedBox(width: 10),
                    _actionButton(Icons.share, 'Share', HexColor('#212020'),
                        onTap: () async {
                      final pickup = _bc.pickupAddress.value;
                      final drop = _bc.dropAddress.value;
                      final shareText =
                          'My KEBU Ride:\nPickup: $pickup\nDrop: $drop';
                      await Share.share(shareText);
                    }),
                  ],
                ),
                const SizedBox(height: 14),

                // Footer
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco, size: 15, color: HexColor('#2E7D32')),
                      const SizedBox(width: 5),
                      Text('Use Electric, Save Nature',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: HexColor('#2E7D32'))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Resolve a backend image path to a loadable URL. Returns '' for empty /
  /// "null" values so the caller can fall back to an icon.
  String _normalizeUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty || v.toLowerCase() == 'null') return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    final base = Uri.parse(ApiClient.baseUrl);
    final port = base.hasPort ? ':${base.port}' : '';
    return '${base.scheme}://${base.host}$port/${v.replaceFirst(RegExp(r'^/'), '')}';
  }

  /// Booked vehicle's image (backend-driven). Falls back to a vehicle icon so
  /// a Bike booking never shows a placeholder car.
  Widget _vehicleImage() {
    final url = _normalizeUrl(_bc.driverInfo['vehicleImage']?.toString());
    if (url.isEmpty) {
      return const Icon(Icons.directions_car, size: 44, color: Colors.black54);
    }
    return Image.network(
      url,
      height: 56,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.directions_car, size: 44, color: Colors.black54),
    );
  }

  /// Driver's profile photo (backend-driven), falling back to a person icon.
  Widget _driverAvatar() {
    final url = _normalizeUrl(_bc.driverInfo['profileImage']?.toString());
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: url.isEmpty
          ? const CircleAvatar(radius: 24, child: Icon(Icons.person))
          : Image.network(
              url,
              height: 48,
              width: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const CircleAvatar(radius: 24, child: Icon(Icons.person)),
            ),
    );
  }

  /// CO₂ saved on this electric trip vs an average petrol car (~0.12 kg/km
  /// tailpipe). Returns null when the trip distance isn't known yet so the
  /// badge is simply hidden rather than showing a fake value.
  int? _co2SavedKg() {
    final km = _bc.distanceKm.value;
    if (km <= 0) return null;
    return (km * 0.12).round();
  }

  Widget _co2Badge(int kg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: HexColor('#FFD546').withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HexColor('#E6B800').withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco, size: 13, color: HexColor('#2E7D32')),
          const SizedBox(width: 4),
          Text('$kg kg CO₂ Saved',
              style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: HexColor('#5A4A00'))),
        ],
      ),
    );
  }

  /// Driver's lifetime ride count, formatted as e.g. "2000+ Rides". Reads
  /// whichever count field the backend provides; null when none is present.
  String? _ridesLabel() {
    final raw = _bc.driverInfo['totalRides'] ??
        _bc.driverInfo['totalTrips'] ??
        _bc.driverInfo['completedRides'] ??
        _bc.driverInfo['rideCount'];
    if (raw == null) return null;
    final count = raw is num ? raw.toInt() : int.tryParse(raw.toString());
    if (count == null || count <= 0) return null;
    if (count >= 1000) return '${(count ~/ 1000) * 1000}+ Rides';
    if (count >= 100) return '${(count ~/ 100) * 100}+ Rides';
    return '$count Rides';
  }

  /// Figma action button: white fill, coloured outline + matching label/icon.
  Widget _actionButton(IconData icon, String label, Color accent,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 41,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: accent),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w500, color: accent)),
            ],
          ),
        ),
      ),
    );
  }

  /// Live header for the in-progress ride: ETA (backend) + remaining distance
  /// to the drop (derived from the live driver position) + destination label.
  /// Mirrors the Figma "Start Trip" info bar and updates as the car moves.
  Widget _destinationHeader() {
    return Obx(() {
      final eta = _bc.etaMinutes.value;
      final etaText = eta > 0 ? '$eta min' : '-- min';

      final remainingKm = _remainingKmToDrop();
      final distText = remainingKm == null
          ? ''
          : remainingKm >= 1
              ? '${remainingKm.toStringAsFixed(1)} km'
              : '${(remainingKm * 1000).round()} m';

      final dest = _bc.dropAddress.value.trim();
      final destLabel = dest.isEmpty ? 'your destination' : dest.split(',').first;

      return Row(
        children: [
          Icon(Icons.navigation_rounded, size: 18, color: HexColor('#0F6992')),
          const SizedBox(width: 8),
          Text(etaText,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          if (distText.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(width: 4, height: 4, decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text(distText,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ],
          const Spacer(),
          Flexible(
            child: Text('To $destLabel',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: Colors.grey.shade600)),
          ),
        ],
      );
    });
  }

  /// Straight-line distance (km) from the live driver position to the drop, or
  /// null when either isn't known yet so the header simply omits distance.
  double? _remainingKmToDrop() {
    final dLat = _bc.driverLat.value, dLng = _bc.driverLng.value;
    final dropLat = _bc.dropLat.value, dropLng = _bc.dropLng.value;
    if (dLat == 0 || dLng == 0 || dropLat == 0 || dropLng == 0) return null;
    return Geolocator.distanceBetween(dLat, dLng, dropLat, dropLng) / 1000.0;
  }

  // ── In progress ──
  Widget _inProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live "heading to destination" header — ETA + remaining distance
          // update in real time as the car moves toward the drop.
          _destinationHeader(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: HexColor('#4CAF50'),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('Ride in progress',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Drop',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey)),
                  Expanded(
                    child: Text(_bc.dropAddress.value,
                        style: GoogleFonts.poppins(fontSize: 13),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              )),
          const SizedBox(height: 8),
          Obx(() => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fare',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey)),
                  Text('₹${_bc.finalFare.value.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              )),
          const SizedBox(height: 16),
          // SOS button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Send SOS alert via socket
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('SOS Emergency',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    content: Text(
                        'Are you sure you want to send an emergency alert?',
                        style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Send Alert',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );

                if (confirmed == true && _bc.bookingId.value.isNotEmpty) {
                  SocketService().sendSOS(_bc.bookingId.value,
                      lat: _bc.pickupLat.value, lng: _bc.pickupLng.value);
                  Get.snackbar(
                    'SOS',
                    'Emergency alert sent to emergency services',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 5),
                  );
                }
              },
              icon: const Icon(Icons.warning_amber, color: Colors.white),
              label: Text('SOS Emergency',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
