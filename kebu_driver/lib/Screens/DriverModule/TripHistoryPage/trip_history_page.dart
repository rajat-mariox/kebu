import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/Screens/DriverModule/BookingDetailScreen/booking_detail_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Figma "History" (131:11212) — yellow header (back + title + filter) over a
/// white list of past trips grouped by date (TODAY / YESTERDAY / date). Each
/// card shows customer + id + date, pickup/drop, trip-type/distance/duration
/// meta and a yellow fare strip. All data from [DriverApiService].
class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  static final _yellow = HexColor('#FFD546');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _gray3 = HexColor('#607080');
  static final _border = HexColor('#E1E6EF');
  static final _border2 = HexColor('#E9F0F7');

  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final res = await DriverApiService.getBookingHistory(page: 0, limit: 50);
    if (res.success && res.data != null && mounted) {
      final list = res.data['bookings'] as List<dynamic>? ?? [];
      setState(() {
        _bookings =
            list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────── helpers ───────────────

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _getDateLabel(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final bookingDate = DateTime(dt.year, dt.month, dt.day);
      if (bookingDate == today) return 'TODAY';
      if (bookingDate == today.subtract(const Duration(days: 1))) {
        return 'YESTERDAY';
      }
      const months = [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String _tripType(Map booking) {
    final t = (booking['tripType'] ?? booking['rideType'] ?? '')
        .toString()
        .toUpperCase();
    if (t.contains('ROUND')) return 'Round Trip';
    if (t.contains('FLEXI')) return 'Flexi';
    return 'One Way';
  }

  String _distance(Map booking) {
    final d = booking['distanceKm'] ?? booking['distance'];
    if (d is num && d > 0) return '${d.toStringAsFixed(2)}km';
    return '-';
  }

  String _duration(Map booking) {
    final m = booking['durationMin'] ?? booking['duration'];
    final mins = (m is num) ? m.toInt() : 0;
    if (mins <= 0) return '-';
    final h = mins ~/ 60;
    final mm = mins % 60;
    return h > 0 ? '${h}h ${mm}min' : '${mm}min';
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final b in _bookings) {
      final label = _getDateLabel(b['createdAt']?.toString() ?? '');
      grouped.putIfAbsent(label, () => []).add(b);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _bookings.isEmpty
                    ? Center(
                        child: Text('No trips yet',
                            style: GoogleFonts.nunito(
                                color: _gray3, fontSize: 15)),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final entry in grouped.entries) ...[
                            _groupSeparator(entry.key),
                            const SizedBox(height: 16),
                            for (final b in entry.value) ...[
                              _tripCard(b),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      color: _yellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(99),
                child: Icon(Icons.arrow_back, size: 26, color: _gray1),
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
              Image.asset('assets/filter.png',
                  height: 16, width: 22, color: _gray1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupSeparator(String label) {
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

  Widget _tripCard(Map<String, dynamic> booking) {
    final pickup = booking['pickupLocation'] ?? booking['pickup'] ?? {};
    final drop = booking['dropLocation'] ?? booking['drop'] ?? {};
    final pickupAddr = (pickup is Map ? pickup['address'] : '')?.toString() ?? '';
    final dropAddr = (drop is Map ? drop['address'] : '')?.toString() ?? '';
    final fare = (booking['finalFare'] ?? booking['fare'] ?? 0).toDouble();
    final user = booking['userId'];
    final userName =
        (user is Map ? (user['fullName'] ?? 'Customer') : 'Customer').toString();
    final bookingId = booking['_id']?.toString() ?? '';
    final shortId = bookingId.length > 8
        ? bookingId.substring(bookingId.length - 8).toUpperCase()
        : bookingId.toUpperCase();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BookingDetailScreen(bookingId: bookingId, booking: booking),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Name + ID + date
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Image.asset('assets/calendar.png',
                            width: 16, height: 16, color: _gray2),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(booking['createdAt']),
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
              // Pickup / Drop
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _border)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _addressRow(
                        'assets/booking_buzzer/pickup_marker.svg',
                        pickupAddr.isNotEmpty ? pickupAddr : 'Pickup',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _addressRow(
                        'assets/booking_buzzer/location_pin.svg',
                        dropAddr.isNotEmpty ? dropAddr : 'Drop',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Meta: trip type | distance | duration
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: _meta('assets/car_icon.png', _tripType(booking)),
                    ),
                    Expanded(
                      child: Center(
                        child: _meta('assets/routing.png', _distance(booking)),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _meta('assets/clock.png', _duration(booking)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: _border2),
              // Fare strip
              Container(
                width: double.infinity,
                color: _yellow,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/moneys.png',
                        width: 20, height: 20, color: _gray2),
                    const SizedBox(width: 8),
                    Text(
                      '₹${fare.toStringAsFixed(0)}',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 22 / 17,
                        color: _gray2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressRow(String iconAsset, String address) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Center(child: AssetIcon(iconAsset, width: 18, height: 18)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
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
    );
  }

  Widget _meta(String iconAsset, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(iconAsset, width: 20, height: 20, color: _gray2),
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
}
