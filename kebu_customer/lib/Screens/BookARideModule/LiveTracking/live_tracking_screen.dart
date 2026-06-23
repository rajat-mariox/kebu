import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── App bar ──
          bookARideAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: _handleBack,
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_ios,
                            size: 20, color: Colors.black),
                        const SizedBox(width: 3),
                        Text("Book a cab",
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // OTP badge
                  Obx(() {
                    final otp = _bc.bookingOtp.value;
                    if (otp.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text('OTP-$otp',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    );
                  }),
                  const SizedBox(width: 8),
                  // Cancel button
                  Obx(() {
                    final canCancel = [
                      BookingState.searching,
                      BookingState.driverAssigned,
                      BookingState.driverArrived,
                    ].contains(_bc.state.value);
                    if (!canCancel) return const SizedBox.shrink();
                    return InkWell(
                      onTap: _cancelRide,
                      child: Row(
                        children: [
                          Icon(Icons.close, color: Colors.red.shade600, size: 16),
                          const SizedBox(width: 2),
                          Text('Cancel Ride',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Map area ──
          Container(
            margin: const EdgeInsets.only(top: 120),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32)),
              child: Stack(
                children: [
                  // Live Google Map — camera follows the driver in real time
                  // as it approaches the pickup. Bottom padding keeps the
                  // vehicle framed above the info card.
                  Obx(() {
                    final tracking = _bc.state.value == BookingState.driverAssigned ||
                        _bc.state.value == BookingState.driverArrived;
                    return GoogleMapWidget(
                      pickupLat: _bc.pickupLat.value,
                      pickupLng: _bc.pickupLng.value,
                      dropLat: _bc.dropLat.value,
                      dropLng: _bc.dropLng.value,
                      driverLat: _bc.driverLat.value,
                      driverLng: _bc.driverLng.value,
                      driverHeading: _bc.driverHeading.value,
                      driverVehicleType: _bc.bookedVehicleType.value,
                      followDriver: tracking,
                      padding: const EdgeInsets.only(bottom: 300),
                      interactive: true,
                    );
                  }),

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
        // ── Floating ETA pill ──
        Obx(() {
          final arrived = _bc.state.value == BookingState.driverArrived;
          final statusText = arrived
              ? 'Driver has arrived'
              : 'Reaching in ${_bc.etaMinutes.value > 0 ? '${_bc.etaMinutes.value} min${_bc.etaMinutes.value == 1 ? '' : 's'}' : '...'}';
          final bgColor =
              arrived ? HexColor('#2196F3') : const Color(0xFF34C759);
          return Container(
            width: MediaQuery.of(context).size.width - 48,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
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
                        fontSize: 14.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),

        // ── Driver / fare info card ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: HexColor('#FFD546'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
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
                    _actionButton(Icons.call, 'Call', const Color(0xFF34C759),
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
                        Icons.chat_bubble_outline, 'Chat', const Color(0xFF2F6BFF),
                        onTap: () {
                      Get.snackbar('Chat', 'Chat feature coming soon',
                          snackPosition: SnackPosition.BOTTOM);
                    }),
                    const SizedBox(width: 10),
                    _actionButton(Icons.share, 'Share', Colors.black87,
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

  Widget _actionButton(IconData icon, String label, Color iconColor,
      {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(30),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
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
