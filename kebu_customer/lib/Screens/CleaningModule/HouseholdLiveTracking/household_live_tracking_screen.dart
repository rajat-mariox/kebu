import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Screens/Screens/DashboardScreen/dashboard_screen.dart';
import 'package:kebu_customer/Services/socket_service.dart';

/// Live map of the service provider travelling to the booking address.
/// Mirrors the cab LiveTrackingScreen but for household service bookings.
class HouseholdLiveTrackingScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? provider;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;

  /// Service-start OTP the customer shares with the partner to begin the work.
  final String otp;

  const HouseholdLiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    this.provider,
    this.otp = '',
  });

  @override
  State<HouseholdLiveTrackingScreen> createState() =>
      _HouseholdLiveTrackingScreenState();
}

class _HouseholdLiveTrackingScreenState
    extends State<HouseholdLiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Map<String, dynamic>>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _paymentSub;
  bool _navigatedHome = false;

  double? _providerLat;
  double? _providerLng;
  String _status = 'PROVIDER_ASSIGNED';

  // Minimal tokens — the sheet is intentionally white/neutral.
  static final Color _accent = HexColor('#D50069');
  static final Color _ink = HexColor('#1B1D21');

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    SocketService().connect();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _locationSub = SocketService().onProviderLocation.listen((data) {
      if (!mounted) return;
      if (data['bookingId']?.toString() != widget.bookingId) return;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() {
        _providerLat = lat;
        _providerLng = lng;
      });
    });

    _statusSub = SocketService().onServiceBookingStatus.listen((data) {
      if (!mounted) return;
      final bookingId = data['bookingId']?.toString();
      if (bookingId != widget.bookingId) return;
      final status = (data['status'] ?? '').toString();
      if (status.isEmpty) return;
      // Cancelled → straight back home. Completed → keep the customer here
      // showing "Service completed" until the partner collects payment, which
      // triggers the Thank-you popup below.
      if (status == 'CANCELLED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking was cancelled')),
        );
        _goHome();
        return;
      }
      setState(() => _status = status);
    });

    // Partner collected the payment → thank the customer, then go home.
    _paymentSub = SocketService().onServicePaymentReceived.listen((data) {
      if (!mounted) return;
      if (data['bookingId']?.toString() != widget.bookingId) return;
      _showThankYouAndGoHome();
    });
  }

  void _goHome() {
    if (_navigatedHome || !mounted) return;
    _navigatedHome = true;
    replaceRoute(context, const DashboardScreen());
  }

  /// "Thank you" popup shown when the partner collects the payment, then the
  /// customer is returned to the home screen after a short pause.
  void _showThankYouAndGoHome() {
    if (_navigatedHome || !mounted) return;
    _navigatedHome = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                    color: HexColor('#34A853'), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Thank You!',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16243B))),
              const SizedBox(height: 8),
              Text('Your payment was received. Have a great day!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close popup
      replaceRoute(context, const DashboardScreen());
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    _paymentSub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Widget _otpDigit(String d) {
    return Container(
      width: 38,
      height: 46,
      margin: const EdgeInsets.only(left: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.14)),
      ),
      child: Text(d,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
    );
  }

  /// Small pulsing Kebu mark shown while waiting for the partner to start the
  /// service — a subtle brand animation.
  Widget _kebuPulse() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.88, end: 1.06).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          'assets/logo/launcher_icon.png',
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.cleaning_services, size: 22, color: _accent),
        ),
      ),
    );
  }

  /// The start OTP is only useful until the partner starts the service.
  bool get _otpStillNeeded =>
      _status != 'IN_PROGRESS' && _status != 'COMPLETED';

  String get _statusLabel {
    switch (_status) {
      case 'PROVIDER_EN_ROUTE':
        return 'Provider on the way';
      case 'PROVIDER_ARRIVED':
        return 'Provider arrived';
      case 'IN_PROGRESS':
        return 'Service in progress';
      case 'COMPLETED':
        return 'Service completed';
      default:
        return 'Provider assigned';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider ?? const {};
    final providerName = (provider['fullName'] ?? 'Provider').toString();
    final providerPhone = (provider['mobileNumber'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMapWidget(
              centerLat: _providerLat ?? widget.destinationLat,
              centerLng: _providerLng ?? widget.destinationLng,
              pickupLat: widget.destinationLat,
              pickupLng: widget.destinationLng,
              driverLat: _providerLat,
              driverLng: _providerLng,
              zoom: 15,
              interactive: true,
              showMyLocation: false,
            ),
          ),

          // Back button + floating brand status chip over the map.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: HexColor('#34A853'),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _statusLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _ink),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 16),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Partner card (simple, white) — also carries the OTP.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.black.withOpacity(0.08)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: HexColor('#F4F4F6'),
                                  backgroundImage: (provider['profileImage'] !=
                                              null &&
                                          provider['profileImage']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(provider['profileImage'])
                                      : null,
                                  child: (provider['profileImage'] == null ||
                                          provider['profileImage']
                                              .toString()
                                              .isEmpty)
                                      ? const Icon(Icons.person,
                                          color: Colors.black45)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        providerName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        providerPhone.isNotEmpty
                                            ? providerPhone
                                            : 'Your service partner',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (providerPhone.isNotEmpty)
                                  InkWell(
                                    onTap: () {},
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        color: HexColor('#F4F4F6'),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.call,
                                          size: 18, color: _ink),
                                    ),
                                  ),
                              ],
                            ),
                            if (widget.otp.isNotEmpty && _otpStillNeeded) ...[
                              const SizedBox(height: 12),
                              Divider(
                                  height: 1,
                                  color: Colors.black.withOpacity(0.06)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _kebuPulse(),
                                  const SizedBox(width: 10),
                                  Text(
                                    'OTP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                  const Spacer(),
                                  ...widget.otp.split('').map(_otpDigit),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, color: _accent, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.destinationAddress,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
