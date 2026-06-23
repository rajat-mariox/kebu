import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/Screens/DriverModule/HistoryScreen/ride_detail_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Figma "History" screen (node 131:11212).
///
/// Lists the driver's past bookings grouped by day (TODAY / YESTERDAY /
/// absolute date). Each booking card shows customer, ID, date, pickup &
/// drop addresses, trip type, distance, duration, and the fare on a yellow
/// footer (paid bookings) or a light-blue footer (unpaid/refunded). Opened
/// from the home-screen "View All" affordance next to the Bookings list.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static final _yellow = HexColor('#FFD546');
  static final _yellowText = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _gray3 = HexColor('#607080');
  static final _gray6 = HexColor('#E9F0F7');
  static final _border = HexColor('#E1E6EF');
  static final _bgGray = HexColor('#F0F5FA');
  static final _blueBg = HexColor('#F0F5FF');

  bool _loading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getBookingHistory(page: 0, limit: 50);
    if (!mounted) return;
    final list = (res.success && res.data != null)
        ? (res.data['bookings'] as List<dynamic>? ?? [])
        : [];
    setState(() {
      _bookings = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(_bookings);

    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _appBar(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      child: groups.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'No bookings yet',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: _gray2,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: Colors.white,
                              child: ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 16),
                                itemCount: groups.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (_, i) {
                                  final g = groups[i];
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _dayHeader(g.label),
                                      const SizedBox(height: 16),
                                      for (int j = 0;
                                          j < g.items.length;
                                          j++) ...[
                                        _bookingCard(g.items[j]),
                                        if (j != g.items.length - 1)
                                          const SizedBox(height: 16),
                                      ],
                                    ],
                                  );
                                },
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

  Widget _appBar(BuildContext context) {
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
              'History',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 25 / 20,
                color: _gray1,
              ),
            ),
          ),
          AssetIcon(
            'assets/history/filter.svg',
            width: 28,
            height: 28,
            color: _gray1,
          ),
        ],
      ),
    );
  }

  // ─────────────── day header (TODAY / YESTERDAY / 26 FEB 2024) ───────────────

  Widget _dayHeader(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 13 / 11,
              color: _gray3,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: _border)),
      ],
    );
  }

  // ─────────────── booking card ───────────────

  Widget _bookingCard(Map<String, dynamic> booking) {
    final customer = booking['userId'] ?? booking['user'] ?? {};
    final customerName = (customer is Map ? customer['name'] : '')?.toString() ??
        'Customer';
    final shortId = _shortId(booking['_id'] ?? booking['id'] ?? '');
    final dateText = _formatDate(
        booking['scheduledFor'] ?? booking['createdAt']);
    final fare = (booking['finalFare'] ?? booking['fare'] ?? 0).toDouble();
    final distanceKm = (booking['distanceKm'] ?? 0).toDouble();
    final durationMin = ((booking['durationMin'] ?? 0) as num).toInt();
    final tripType = _tripTypeLabel(booking);
    final pickup = booking['pickup'] ?? booking['pickupLocation'] ?? {};
    final drop = booking['drop'] ?? booking['dropLocation'] ?? {};
    final pickupAddr =
        (pickup is Map ? pickup['address'] : '')?.toString() ?? '';
    final dropAddr =
        (drop is Map ? drop['address'] : '')?.toString() ?? '';

    final paid = (booking['paymentStatus'] ?? '').toString() == 'PAID' ||
        (booking['status'] ?? '').toString() == 'COMPLETED';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            pushTo(context, RideDetailScreen(initial: booking)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: name + id, calendar + date
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 20 / 15,
                            color: _gray1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: #$shortId',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 16 / 12,
                            color: _gray2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      AssetIcon(
                        'assets/history/calendar.svg',
                        width: 18,
                        height: 18,
                        color: _gray2,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateText,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 18 / 13,
                          color: _gray2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Pickup + drop addresses
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _addressRow(
                    iconColor: _yellow,
                    address: pickupAddr,
                    showDivider: true,
                  ),
                  _addressRow(
                    iconColor: HexColor('#E02D3C'),
                    address: dropAddr,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Trip type / distance / duration
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _statRow(
                      'assets/history/car_taxi.svg',
                      tripType,
                      align: MainAxisAlignment.start,
                    ),
                  ),
                  Expanded(
                    child: _statRow(
                      'assets/history/routing.svg',
                      '${distanceKm.toStringAsFixed(2)}km',
                      align: MainAxisAlignment.center,
                    ),
                  ),
                  Expanded(
                    child: _statRow(
                      'assets/history/clock.svg',
                      _formatDuration(durationMin),
                      align: MainAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: _gray6),
            // Fare footer
            Container(
              width: double.infinity,
              color: paid ? _yellow : _blueBg,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AssetIcon(
                    'assets/history/moneys.svg',
                    width: 20,
                    height: 20,
                    color: paid ? _gray2 : _yellowText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${_formatFare(fare)}',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 22 / 17,
                      color: paid ? _gray2 : _yellowText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _addressRow({
    required Color iconColor,
    required String address,
    required bool showDivider,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: _border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address.isEmpty ? '—' : address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 20 / 15,
                color: _gray1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String icon, String text,
      {required MainAxisAlignment align}) {
    return Row(
      mainAxisAlignment: align,
      children: [
        AssetIcon(icon, width: 20, height: 20, color: _gray2),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 18 / 13,
            color: _gray2,
          ),
        ),
      ],
    );
  }

  // ─────────────── helpers ───────────────

  String _shortId(dynamic id) {
    final s = id.toString();
    if (s.length <= 8) return s.toUpperCase();
    return s.substring(s.length - 8).toUpperCase();
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int mins) {
    if (mins <= 0) return '—';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
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

  List<_DayGroup> _groupByDay(List<Map<String, dynamic>> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];

    final map = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];

    for (final b in bookings) {
      final raw = b['scheduledFor'] ?? b['createdAt'];
      if (raw == null) continue;
      DateTime dt;
      try {
        dt = DateTime.parse(raw.toString()).toLocal();
      } catch (_) {
        continue;
      }
      final day = DateTime(dt.year, dt.month, dt.day);
      String label;
      if (day == today) {
        label = 'TODAY';
      } else if (day == yesterday) {
        label = 'YESTERDAY';
      } else {
        label = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      }
      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(b);
    }

    return order.map((l) => _DayGroup(label: l, items: map[l]!)).toList();
  }
}

class _DayGroup {
  final String label;
  final List<Map<String, dynamic>> items;
  _DayGroup({required this.label, required this.items});
}
