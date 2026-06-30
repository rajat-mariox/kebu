import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Screens/CleaningModule/HouseholdLiveTracking/household_live_tracking_screen.dart';
import 'package:kebu_customer/Services/household_api_service.dart';

/// Shown right after a household booking is placed. For up to [waitSeconds] it
/// pulses an animation ("Your booking will be accepted within a minute") and
/// polls the booking status. If a partner accepts → the order-placed screen; if
/// the timer runs out with no partner → the booking is auto-cancelled.
class ServiceWaitingScreen extends StatefulWidget {
  final String bookingId;
  final int waitSeconds;

  const ServiceWaitingScreen({
    super.key,
    required this.bookingId,
    this.waitSeconds = 60,
  });

  @override
  State<ServiceWaitingScreen> createState() => _ServiceWaitingScreenState();
}

class _ServiceWaitingScreenState extends State<ServiceWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _countdownTimer;
  Timer? _pollTimer;
  late int _remaining;
  bool _resolved = false;
  // The minute ran out with no partner — show the "Search again / Cancel"
  // choice instead of auto-cancelling. Polling keeps running underneath so a
  // late accept still advances automatically.
  bool _timedOut = false;
  bool _searching = false;
  int _round = 1;

  static const _acceptedStatuses = {
    'ACCEPTED',
    'PROVIDER_ASSIGNED',
    'PROVIDER_EN_ROUTE',
    'PROVIDER_ARRIVED',
    'IN_PROGRESS',
  };

  static final Color _pink = HexColor('#E61978');
  static final Color _purple = HexColor('#461E98');

  @override
  void initState() {
    super.initState();
    _remaining = widget.waitSeconds;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _onTimeout();
      } else {
        setState(() => _remaining -= 1);
      }
    });

    // Poll the booking status — a partner accept flips it to PROVIDER_ASSIGNED.
    _pollTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => _checkStatus());
    _checkStatus();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _cleanupTimers();
    super.dispose();
  }

  void _cleanupTimers() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
  }

  Future<void> _checkStatus() async {
    if (_resolved) return;
    final res = await HouseholdApiService.getBookingDetails(widget.bookingId);
    if (!mounted || _resolved) return;
    if (res.success && res.data != null) {
      final data = res.data;
      final raw = (data['booking'] is Map) ? data['booking'] : data;
      if (raw is! Map) return;
      final b = Map<String, dynamic>.from(raw);
      final status = (b['status'] ?? '').toString();
      if (_acceptedStatuses.contains(status)) _onAccepted(b);
    }
  }

  /// Partner accepted → straight to the live tracking screen so the customer can
  /// watch the partner approach (and see the start OTP).
  void _onAccepted(Map<String, dynamic> booking) {
    if (_resolved) return;
    _resolved = true;
    _cleanupTimers();
    final provider = (booking['providerId'] is Map)
        ? Map<String, dynamic>.from(booking['providerId'])
        : <String, dynamic>{};
    final address = (booking['address'] is Map)
        ? Map<String, dynamic>.from(booking['address'])
        : <String, dynamic>{};
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HouseholdLiveTrackingScreen(
          bookingId: widget.bookingId,
          provider: provider,
          destinationLat: (address['lat'] as num?)?.toDouble() ?? 0,
          destinationLng: (address['lng'] as num?)?.toDouble() ?? 0,
          destinationAddress: (address['fullAddress'] ?? '').toString(),
          otp: (booking['otp'] ?? '').toString(),
        ),
      ),
    );
  }

  /// The minute elapsed with no partner. Don't cancel — pause the countdown and
  /// offer "Search again". Polling keeps running so a late accept still routes
  /// the customer straight into tracking.
  void _onTimeout() {
    if (_resolved || _timedOut) return;
    _countdownTimer?.cancel();
    setState(() => _timedOut = true);
  }

  /// Re-broadcast the still-pending booking to online partners and restart the
  /// one-minute search.
  Future<void> _searchAgain() async {
    if (_resolved || _searching) return;
    setState(() => _searching = true);
    final res = await HouseholdApiService.searchAgain(widget.bookingId);
    if (!mounted || _resolved) return;

    // A partner may have accepted in the meantime — route into tracking.
    final data = res.data;
    final raw = (data is Map && data['booking'] is Map) ? data['booking'] : data;
    if (raw is Map) {
      final b = Map<String, dynamic>.from(raw);
      if (_acceptedStatuses.contains((b['status'] ?? '').toString())) {
        _onAccepted(b);
        return;
      }
    }

    setState(() {
      _round += 1;
      _remaining = widget.waitSeconds;
      _timedOut = false;
      _searching = false;
    });
    // Restart the countdown; the poll timer is still running from initState.
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _onTimeout();
      } else {
        setState(() => _remaining -= 1);
      }
    });
    _checkStatus();
  }

  Future<void> _cancelManually() async {
    if (_resolved) return;
    _resolved = true;
    _cleanupTimers();
    await HouseholdApiService.cancelBooking(widget.bookingId,
        reason: 'Cancelled by user');
    if (mounted) Navigator.of(context).pop();
  }

  String get _mmss {
    final m = _remaining ~/ 60;
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
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
                                LinearGradient(colors: [_pink, _purple]),
                          ),
                          child: const Icon(Icons.cleaning_services,
                              color: Colors.white, size: 44),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              if (_timedOut) ...[
                Text(
                  'No partner accepted yet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'All partners are busy right now. You can search again to '
                  'notify them once more, or cancel.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              ] else ...[
                Text(
                  _mmss,
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: _purple,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Your booking will be accepted within a minute',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _round > 1
                      ? 'Search round $_round — connecting you with a nearby partner.'
                      : 'Please wait while we connect you with a nearby partner.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const Spacer(),
              if (_timedOut)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _searchAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _searching
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Search again',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              TextButton(
                onPressed: _searching ? null : _cancelManually,
                child: Text(
                  'Cancel booking',
                  style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
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
          border: Border.all(color: _pink, width: 2),
        ),
      ),
    );
  }
}
