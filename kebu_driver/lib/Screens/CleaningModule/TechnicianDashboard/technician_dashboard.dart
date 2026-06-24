import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/Screens/CleaningModule/ProfileScreen/profile_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/incoming_service_bottom_sheet.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

/// Cleaning / household partner home dashboard.
///
/// Fully backend-driven: the stat cards, the monthly revenue chart, the
/// On Going / Pending / Completed booking tabs and the reviews are all fetched
/// from `/driver/app/household/dashboard` and rendered dynamically. Matches the
/// Figma "Cleaning" dashboard design.
class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _newBookingSub;
  bool _sheetOpen = false;

  bool _loading = true;
  bool _togglingStatus = false;

  // Backend-driven dashboard payload.
  Map<String, dynamic> _partner = {};
  List<Map<String, dynamic>> _stats = [];
  Map<String, dynamic> _revenueChart = {};
  List<Map<String, dynamic>> _bookingTabs = [];
  Map<String, dynamic> _reviews = {};
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();

    _newBookingSub = SocketService().onNewServiceBooking.listen((data) {
      if (!mounted || _sheetOpen) return;
      final booking = (data['booking'] is Map)
          ? Map<String, dynamic>.from(data['booking'])
          : Map<String, dynamic>.from(data);
      if (booking.isEmpty) return;

      _sheetOpen = true;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (_) => IncomingServiceBottomSheet(booking: booking),
      ).whenComplete(() {
        _sheetOpen = false;
        // A new booking may have changed the dashboard counts/tabs.
        _loadDashboard(silent: true);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newBookingSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when the partner returns to the app so counts stay current.
    if (state == AppLifecycleState.resumed) _loadDashboard(silent: true);
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final res = await DriverApiService.getHouseholdDashboard();
    if (!mounted) return;

    if (!res.success || res.data == null) {
      setState(() => _loading = false);
      if (!silent) {
        showCustomToast(
            context, res.message.isNotEmpty ? res.message : 'Failed to load dashboard.');
      }
      return;
    }

    final data = Map<String, dynamic>.from(res.data as Map);
    setState(() {
      _partner = (data['partner'] is Map)
          ? Map<String, dynamic>.from(data['partner'])
          : {};
      _stats = (data['stats'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _revenueChart = (data['revenueChart'] is Map)
          ? Map<String, dynamic>.from(data['revenueChart'])
          : {};
      _bookingTabs = (data['bookingTabs'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _reviews = (data['reviews'] is Map)
          ? Map<String, dynamic>.from(data['reviews'])
          : {};
      if (_selectedTab >= _bookingTabs.length) _selectedTab = 0;
      _loading = false;
    });
  }

  Future<void> _toggleOnline() async {
    if (_togglingStatus) return;
    setState(() => _togglingStatus = true);
    final res = await DriverApiService.toggleStatus();
    if (!mounted) return;
    setState(() => _togglingStatus = false);

    if (res.success) {
      final isOnline = (res.data is Map) ? res.data['isOnline'] == true : null;
      setState(() {
        _partner['isOnline'] = isOnline ?? !(_partner['isOnline'] == true);
      });
    } else {
      showCustomToast(
          context, res.message.isNotEmpty ? res.message : 'Failed to update status.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => _loadDashboard(silent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              cleaningAppBar(
                height: 160,
                context: context,
                child: Container(
                  padding: const EdgeInsets.only(left: 12, right: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => pushTo(context, const ProfileScreen()),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: _partnerAvatar(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      _onlinePill(),
                      const Spacer(),
                      Container(width: 55),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 120),
                padding: const EdgeInsets.only(left: 20, right: 20),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(32),
                      topLeft: Radius.circular(32)),
                  color: Colors.white,
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 120),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partnerAvatar() {
    final img = (_partner['profileImage'] ?? '').toString();
    if (img.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          img,
          height: 44,
          width: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Image.asset("assets/person_icon.png", height: 26, width: 26),
        ),
      );
    }
    return Image.asset("assets/person_icon.png", height: 26, width: 26);
  }

  Widget _onlinePill() {
    final isOnline = _partner['isOnline'] == true;
    return InkWell(
      onTap: _toggleOnline,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isOnline ? HexColor("#3CAE5C") : Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _togglingStatus
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                isOnline ? "Online" : "Offline",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _body() {
    return Column(
      children: [
        // Stats Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(_stats.length, (i) {
            final s = _stats[i];
            return _buildStatCard(
              (s['value'] ?? '').toString(),
              (s['label'] ?? '').toString(),
              _statIcon(i),
            );
          }),
        ),

        const SizedBox(height: 25),

        // Monthly Revenue Chart
        Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.center,
            child: Text(
              (_revenueChart['title'] ?? 'Monthly Revenue Rupee').toString(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(height: 220, child: _revenueBarChart()),

        const SizedBox(height: 30),

        // Tabs
        Row(
          children: List.generate(_bookingTabs.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == _bookingTabs.length - 1 ? 0 : 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = i),
                  child: _buildTabButton(
                    (_bookingTabs[i]['label'] ?? '').toString(),
                    i == _selectedTab,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        // Bookings for the selected tab
        _bookingsForSelectedTab(),

        const SizedBox(height: 20),

        // Reviews Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (_reviews['title'] ?? 'Reviews').toString(),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Text(
                "View All",
                style: TextStyle(fontSize: 13, color: Colors.blue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        _reviewsList(),
        const SizedBox(height: 30),
      ],
    );
  }

  // ── Chart ──
  Widget _revenueBarChart() {
    final points = (_revenueChart['points'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (points.isEmpty) {
      return const Center(
        child: Text("No revenue data yet",
            style: TextStyle(color: Colors.grey)),
      );
    }

    final values = points
        .map((p) => (p['value'] is num) ? (p['value'] as num).toDouble() : 0.0)
        .toList();
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    // Round the axis up to a tidy maximum; default to 15000 when empty.
    final maxY = maxValue <= 0 ? 15000.0 : (((maxValue / 5000).ceil()) * 5000).toDouble();
    final interval = maxY / 3;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 55,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < points.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (points[idx]['label'] ?? '').toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        barGroups: List.generate(points.length, (i) => _barGroup(i, values[i])),
        alignment: BarChartAlignment.spaceAround,
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius: BorderRadius.circular(4),
          color: const Color(0xFF2F5AE3),
        ),
      ],
    );
  }

  // ── Bookings ──
  Widget _bookingsForSelectedTab() {
    if (_bookingTabs.isEmpty) return const SizedBox.shrink();
    final bookings = (_bookingTabs[_selectedTab]['bookings'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (bookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: Text(
          "No ${(_bookingTabs[_selectedTab]['label'] ?? '').toString().toLowerCase()} services",
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return Column(
      children: bookings.map(_buildBookingCard).toList(),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final discountLabel = (b['discountLabel'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  (b['serviceType'] ?? '').toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: HexColor("#2D52C0"),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text((b['bookingNumber'] ?? '').toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                (b['priceLabel'] ?? '').toString(),
                style: TextStyle(
                    fontSize: 18,
                    color: HexColor("#2D52C0"),
                    fontWeight: FontWeight.bold),
              ),
              if (discountLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  discountLabel,
                  style: TextStyle(
                      fontSize: 13,
                      color: HexColor("#3CAE5C"),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          if ((b['address'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoRow("assets/location.png", (b['address']).toString()),
          ],
          if ((b['dateLabel'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow("assets/calendar_2.png", (b['dateLabel']).toString()),
          ],
          if ((b['customerName'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow("assets/person_icon.png", (b['customerName']).toString()),
          ],
        ],
      ),
    );
  }

  // ── Reviews ──
  Widget _reviewsList() {
    final items = (_reviews['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: const Text("No reviews yet",
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }

    return Column(children: items.map(_buildReview).toList());
  }

  Widget _buildReview(Map<String, dynamic> r) {
    final image = (r['image'] ?? '').toString();
    final rating = (r['rating'] is num) ? (r['rating'] as num).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            child: ClipOval(
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                          "assets/review_image.png",
                          width: 42,
                          height: 42),
                    )
                  : Image.asset("assets/review_image.png",
                      width: 42, height: 42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text((r['name'] ?? '').toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    Text((r['date'] ?? '').toString(),
                        style:
                            TextStyle(color: HexColor("#6C757D"), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ..._ratingStars(rating),
                    const SizedBox(width: 6),
                    Text(rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54)),
                  ],
                ),
                if ((r['feedback'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    (r['feedback']).toString(),
                    style: const TextStyle(
                        fontSize: 13.5, color: Colors.black54, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ratingStars(double rating) {
    final stars = <Widget>[];
    for (var i = 1; i <= 5; i++) {
      IconData icon;
      if (rating >= i) {
        icon = Icons.star;
      } else if (rating >= i - 0.5) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(Icon(icon, color: HexColor("#FFBD00"), size: 16));
    }
    return stars;
  }

  // ── Static styling helpers (unchanged from the original design) ──
  String _statIcon(int index) {
    const icons = [
      "assets/discount_icon.png",
      "assets/documents_icon.png",
      "assets/documents_icon.png",
      "assets/documents_icon.png",
    ];
    return icons[index % icons.length];
  }

  static Widget _buildStatCard(String value, String label, String icon) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HexColor("#EBEBEB")),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: HexColor("#2F4DBC"))),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(width: 0)),
          Container(
            height: 36,
            width: 36,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: HexColor("#2F4DBC").withOpacity(0.06),
            ),
            child: Image.asset(icon, height: 24, width: 24),
          ),
        ],
      ),
    );
  }

  static Widget _buildTabButton(String label, bool isActive) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isActive ? HexColor("#2E50BF") : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
              color: isActive ? Colors.white : Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 13),
        ),
      ),
    );
  }

  static Widget _infoRow(String icon, String text) {
    return Row(
      children: [
        Image.asset(icon, height: 20, width: 20, color: Colors.black),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: HexColor("#6C757D")),
          ),
        ),
      ],
    );
  }
}
