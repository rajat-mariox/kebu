import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/BookARideModule/BookingDetail/booking_detail_screen.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';
import 'package:kebu_customer/Services/delivery_api_service.dart';
import 'package:kebu_customer/Services/household_api_service.dart';

/// Design tokens from Figma (kebu-one / History — node 131:11212)
class _C {
  static final bg = HexColor('#F0F5FA');
  static final yellow = HexColor('#FFD546');
  static final border = HexColor('#E1E6EF');
  static final divider = HexColor('#E9F0F7');
  static final ink = HexColor('#132235'); // Gray/Shade 1
  static final ink2 = HexColor('#364B63'); // Gray/Shade 2
  static final ink3 = HexColor('#607080'); // Gray/Shade 3
  static final lightFooter = HexColor('#F0F5FF');
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<_HistoryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderHistory();
  }

  Future<void> _loadOrderHistory() async {
    final results = await Future.wait([
      BookingApiService.getBookingHistory(),
      DeliveryApiService.getDeliveryHistory(),
      HouseholdApiService.getUserBookings(),
    ]);

    final List<_HistoryItem> all = [];

    // ---- Ride bookings ----
    if (results[0].success && results[0].data != null) {
      for (final b in (results[0].data['bookings'] ?? [])) {
        final raw = Map<String, dynamic>.from(b as Map);
        all.add(_HistoryItem(
          kind: 'ride',
          id: raw['_id']?.toString() ?? '',
          raw: raw,
          status: (raw['status'] ?? '').toString(),
          name: _driverName(raw) ?? _vehicleName(raw),
          createdAt: _date(raw['createdAt']),
          pickup: _addr(raw['pickup']),
          drop: _addr(raw['drop']),
          tripType: _tripType(raw),
          distance: _distance(raw['distanceKm'] ?? raw['distance']),
          duration: _duration(raw['durationMin'] ?? raw['duration']),
          fare: _money(raw['finalFare'] ?? raw['fare']),
          paid: _isPaid(raw['paymentStatus']),
        ));
      }
    }

    // ---- Deliveries ----
    if (results[1].success && results[1].data != null) {
      for (final d in (results[1].data['deliveries'] ?? [])) {
        final raw = Map<String, dynamic>.from(d as Map);
        all.add(_HistoryItem(
          kind: 'delivery',
          id: raw['_id']?.toString() ?? '',
          raw: raw,
          status: (raw['status'] ?? '').toString(),
          name: _driverName(raw) ?? 'Send Parcel',
          createdAt: _date(raw['createdAt']),
          pickup: _addr(raw['pickup']),
          drop: _addr(_firstDrop(raw)),
          tripType: 'Delivery',
          distance: _distance(raw['distanceKm'] ?? raw['distance']),
          duration: _duration(raw['durationMin'] ?? raw['duration']),
          fare: _money(raw['finalFare'] ?? raw['totalPrice'] ?? raw['amount']),
          paid: _isPaid(raw['paymentStatus']),
        ));
      }
    }

    // ---- Household bookings ----
    if (results[2].success && results[2].data != null) {
      for (final h in (results[2].data['bookings'] ?? [])) {
        final raw = Map<String, dynamic>.from(h as Map);
        final category = raw['categoryId'];
        final categoryName = category is Map ? category['name']?.toString() : null;
        all.add(_HistoryItem(
          kind: 'household',
          id: raw['_id']?.toString() ?? '',
          raw: raw,
          status: (raw['status'] ?? '').toString(),
          name: categoryName ??
              raw['serviceType']?.toString() ??
              'Household Service',
          createdAt: _date(raw['createdAt']),
          pickup: _addr(raw['address']),
          drop: null,
          tripType: 'Service',
          distance: null,
          duration: _duration(raw['durationMin']),
          fare: _money(raw['finalFare'] ?? raw['amount'] ?? raw['totalPrice']),
          paid: _isPaid(raw['paymentStatus']),
        ));
      }
    }

    // Newest first across all kinds.
    all.sort((a, b) =>
        (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));

    if (mounted) {
      setState(() {
        _items = all;
        _isLoading = false;
      });
    }
  }

  // ---------------- field extractors ----------------

  String? _driverName(Map<String, dynamic> raw) {
    final driver = raw['driverId'];
    if (driver is Map) {
      final n = driver['fullName']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return null;
  }

  String _vehicleName(Map<String, dynamic> raw) {
    final vt = raw['vehicleTypeId'] ?? raw['vehicleType'];
    if (vt is Map && (vt['name']?.toString().isNotEmpty ?? false)) {
      return '${vt['name']} Ride';
    }
    return 'Ride Booking';
  }

  String _tripType(Map<String, dynamic> raw) {
    final t = raw['tripType']?.toString().trim();
    if (t == null || t.isEmpty) return 'One Way';
    switch (t.toUpperCase()) {
      case 'ROUND_TRIP':
      case 'ROUNDTRIP':
        return 'Round Trip';
      case 'ONE_WAY':
      case 'ONEWAY':
        return 'One Way';
      default:
        return t;
    }
  }

  String _addr(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is Map) {
      return (v['address'] ?? v['addressText'] ?? v['name'] ?? '').toString();
    }
    return '';
  }

  dynamic _firstDrop(Map<String, dynamic> raw) {
    final drops = raw['drops'];
    if (drops is List && drops.isNotEmpty) return drops.first;
    return raw['drop'];
  }

  DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? _distance(dynamic v) {
    final km = _num(v);
    if (km == null || km <= 0) return null;
    final s = km == km.roundToDouble()
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(2);
    return '${s}km';
  }

  String? _duration(dynamic v) {
    final mins = _num(v)?.round();
    if (mins == null || mins <= 0) return null;
    if (mins < 60) return '${mins}min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  String _money(dynamic v) {
    final amount = _num(v) ?? 0;
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
    );
    return fmt.format(amount);
  }

  bool _isPaid(dynamic status) {
    return status?.toString().toUpperCase() == 'PAID';
  }

  /// Section header: TODAY / YESTERDAY / "26 FEB 2024".
  String _sectionLabel(DateTime? dt) {
    if (dt == null) return 'EARLIER';
    final now = DateTime.now();
    final day = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('dd MMM yyyy').format(dt).toUpperCase();
  }

  /// Groups items into consecutive date sections (input already sorted desc).
  List<_Section> _grouped() {
    final sections = <_Section>[];
    for (final item in _items) {
      final label = _sectionLabel(item.createdAt);
      if (sections.isEmpty || sections.last.label != label) {
        sections.add(_Section(label, [item]));
      } else {
        sections.last.items.add(item);
      }
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _emptyState()
                      : _list(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- header ----------------

  Widget _header(BuildContext context) {
    return Container(
      color: _C.yellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Icon(Icons.arrow_back, size: 26, color: _C.ink),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  'History',
                  style: GoogleFonts.nunito(
                    color: _C.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 25 / 20,
                  ),
                ),
              ),
              SvgPicture.asset('assets/history/filter.svg', width: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- list ----------------

  Widget _list() {
    final sections = _grouped();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final section = sections[i];
        return Column(
          children: [
            if (i != 0) const SizedBox(height: 16),
            _sectionDivider(section.label),
            for (final item in section.items) ...[
              const SizedBox(height: 16),
              _HistoryCard(
                item: item,
                onTap: item.kind == 'ride' && item.id.isNotEmpty
                    ? () => pushTo(
                          context,
                          BookingDetailScreen(
                            bookingId: item.id,
                            initialBooking: item.raw,
                          ),
                        )
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionDivider(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _C.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              color: _C.ink3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 13 / 11,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: _C.border)),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 56, color: _C.border),
          const SizedBox(height: 12),
          Text(
            'No history yet',
            style: GoogleFonts.nunito(
              color: _C.ink2,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your bookings will appear here',
            style: GoogleFonts.nunito(color: _C.ink3, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ===================== models =====================

class _HistoryItem {
  final String kind;
  final String id;
  final Map<String, dynamic> raw;
  final String status;
  final String name;
  final DateTime? createdAt;
  final String pickup;
  final String? drop;
  final String tripType;
  final String? distance;
  final String? duration;
  final String fare;
  final bool paid;

  _HistoryItem({
    required this.kind,
    required this.id,
    required this.raw,
    required this.status,
    required this.name,
    required this.createdAt,
    required this.pickup,
    required this.drop,
    required this.tripType,
    required this.distance,
    required this.duration,
    required this.fare,
    required this.paid,
  });

  /// Short id shown as `#0CAC6C64`.
  String get shortId {
    final v = id.length <= 8 ? id : id.substring(id.length - 8);
    return '#${v.toUpperCase()}';
  }
}

class _Section {
  final String label;
  final List<_HistoryItem> items;
  _Section(this.label, this.items);
}

// ===================== card =====================

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final VoidCallback? onTap;

  const _HistoryCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header: name + id  /  calendar + date
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
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              color: _C.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 20 / 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${item.shortId}',
                            style: GoogleFonts.nunito(
                              color: _C.ink2,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 16 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset('assets/history/calendar.svg',
                            width: 18, height: 18),
                        const SizedBox(width: 6),
                        Text(
                          item.createdAt == null
                              ? '--'
                              : DateFormat('dd/MM/yyyy')
                                  .format(item.createdAt!),
                          style: GoogleFonts.nunito(
                            color: _C.ink2,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 18 / 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Address rows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _addressRow('assets/history/pickup.svg', item.pickup,
                        bottomBorder: item.drop != null),
                    if (item.drop != null)
                      _addressRow('assets/history/drop.svg', item.drop!,
                          bottomBorder: false),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 102,
                      child: _stat('assets/history/car_taxi.svg', item.tripType),
                    ),
                    if (item.distance != null)
                      Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: _stat(
                              'assets/history/routing.svg', item.distance!),
                        ),
                      )
                    else
                      const Spacer(),
                    if (item.duration != null)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child:
                              _stat('assets/history/clock.svg', item.duration!),
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Divider
              Container(height: 1, color: _C.divider),
              // Fare footer
              _fareFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressRow(String icon, String text, {required bool bottomBorder}) {
    return Container(
      decoration: BoxDecoration(
        border: bottomBorder
            ? Border(bottom: BorderSide(color: _C.border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: SvgPicture.asset(icon, width: 18, height: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                color: _C.ink,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 20 / 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(icon, width: 20, height: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              color: _C.ink2,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 18 / 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fareFooter() {
    final lightVariant = item.paid;
    return Container(
      width: double.infinity,
      color: lightVariant ? _C.lightFooter : _C.yellow,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            lightVariant
                ? 'assets/history/moneys_yellow.svg'
                : 'assets/history/moneys_dark.svg',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 8),
          Text(
            item.fare,
            style: GoogleFonts.nunito(
              color: lightVariant ? _C.yellow : _C.ink2,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 22 / 17,
            ),
          ),
        ],
      ),
    );
  }
}
