import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Figma "History - Ride Details Page" (node 131:11437).
///
/// Shown when the driver taps a card in the History list. Renders the
/// trip's pickup/destination timeline, basic facts (id, type, distance,
/// duration, vehicle), and the estimated-fare card with the driver's
/// earnings highlight at the bottom. Initialised with whatever fields the
/// list already has, then refreshes from `GET /driver/app/booking/:id` to
/// pick up populated user/vehicle blocks.
class RideDetailScreen extends StatefulWidget {
  final Map<String, dynamic> initial;
  const RideDetailScreen({super.key, required this.initial});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray1Alt = HexColor('#132234');
  static final _border = HexColor('#E1E6EF');
  static final _bgGray = HexColor('#F0F5FA');
  static final _blue = HexColor('#2F6FED');

  late Map<String, dynamic> _booking;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.initial);
    _refresh();
  }

  Future<void> _refresh() async {
    final id = (_booking['_id'] ?? _booking['id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() => _refreshing = true);
    final res = await DriverApiService.getBookingById(id);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final fresh = res.data['booking'] ?? res.data;
      if (fresh is Map) {
        setState(() {
          _booking = Map<String, dynamic>.from(fresh);
          _refreshing = false;
        });
        return;
      }
    }
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final shortId = _shortId(_booking['_id'] ?? _booking['id'] ?? '');

    final pickup = _booking['pickup'] ?? _booking['pickupLocation'] ?? {};
    final drop = _booking['drop'] ?? _booking['dropLocation'] ?? {};
    final pickupAddr =
        (pickup is Map ? pickup['address'] : '')?.toString() ?? '';
    final dropAddr = (drop is Map ? drop['address'] : '')?.toString() ?? '';

    final startedAt = _booking['rideStartedAt'] ??
        _booking['startedAt'] ??
        _booking['scheduledFor'] ??
        _booking['createdAt'];
    final endedAt = _booking['rideEndedAt'] ??
        _booking['endedAt'] ??
        _booking['completedAt'];

    final distanceKm = (_booking['distanceKm'] ?? 0).toDouble();
    final durationMin = ((_booking['durationMin'] ?? 0) as num).toInt();
    final tripType = _tripTypeLabel(_booking);
    final vehicle = _vehicleLabel(_booking);

    final estimatedFare =
        (_booking['fare'] ?? _booking['estimatedFare'] ?? 0).toDouble();
    final earned =
        (_booking['driverEarning'] ?? _booking['driverShare'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _appBar(context, '#$shortId'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pickupDestCard(
                            startedAt, pickupAddr, endedAt, dropAddr),
                        const SizedBox(height: 16),
                        _basicDetailsCard(
                          tripId: '#$shortId',
                          tripType: tripType,
                          distance: '${distanceKm.toStringAsFixed(2)} km',
                          duration: _formatDuration(durationMin),
                          vehicle: vehicle,
                        ),
                        const SizedBox(height: 16),
                        _fareCard(
                            estimatedFare: estimatedFare, earned: earned),
                        if (_refreshing)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── app bar ───────────────

  Widget _appBar(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      color: _yellow,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: AssetIcon(
                'assets/history/arrow_left.svg',
                width: 28,
                height: 28,
                color: _gray1,
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
                color: _gray1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── pickup & destination card ───────────────

  Widget _pickupDestCard(
      dynamic startedAt, String pickup, dynamic endedAt, String drop) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PICKUP & DESTINATION',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
              color: _gray1Alt,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              // Connector line between the two dots.
              Positioned(
                left: 11,
                top: 32,
                bottom: 32,
                child: Container(width: 2, color: _border),
              ),
              Column(
                children: [
                  _stop(
                    color: HexColor('#08875D'),
                    title:
                        'Started : ${_formatDateTime(startedAt) ?? '—'}',
                    address: pickup,
                  ),
                  const SizedBox(height: 8),
                  _stop(
                    color: HexColor('#E02D3C'),
                    title:
                        'Ended : ${_formatDateTime(endedAt) ?? '—'}',
                    address: drop,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stop(
      {required Color color,
      required String title,
      required String address}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 20 / 15,
                    color: _gray1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address.isEmpty ? '—' : address,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: _gray1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── basic details card ───────────────

  Widget _basicDetailsCard({
    required String tripId,
    required String tripType,
    required String distance,
    required String duration,
    required String vehicle,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BASIC DETAILS',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
              color: _gray1Alt,
            ),
          ),
          const SizedBox(height: 8),
          _detailRow('Trip ID:', tripId),
          const SizedBox(height: 16),
          _detailRow('Trip Type:', tripType),
          const SizedBox(height: 16),
          _detailRow('Trip Distance:', distance),
          const SizedBox(height: 16),
          _detailRow('Trip Duration:', duration),
          const SizedBox(height: 16),
          _detailRow('Vehicle Type:', vehicle),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 20 / 15,
              color: _gray1,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 20 / 15,
            color: _gray1,
          ),
        ),
      ],
    );
  }

  // ─────────────── fare card ───────────────

  Widget _fareCard({required double estimatedFare, required double earned}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ESTIMATED FARE DETAILS',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 16 / 12,
              color: _gray1Alt,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated Total Fare:',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 20 / 15,
                    color: _gray1,
                  ),
                ),
              ),
              Text(
                '₹${_formatFare(estimatedFare)}',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 20 / 15,
                  color: _gray1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _border),
          const SizedBox(height: 16),
          Text(
            'Earned money from trip:',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              color: _blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${_formatFare(earned > 0 ? earned : estimatedFare)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 25 / 20,
              color: _blue,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── shared card shell ───────────────

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  // ─────────────── helpers ───────────────

  String _shortId(dynamic id) {
    final s = id.toString();
    if (s.length <= 8) return s.toUpperCase();
    return s.substring(s.length - 8).toUpperCase();
  }

  String? _formatDateTime(dynamic raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      var hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day.toString().padLeft(2, '0')} '
          '${months[dt.month - 1]} '
          '${dt.year}, '
          '${hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(int mins) {
    if (mins <= 0) return '—';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m.toString().padLeft(2, '0')}min';
  }

  String _formatFare(double v) {
    if (v >= 1000) {
      final whole = v.toInt();
      final s = whole.toString();
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return v.toStringAsFixed(0);
  }

  String _tripTypeLabel(Map<String, dynamic> b) {
    final t = (b['tripType'] ?? b['rideType'] ?? '').toString();
    switch (t.toUpperCase()) {
      case 'ROUND_TRIP':
      case 'ROUND-TRIP':
      case 'ROUND':
        return 'Round Trip';
      case 'FLEXI':
        return 'Flexi';
      default:
        return 'One Way';
    }
  }

  String _vehicleLabel(Map<String, dynamic> b) {
    final vt = b['vehicleTypeId'] ?? b['vehicleType'] ?? {};
    if (vt is Map) {
      final name = (vt['name'] ?? vt['displayName'] ?? '').toString();
      final transmission = (vt['transmission'] ?? '').toString();
      if (name.isNotEmpty && transmission.isNotEmpty) {
        return '$transmission - $name';
      }
      if (name.isNotEmpty) return name;
    }
    return '—';
  }
}
