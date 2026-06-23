import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/BookingDetail/booking_detail_screen.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';
import 'package:kebu_customer/Services/delivery_api_service.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Map<String, dynamic>> services = [];
  bool isLoading = true;

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

    final List<Map<String, dynamic>> allOrders = [];

    // Ride bookings
    if (results[0].success && results[0].data != null) {
      final bookings = results[0].data['bookings'] ?? [];
      for (var b in bookings) {
        final raw = Map<String, dynamic>.from(b as Map);
        allOrders.add({
          'kind': 'ride',
          'id': raw['_id']?.toString() ?? '',
          'raw': raw,
          'status': (raw['status'] ?? 'Active').toString(),
          'title': _vehicleName(raw),
          'date': raw['createdAt'],
          'address': raw['pickup']?['address'] ?? '',
        });
      }
    }

    // Deliveries
    if (results[1].success && results[1].data != null) {
      final deliveries = results[1].data['deliveries'] ?? [];
      for (var d in deliveries) {
        final raw = Map<String, dynamic>.from(d as Map);
        allOrders.add({
          'kind': 'delivery',
          'id': raw['_id']?.toString() ?? '',
          'raw': raw,
          'status': (raw['status'] ?? 'Active').toString(),
          'title': 'Send Parcel',
          'date': raw['createdAt'],
          'address': raw['pickup']?['address'] ?? '',
        });
      }
    }

    // Household bookings
    if (results[2].success && results[2].data != null) {
      final bookings = results[2].data['bookings'] ?? [];
      for (var h in bookings) {
        final raw = Map<String, dynamic>.from(h as Map);
        final category = raw['categoryId'];
        final categoryName =
            category is Map ? category['name']?.toString() : null;
        allOrders.add({
          'kind': 'household',
          'id': raw['_id']?.toString() ?? '',
          'raw': raw,
          'status': (raw['status'] ?? 'Active').toString(),
          'title': categoryName ??
              raw['serviceType']?.toString() ??
              'Household Service',
          'date': raw['createdAt'],
          'address': raw['address']?['address'] ?? raw['address']?['addressText'] ?? '',
        });
      }
    }

    // Newest first across all kinds
    allOrders.sort((a, b) {
      final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
      final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });

    if (mounted) {
      setState(() {
        services = allOrders;
        isLoading = false;
      });
    }
  }

  String _vehicleName(Map<String, dynamic> raw) {
    final vt = raw['vehicleTypeId'] ?? raw['vehicleType'];
    if (vt is Map && (vt['name']?.toString().isNotEmpty ?? false)) {
      return '${vt['name']} Ride';
    }
    return 'Ride Booking';
  }

  /// Maps backend status -> Figma label + colour.
  /// Done = #1B1D21, Cancelled = #FF2F28, Active = #4FBF67
  Map<String, dynamic> _statusBadge(String status) {
    final s = status.toUpperCase();
    if (s == 'COMPLETED' || s == 'DONE' || s == 'DELIVERED') {
      return {'label': 'Done', 'color': HexColor('#1B1D21')};
    }
    if (s == 'CANCELLED' || s == 'CANCELED' || s == 'REJECTED' || s == 'FAILED') {
      return {'label': 'Cancelled', 'color': HexColor('#FF2F28')};
    }
    return {'label': 'Active', 'color': HexColor('#4FBF67')};
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('EEEE, MMMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient header
          commonAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 12, right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Order History",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const NotificationIconButton(height: 33),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 120),

              // White rounded sheet header: "This Month" + filter + grid
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
                child: Row(
                  children: [
                    Text(
                      'This Month',
                      style: GoogleFonts.dmSans(
                        color: HexColor('#1B1D21'),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const Spacer(),
                    Image.asset("assets/filter.png", height: 24),
                    Container(
                      height: 18,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: HexColor('#E0E0E0'),
                    ),
                    Image.asset("assets/grid_icon.png", height: 24),
                  ],
                ),
              ),

              // List
              Expanded(
                child: Container(
                  color: HexColor("#C4C4C4").withOpacity(0.06),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : services.isEmpty
                          ? _emptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(19, 16, 19, 24),
                              itemCount: services.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 20),
                              itemBuilder: (context, index) {
                                final s = services[index];
                                final badge =
                                    _statusBadge(s['status'] as String);
                                final card = ServiceCard(
                                  status: badge['label'] as String,
                                  color: badge['color'] as Color,
                                  title: s['title'] as String,
                                  date: _formatDate(s['date']),
                                  address: s['address'] as String,
                                );

                                final isRide = s['kind'] == 'ride';
                                final bookingId = (s['id'] ?? '').toString();

                                if (isRide && bookingId.isNotEmpty) {
                                  return Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(28),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(28),
                                      onTap: () => pushTo(
                                        context,
                                        BookingDetailScreen(
                                          bookingId: bookingId,
                                          initialBooking:
                                              s['raw'] as Map<String, dynamic>?,
                                        ),
                                      ),
                                      child: card,
                                    ),
                                  );
                                }
                                return card;
                              },
                            ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            "No orders yet",
            style: GoogleFonts.dmSans(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Your bookings will appear here",
            style: GoogleFonts.dmSans(
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final String status;
  final Color color;
  final String title;
  final String date;
  final String address;

  const ServiceCard({
    super.key,
    required this.status,
    required this.color,
    required this.title,
    required this.date,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map area with status badge + centered pin
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.asset(
                  'assets/empty_map.png',
                  fit: BoxFit.cover,
                  height: 132,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    height: 132,
                    width: double.infinity,
                    color: const Color(0xFFF1F1F1),
                  ),
                ),
                // Center location pin marker
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.location_on,
                              color: HexColor('#FFB800'), size: 22),
                        ),
                      ],
                    ),
                  ),
                ),
                // Status badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x33949494),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.4,
                color: HexColor('#1B1D21'),
              ),
            ),
          ),
          // Date
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              date,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                letterSpacing: -0.3,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(
              height: 22,
              thickness: 1,
              color: HexColor('#ECECEC'),
            ),
          ),

          // Address row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Image.asset('assets/star_with_location.png', width: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    address.isEmpty ? '—' : address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      letterSpacing: -0.3,
                      color: HexColor('#1B1D21'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
