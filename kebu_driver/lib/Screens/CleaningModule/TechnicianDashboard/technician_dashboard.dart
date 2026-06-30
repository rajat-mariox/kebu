import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/CleaningModule/BookingHistoryScreen/booking_history_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/NotificationScreen/notification_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/ProfileScreen/profile_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/OngoingServiceScreen/ongoing_service_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/ServiceDetailsScreen/service_details_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/customer_direction_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/incoming_service_bottom_sheet.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/start_customer_direction.dart';
import 'package:kebu_driver/Screens/DriverModule/WalletModule/my_wallet_screen.dart';
import 'package:kebu_driver/CommonWidgets/map_warmup.dart';
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
  Timer? _availablePoll;
  bool _sheetOpen = false;

  // Jobs already surfaced as a popup, so we don't re-open the sheet for them.
  final Set<String> _seenJobIds = {};

  bool _loading = true;
  bool _togglingStatus = false;

  // Backend-driven dashboard payload.
  Map<String, dynamic> _partner = {};
  List<Map<String, dynamic>> _stats = [];
  Map<String, dynamic> _revenueChart = {};
  List<Map<String, dynamic>> _bookingTabs = [];
  Map<String, dynamic> _reviews = {};
  int _selectedTab = 0;

  int _pollTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure the realtime socket is connected so a new booking pops up the
    // INSTANT it's created (this screen can be opened without going through the
    // ride home, which was the only place that connected the socket before).
    SocketService().connect();
    _loadDashboard();
    _loadAvailableJobs();
    // Fast-poll available jobs as a reliable fallback to the live socket (so a
    // request still appears within a few seconds even if the socket missed it),
    // and refresh the dashboard less often so finished jobs leave "On Going".
    _availablePoll = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadAvailableJobs();
      if (++_pollTick % 4 == 0) _loadDashboard(silent: true); // ~every 20s
    });

    _newBookingSub = SocketService().onNewServiceBooking.listen((data) {
      if (!mounted || _sheetOpen) return;
      final booking = (data['booking'] is Map)
          ? Map<String, dynamic>.from(data['booking'])
          : Map<String, dynamic>.from(data);
      if (booking.isEmpty) return;
      _showIncoming(booking);
    });

    // Pre-warm the native Google Maps SDK while the partner is on the dashboard
    // so the customer-direction map renders instantly when a booking is
    // accepted, instead of paying the first-map cold-start cost then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MapWarmup.ensure(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newBookingSub?.cancel();
    _availablePoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when the partner returns to the app so counts stay current.
    if (state == AppLifecycleState.resumed) {
      _loadDashboard(silent: true);
      _loadAvailableJobs();
    }
  }

  /// Open the incoming-booking sheet (used by both the live socket event and a
  /// tap on an available request), refreshing the dashboard afterwards.
  void _showIncoming(Map<String, dynamic> booking) {
    if (_sheetOpen) return;
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
      _loadDashboard(silent: true);
      _loadAvailableJobs();
    });
  }

  Future<void> _loadAvailableJobs() async {
    final res = await DriverApiService.getAvailableServiceBookings();
    if (!mounted || !res.success || res.data == null) return;
    final data = Map<String, dynamic>.from(res.data as Map);
    final jobs = (data['bookings'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    // Any job we haven't shown yet → open the incoming popup directly (so a
    // new request appears on its own, not as a list to tap into). The live
    // socket does the same; whichever fires first wins — _showIncoming guards
    // against opening a second sheet.
    final fresh = jobs
        .where((j) => !_seenJobIds.contains((j['_id'] ?? '').toString()))
        .toList();
    for (final j in jobs) {
      _seenJobIds.add((j['_id'] ?? '').toString());
    }
    if (fresh.isNotEmpty && !_sheetOpen) {
      _showIncoming(fresh.first);
    }
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
      bottomNavigationBar: _bottomNav(),
      body: Stack(
        children: [
          RefreshIndicator(
        onRefresh: () => _loadDashboard(silent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              _gradientHeader(),
              Container(
                margin: const EdgeInsets.only(top: 120),
                // Top padding clears the 40px rounded corners so the stat cards
                // sit fully on the white card (Figma: counters ~19px below the
                // card's top edge) instead of poking into the blue header above.
                padding: const EdgeInsets.only(left: 20, right: 20, top: 18),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(40),
                      topLeft: Radius.circular(40)),
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
          if (_activeServiceJob != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: _activeJobMiniTracker(_activeServiceJob!),
            ),
        ],
      ),
    );
  }

  // ── Gradient header ──
  // Figma fills the header with a smooth top→bottom gradient: a vivid royal
  // blue (#226DD2) that gradually darkens into indigo (#3B2FA8) by the bottom.
  // (The earlier [0, 0.19] stops snapped to solid indigo in the top 30px, which
  // read as a flat dark/purple header — not the gradual blue of the design.)
  Widget _gradientHeader() {
    return Container(
      height: 160,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [HexColor("#226DD2"), HexColor("#3B2FA8")],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                _profileButton(),
                const Spacer(),
                _onlinePill(),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileButton() {
    return InkWell(
      onTap: () => pushTo(context, const ProfileScreen()),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 48,
        width: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: HexColor("#E1E6EF")),
        ),
        child: ClipOval(child: _partnerAvatar()),
      ),
    );
  }

  Widget _partnerAvatar() {
    final img = (_partner['profileImage'] ?? '').toString();
    if (img.isNotEmpty) {
      return Image.network(
        img,
        height: 48,
        width: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset("assets/person_icon.png", height: 26, width: 26),
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
          color: isOnline ? HexColor("#3CAE5C") : HexColor("#E02D3C"),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
            ),
          ],
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
      ),
    );
  }

  // ── Bottom navigation bar (Home / Ticket / Wallet / Notification) ──
  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: HexColor("#F6F7F9"),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navIcon(Icons.home_filled, active: true, onTap: () {}),
              _navIcon(Icons.confirmation_number_outlined,
                  onTap: () => pushTo(context, const BookingHistoryScreen())),
              _navIcon(Icons.account_balance_wallet_outlined,
                  onTap: () => pushTo(context, const MyWalletScreen())),
              _navIcon(Icons.notifications_none_rounded,
                  onTap: () => pushTo(context, const NotificationScreen())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon,
      {bool active = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Icon(icon,
            size: 26,
            color: active ? HexColor("#2F4DBC") : HexColor("#6C757D")),
      ),
    );
  }

  Widget _body() {
    return Column(
      children: [
        // Stats Grid
        ..._statRows(),

        const SizedBox(height: 25),

        // Monthly Revenue Chart
        Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.center,
            child: Text(
              (_revenueChart['title'] ?? 'Monthly Revenue Rupee').toString(),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: HexColor("#1C1F34")),
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
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HexColor("#1C1F34")),
              ),
              Text(
                "View All",
                style: TextStyle(fontSize: 12, color: HexColor("#6C757D")),
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
          width: 10,
          borderRadius: BorderRadius.zero,
          color: HexColor("#2D52C0"),
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

  /// Re-open a booking the driver is handling and RESUME at the right step
  /// based on its status (so closing the app mid-service doesn't restart from
  /// the beginning).
  Future<void> _openBooking(Map<String, dynamic> b) async {
    final id = (b['id'] ?? b['_id'] ?? '').toString();
    if (id.isEmpty) return;
    final res = await DriverApiService.getServiceBookingDetail(id);
    if (!mounted) return;
    if (!res.success || res.data is! Map) {
      showCustomToast(
          context, res.message.isNotEmpty ? res.message : 'Could not open booking.');
      return;
    }
    final data = Map<String, dynamic>.from(res.data as Map);
    final status =
        ((data['booking'] is Map ? data['booking']['status'] : '') ?? '')
            .toString();

    final Widget screen;
    switch (status) {
      case 'PROVIDER_EN_ROUTE':
        screen = CustomerDirectionScreen(data: data);
        break;
      case 'PROVIDER_ARRIVED':
        screen = ServiceDetailsScreen(data: data);
        break;
      case 'IN_PROGRESS':
        screen = OngoingServiceScreen(data: data);
        break;
      default: // ACCEPTED / PROVIDER_ASSIGNED
        screen = StartCustomerDirection(data: data);
    }
    pushTo(context, screen);
  }

  /// The single ongoing job (if any), scanned from the dashboard tabs — drives
  /// the floating resume mini-tracker so closing the app mid-job never loses it.
  Map<String, dynamic>? get _activeServiceJob {
    for (final tab in _bookingTabs) {
      final bookings = (tab['bookings'] as List? ?? const []);
      for (final raw in bookings) {
        if (raw is! Map) continue;
        final b = Map<String, dynamic>.from(raw);
        if (_ongoingStatuses.contains((b['status'] ?? '').toString())) {
          return b;
        }
      }
    }
    return null;
  }

  String _jobStatusLabel(String s) {
    switch (s) {
      case 'PROVIDER_EN_ROUTE':
        return 'On the way to customer';
      case 'PROVIDER_ARRIVED':
        return 'Arrived at location';
      case 'IN_PROGRESS':
        return 'Service in progress';
      default:
        return 'Job accepted — start now';
    }
  }

  /// Floating white resume mini-tracker for the active job (same pattern as the
  /// customer app). Tap resumes at the right step via [_openBooking].
  Widget _activeJobMiniTracker(Map<String, dynamic> job) {
    final status = (job['status'] ?? '').toString();
    final service = (job['serviceType'] ?? 'Service').toString();
    final blue = HexColor('#2D52C0');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openBooking(job),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HexColor('#EEF1FB'),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cleaning_services_rounded,
                    color: blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _jobStatusLabel(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HexColor('#1C1F34'),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$service • Tap to resume',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: HexColor('#EEF1FB'),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Resume',
                    style: TextStyle(
                        color: blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  // Only an On Going job can be re-opened/handled; Pending & Completed cards
  // are read-only.
  static const _ongoingStatuses = {
    'ACCEPTED',
    'PROVIDER_ASSIGNED',
    'PROVIDER_EN_ROUTE',
    'PROVIDER_ARRIVED',
    'IN_PROGRESS',
  };

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final discountLabel = (b['discountLabel'] ?? '').toString();
    final canOpen = _ongoingStatuses.contains((b['status'] ?? '').toString());
    return InkWell(
      onTap: canOpen ? () => _openBooking(b) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HexColor("#EBEBEB")),
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
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: HexColor("#1C1F34")),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HexColor("#2D52C0"),
                  borderRadius: BorderRadius.circular(43),
                ),
                child: Text((b['bookingNumber'] ?? '').toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                (b['priceLabel'] ?? '').toString(),
                style: TextStyle(
                    fontSize: 22,
                    color: HexColor("#2D52C0"),
                    fontWeight: FontWeight.bold),
              ),
              if (discountLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  discountLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: HexColor("#3CAE5C"),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          if ((b['address'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 15),
            _infoRow("assets/location.png", (b['address']).toString()),
          ],
          if ((b['dateLabel'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 15),
            _infoRow("assets/calendar_2.png", (b['dateLabel']).toString()),
          ],
          if ((b['customerName'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 15),
            _infoRow("assets/person_icon.png", (b['customerName']).toString()),
          ],
        ],
      ),
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
            margin: const EdgeInsets.only(top: 2),
            child: ClipOval(
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                          "assets/review_image.png",
                          width: 50,
                          height: 50),
                    )
                  : Image.asset("assets/review_image.png",
                      width: 50, height: 50),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text((r['name'] ?? '').toString(),
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: HexColor("#1C1F34"))),
                    ),
                    Text((r['date'] ?? '').toString(),
                        style:
                            TextStyle(color: HexColor("#6C757D"), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ..._ratingStars(rating),
                    const SizedBox(width: 6),
                    Text(rating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 14, color: HexColor("#6C757D"))),
                  ],
                ),
                if ((r['feedback'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    (r['feedback']).toString(),
                    style: TextStyle(
                        fontSize: 14, color: HexColor("#6C757D"), height: 1.43),
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

  // Stats as 2 rows of 2 fixed-height cards — avoids the GridView aspect-ratio
  // overflow and lets long labels (e.g. "Upcoming Services") wrap to two lines.
  List<Widget> _statRows() {
    final rows = <Widget>[];
    for (var i = 0; i < _stats.length; i += 2) {
      final a = _stats[i];
      final hasB = i + 1 < _stats.length;
      // IntrinsicHeight + stretch keeps both cards in a row the same height
      // (matching the taller, two-line one) while letting the cards size to
      // their content — so a wrapping label can never overflow a fixed box.
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildStatCard((a['value'] ?? '').toString(),
                  (a['label'] ?? '').toString(), _statIcon(i)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: hasB
                  ? _buildStatCard((_stats[i + 1]['value'] ?? '').toString(),
                      (_stats[i + 1]['label'] ?? '').toString(), _statIcon(i + 1))
                  : const SizedBox(),
            ),
          ],
        ),
      ));
      if (i + 2 < _stats.length) rows.add(const SizedBox(height: 20));
    }
    return rows;
  }

  static Widget _buildStatCard(String value, String label, String icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: HexColor("#EBEBEB")),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: HexColor("#2F4DBC"))),
                const SizedBox(height: 10),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: HexColor("#6C757D"),
                        height: 1.2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 35,
            width: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HexColor("#F0F0FA"),
            ),
            child: Image.asset(icon, height: 18, width: 18),
          ),
        ],
      ),
    );
  }

  static Widget _buildTabButton(String label, bool isActive) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isActive ? HexColor("#2E50BF") : HexColor("#F6F7F9"),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
              color: isActive ? Colors.white : HexColor("#1C1F34"),
              fontWeight: FontWeight.w500,
              fontSize: 14),
        ),
      ),
    );
  }

  static Widget _infoRow(String icon, String text) {
    return Row(
      children: [
        Image.asset(icon, height: 14, width: 14, color: HexColor("#6C757D")),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: HexColor("#6C757D")),
          ),
        ),
      ],
    );
  }
}
