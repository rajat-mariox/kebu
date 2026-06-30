import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/CleaningModule/HouseholdLiveTracking/household_live_tracking_screen.dart';
import 'package:kebu_customer/Screens/Screens/DashboardScreen/dashboard_screen.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:kebu_customer/Services/socket_service.dart';

class CleaningOrderPlaced extends StatefulWidget {
  /// When set, the screen fetches the booking so it can show the assigned
  /// provider + the service-start OTP (which the customer shares with the
  /// partner so they can begin the work).
  final String? bookingId;

  const CleaningOrderPlaced({super.key, this.bookingId});

  @override
  State<CleaningOrderPlaced> createState() => _CleaningOrderPlacedState();
}

class _CleaningOrderPlacedState extends State<CleaningOrderPlaced> {
  static final Color _purple = HexColor('#531E96');
  static final Color _ink = HexColor('#16243B');
  static final Color _muted = HexColor('#7A8699');
  static final Color _green = HexColor('#34A853');

  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _booking;

  @override
  void initState() {
    super.initState();
    SocketService().connect();
    _acceptedSub = SocketService().onServiceBookingAccepted.listen((data) {
      if (!mounted) return;
      final provider = data['provider'];
      final booking = data['booking'];
      if (provider is Map) {
        setState(() => _provider = Map<String, dynamic>.from(provider));
      }
      if (booking is Map) {
        setState(() => _booking = Map<String, dynamic>.from(booking));
      }
    });
    // When the partner finishes (or cancels) the service, send the customer
    // back to the home screen.
    _statusSub = SocketService().onServiceBookingStatus.listen((data) {
      if (!mounted) return;
      final id = data['bookingId']?.toString();
      final myId = widget.bookingId ?? _booking?['_id']?.toString();
      if (id == null || (myId != null && id != myId)) return;
      final status = (data['status'] ?? '').toString();
      if (status == 'COMPLETED' || status == 'CANCELLED') {
        replaceRoute(context, const DashboardScreen());
      }
    });
    // Reaching this screen after a partner already accepted (e.g. via the
    // waiting screen) → fetch the booking so the OTP + provider show even
    // though the live accept event already fired.
    if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      _loadBooking();
    }
  }

  Future<void> _loadBooking() async {
    final res = await HouseholdApiService.getBookingDetails(widget.bookingId!);
    if (!mounted || !res.success || res.data == null) return;
    final data = res.data;
    final b = (data['booking'] is Map) ? data['booking'] : data;
    if (b is! Map) return;
    final booking = Map<String, dynamic>.from(b);
    setState(() {
      _booking = booking;
      if (booking['providerId'] is Map) {
        _provider = Map<String, dynamic>.from(booking['providerId']);
      }
    });
  }

  String get _otp => (_booking?['otp'] ?? '').toString();

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _openTracking() {
    final booking = _booking;
    final provider = _provider;
    if (booking == null || provider == null) return;
    final bookingId = booking['_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;
    final address = (booking['address'] is Map)
        ? Map<String, dynamic>.from(booking['address'])
        : const <String, dynamic>{};
    final lat = (address['lat'] as num?)?.toDouble();
    final lng = (address['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    pushTo(
      context,
      HouseholdLiveTrackingScreen(
        bookingId: bookingId,
        provider: provider,
        destinationLat: lat,
        destinationLng: lng,
        destinationAddress: (address['fullAddress'] ?? '').toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assigned = _provider != null;
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
                  const Spacer(),
                  const Text("Order Placed",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const Spacer(),
                  const NotificationIconButton(),
                ],
              ),
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            margin: const EdgeInsets.only(top: 120),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  children: [
                    // Small OTP section at the very top.
                    if (_otp.isNotEmpty) ...[
                      _otpTopSection(),
                      const SizedBox(height: 24),
                    ],

                    _statusBadge(assigned),
                    const SizedBox(height: 18),

                    Text(
                      assigned ? "Booking Confirmed" : "Finding a Provider…",
                      style: GoogleFonts.poppins(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      assigned
                          ? "Your partner is assigned. Track them live or relax — we'll keep you posted."
                          : "We're connecting you with a nearby professional — usually under a minute.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, color: _muted, height: 1.45),
                    ),
                    const SizedBox(height: 22),

                    if (assigned) _providerCard(),
                    if (assigned) const SizedBox(height: 26),

                    if (assigned && _booking != null) ...[
                      _primaryButton("Track Provider", _openTracking),
                      const SizedBox(height: 12),
                    ],
                    _secondaryButton(
                      "Go to Homepage",
                      () => replaceRoute(context, const DashboardScreen()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact OTP banner pinned at the top of the sheet.
  Widget _otpTopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HexColor('#F4F0FB'),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _purple.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.vpn_key_rounded, color: _purple, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Service Start OTP",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _purple)),
                Text("Share with the partner to begin",
                    style:
                        GoogleFonts.poppins(fontSize: 10.5, color: _muted)),
              ],
            ),
          ),
          Row(
            children: _otp.split('').map((d) => _otpDigit(d)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _otpDigit(String d) {
    return Container(
      width: 30,
      height: 38,
      margin: const EdgeInsets.only(left: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _purple.withOpacity(0.35)),
      ),
      child: Text(d,
          style: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700, color: _purple)),
    );
  }

  /// Green success check (assigned) or a searching spinner (finding).
  Widget _statusBadge(bool assigned) {
    return Container(
      height: 92,
      width: 92,
      decoration: BoxDecoration(
        color: (assigned ? _green : _purple).withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: assigned
          ? Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
            )
          : SizedBox(
              height: 38,
              width: 38,
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_purple)),
            ),
    );
  }

  Widget _providerCard() {
    final name = (_provider!['fullName'] ?? 'Your provider').toString();
    final phone = (_provider!['mobileNumber'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HexColor('#ECECF2')),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _purple.withOpacity(0.12),
            child: Icon(Icons.person, color: _purple, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your Partner",
                    style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                const SizedBox(height: 2),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _green,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.call, color: _green, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: HexColor('#E2E2EA')),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _ink,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: _ink, size: 18),
          ],
        ),
      ),
    );
  }
}
