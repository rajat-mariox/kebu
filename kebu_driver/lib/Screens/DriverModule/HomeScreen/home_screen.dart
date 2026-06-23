import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';
import 'package:kebu_driver/Screens/DriverModule/HistoryScreen/history_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/HomeScreen/Widgets/profile_dialog.dart';
import 'package:kebu_driver/Screens/DriverModule/HomeScreen/Widgets/wish_to_work_dialog.dart';
import 'package:kebu_driver/Screens/DriverModule/MyProfileScreen/my_profile_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/TakeBookingsScreen/take_bookings_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/RideRequestScreen/ride_request_screen.dart';
import 'package:kebu_driver/Screens/DriverModule/ActiveRideScreen/active_ride_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';

/// Figma design tokens for the dashboard. Kept local so the layout has them
/// at hand without polluting the global AppColors.
class _Tokens {
  static final yellow = HexColor('#FFD546');
  static final yellowAlt = HexColor('#FFCC00');
  static final dark = HexColor('#13203C');
  static final gray1 = HexColor('#132235');
  static final gray2 = HexColor('#364B63');
  static final gray5 = HexColor('#D3DDE7');
  static final border = HexColor('#E1E6EF');
  static final background = HexColor('#F0F5FA');
  static final primaryBg = HexColor('#F0F9FF');
  static final lightAlt = HexColor('#F0F5FF');
  static final red = HexColor('#E02D3C');
  static final green = HexColor('#17C97C');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DriverBookingController _bc = Get.find<DriverBookingController>();
  StreamSubscription? _rideRequestSub;

  // Dashboard data
  String _driverName = '';
  String _driverId = '';
  String _profileImage = '';
  double _rating = 0;
  int _todayRides = 0;
  double _todayEarnings = 0;
  String _preferredWorkHours = '';

  // Bookings
  List<Map<String, dynamic>> _recentBookings = [];

  // Local notifications plugin (used to fire ride-request alert sound)
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _fetchDashboardAndCheckWorkHours();
    _fetchBookings();

    SocketService().connect();
    _rideRequestSub = SocketService().onNewRideRequest.listen((_) {
      if (!mounted) return;
      _playRideAlert();
      if (_bc.rideState.value == DriverRideState.newRequest) {
        pushTo(context, const RideRequestScreen());
      }
    });
    _checkActiveBooking();
  }

  @override
  void dispose() {
    _rideRequestSub?.cancel();
    super.dispose();
  }

  // ─────────────── data fetches ───────────────

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _playRideAlert() async {
    HapticFeedback.heavyImpact();
    const androidDetails = AndroidNotificationDetails(
      'ride_request',
      'Ride Requests',
      channelDescription: 'New ride request alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'New Ride Request!',
      'A customer is looking for a ride nearby',
      details,
    );
  }

  Future<void> _fetchDashboardAndCheckWorkHours() async {
    final res = await DriverApiService.getDashboard();
    if (!res.success || res.data == null || !mounted) return;
    _applyDashboard(res.data);

    final workHours = _preferredWorkHours;
    if (workHours.isEmpty && mounted) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        builder: (_) => const WishToWorkDialog(),
      );
    }
  }

  Future<void> _fetchDashboard() async {
    final res = await DriverApiService.getDashboard();
    if (!res.success || res.data == null || !mounted) return;
    _applyDashboard(res.data);
  }

  void _applyDashboard(dynamic data) {
    final driver = data['driver'] ?? {};
    final today = data['today'] ?? {};
    setState(() {
      _driverName = (driver['fullName'] ?? '').toString();
      _driverId = (driver['_id'] ?? '').toString();
      _profileImage = (driver['profileImage'] ?? '').toString();
      _rating = (driver['rating'] ?? 0).toDouble();
      _todayRides = (today['totalRides'] ?? 0) as int;
      _todayEarnings = (today['totalEarnings'] ?? 0).toDouble();
      _preferredWorkHours = (driver['preferredWorkHours'] ?? '').toString();
    });

    final serverOnline = driver['isOnline'] == true;
    if (serverOnline != _bc.isOnline.value) {
      _bc.isOnline.value = serverOnline;
    }
    // Keep the socket's online presence aligned with the authoritative server
    // status. Connecting the socket no longer force-onlines the driver, so we
    // explicitly tell it whether the driver should be advertised as available.
    SocketService().syncOnlineState(serverOnline);
  }

  Future<void> _fetchBookings() async {
    final res = await DriverApiService.getBookingHistory(page: 0, limit: 10);
    if (!res.success || res.data == null || !mounted) return;
    final list = res.data['bookings'] as List<dynamic>? ?? [];
    setState(() {
      _recentBookings =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  /// On launch (incl. reopening after the app was accidentally killed),
  /// restore any active booking into the controller so it surfaces in the
  /// "On Going Bookings" section. We intentionally do NOT auto-navigate into
  /// the ride — the driver taps the ongoing card to resume it.
  Future<void> _checkActiveBooking() async {
    await _bc.checkActiveBooking();
    if (mounted) setState(() {});
  }

  /// Resume an active ride from the "On Going Bookings" list. Re-syncs the
  /// controller from the backend (covers the post-restart case) and opens the
  /// active-ride screen at whatever phase the ride is in.
  Future<void> _resumeOngoingBooking(Map<String, dynamic> _) async {
    final hasActive = await _bc.checkActiveBooking();
    if (!mounted) return;
    if (hasActive) {
      pushTo(context, const ActiveRideScreen());
    } else {
      _fetchBookings();
    }
  }

  // ─────────────── helpers ───────────────

  String _shortDriverIdLong() {
    if (_driverId.isEmpty) return '#----------';
    final tail = _driverId.length > 10
        ? _driverId.substring(_driverId.length - 10)
        : _driverId;
    return '#$tail';
  }

  String _formatBookingDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString()).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      var hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day} ${months[dt.month - 1]}, '
          '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '';
    }
  }

  /// Friendly "Starts in: 1 Hr 12 mins" string. Returns empty when the
  /// booking has no scheduledFor / pickupTime in the future.
  String _formatStartsIn(Map<String, dynamic> booking) {
    final raw = booking['scheduledFor'] ?? booking['scheduledTime'] ?? booking['pickupTime'];
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return 'Now';
      final totalMin = diff.inMinutes;
      if (totalMin < 60) return '$totalMin mins';
      final hr = diff.inHours;
      final min = totalMin - hr * 60;
      return '$hr Hr $min mins';
    } catch (_) {
      return '';
    }
  }

  String _bookingTypeLabel(Map<String, dynamic> booking) {
    final t = (booking['tripType'] ?? booking['rideType'] ?? '').toString();
    switch (t.toUpperCase()) {
      case 'ROUND_TRIP':
      case 'ROUND-TRIP':
      case 'ROUND':
        return 'Round Trip';
      case 'FLEXI':
        return 'Flexi';
      case 'ONE_WAY':
      case 'ONEWAY':
      case 'ONE-WAY':
      default:
        return 'One Way';
    }
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _Tokens.background,
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _fetchDashboard(),
                    _fetchBookings(),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _profileSection(),
                      const SizedBox(height: 8),
                      _statsSection(),
                      const SizedBox(height: 8),
                      _onGoingBookings(),
                      const SizedBox(height: 8),
                      _recommendedBookings(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── top yellow bar (hamburger + centered status pill) ───────────────

  Widget _topBar() {
    return Container(
      width: double.infinity,
      height: 76,
      color: _Tokens.yellow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hamburger → opens MyProfileScreen
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyProfileScreen()),
                );
                _fetchDashboard();
              },
              borderRadius: BorderRadius.circular(99),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Tokens.border),
                ),
                child: Center(
                  child: AssetIcon(
                    'assets/dashboard/hamburger.svg',
                    width: 22,
                    height: 18,
                    color: _Tokens.dark,
                  ),
                ),
              ),
            ),
          ),
          // Status pill (centered) — red/yellow-text when offline,
          // green/white-text when online.
          Obx(() {
            final online = _bc.isOnline.value;
            return Container(
              constraints: const BoxConstraints(minWidth: 101),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: online ? _Tokens.green : _Tokens.red,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 1.5,
                  ),
                ],
              ),
              child: Text(
                online ? 'Online' : 'Offline',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 20 / 15,
                  color: online ? Colors.white : _Tokens.yellow,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────── profile row ───────────────

  Widget _profileSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () async {
          await showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.25),
            builder: (_) => const ProfileDialog(),
          );
          _fetchDashboard();
        },
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: _profileImage.isNotEmpty
                    ? Image.network(
                        _profileImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Image.asset('assets/profile_pic.png',
                                fit: BoxFit.cover),
                      )
                    : Image.asset('assets/profile_pic.png',
                        fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _driverName.isNotEmpty ? _driverName : 'Driver',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 20 / 15,
                      color: _Tokens.gray1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ID: ',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 16 / 12,
                          color: _Tokens.gray2,
                        ),
                      ),
                      Text(
                        _shortDriverIdLong(),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 16 / 12,
                          color: _Tokens.gray2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const AssetIcon('assets/dashboard/star.svg', width: 20, height: 20),
            const SizedBox(width: 4),
            Text(
              _rating > 0 ? _rating.toStringAsFixed(1) : 'N/A',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 20 / 15,
                color: _Tokens.gray1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── stats row (Earning / Trips / Login Hrs) ───────────────

  Widget _statsSection() {
    var loginHrs =
        _preferredWorkHours.isNotEmpty ? _preferredWorkHours : '—';
    // Keep it short / single-line like the Figma ("17 Hrs").
    loginHrs = loginHrs.replaceAll(
        RegExp(r'\bHours\b', caseSensitive: false), 'Hrs');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _statTile(
              label: "Today's\nEarning",
              value: '₹${_todayEarnings.toStringAsFixed(0)}',
              backgroundColor: _Tokens.dark,
              textColor: Colors.white,
              borderColor: _Tokens.gray5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              label: "Today's\nTrips",
              value: '$_todayRides',
              backgroundColor: _Tokens.yellowAlt,
              textColor: _Tokens.dark,
              borderColor: _Tokens.gray5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              label: "Today's\nLogin Hrs",
              value: loginHrs,
              backgroundColor: _Tokens.yellow,
              textColor: _Tokens.dark,
              borderColor: null,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color backgroundColor,
    required Color textColor,
    required Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 16 / 12,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 22 / 17,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── On Going Bookings ───────────────

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 22 / 17,
                color: _Tokens.gray1,
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  'View All',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 16 / 12,
                    color: _Tokens.dark,
                  ),
                ),
                const SizedBox(width: 2),
                const AssetIcon('assets/dashboard/arrow_right.svg',
                    width: 16, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onGoingBookings() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            'On Going Bookings',
            onTap: () {
              // If a ride is live, "View All" resumes it; otherwise show the
              // take-booking screen.
              if (_bc.hasActiveRide) {
                pushTo(context, const ActiveRideScreen());
              } else {
                pushTo(context, const TakeBookingsScreen());
              }
            },
          ),
          const SizedBox(height: 16),
          // Reactive: the live ride is restored into the controller on launch
          // (survives an accidental app kill), so it always shows here even if
          // the booking-history fetch hasn't returned it.
          Obx(() {
            final cards = <Widget>[];

            final hasLive =
                _bc.hasActiveRide && _bc.bookingId.value.isNotEmpty;
            if (hasLive) {
              cards.add(InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => pushTo(context, const ActiveRideScreen()),
                child: _activeRideCard(),
              ));
            }

            // History-sourced ongoing bookings (e.g. scheduled/assigned not
            // yet loaded into the controller), excluding the live one.
            final ongoing = _recentBookings.where((b) {
              final status = (b['status'] ?? '').toString();
              final id = (b['_id'] ?? b['bookingId'] ?? '').toString();
              return ['ASSIGNED', 'DRIVER_ARRIVED', 'IN_PROGRESS', 'SEARCHING']
                      .contains(status) &&
                  id != _bc.bookingId.value;
            }).toList();
            for (final b in ongoing) {
              cards.add(InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _resumeOngoingBooking(b),
                child: _ongoingCard(b),
              ));
            }

            if (cards.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No ongoing bookings',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: Colors.grey.shade600),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final card in cards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: card,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Card for the currently-live ride restored into the controller. Bound to
  /// reactive state so it reflects the current phase; tap to resume.
  Widget _activeRideCard() {
    final type = _bc.tripType.value.isNotEmpty
        ? _bc.tripType.value
        : (_bc.vehicleType.value.isNotEmpty ? _bc.vehicleType.value : 'One Way');
    final phaseLabel = switch (_bc.rideState.value) {
      DriverRideState.navigatingToPickup => 'On the way to pickup',
      DriverRideState.arrivedAtPickup => 'Arrived at pickup',
      DriverRideState.inProgress => 'Trip in progress',
      _ => 'Ongoing',
    };
    final subtitle = _bc.dropAddress.value.isNotEmpty
        ? _bc.dropAddress.value
        : (_bc.pickupAddress.value.isNotEmpty ? _bc.pickupAddress.value : '');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _Tokens.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _Tokens.primaryBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: AssetIcon('assets/dashboard/routing.svg',
                  width: 28, height: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 20 / 15,
                          color: _Tokens.gray1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _Tokens.primaryBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Resume',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 16 / 11,
                          color: _Tokens.gray1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  phaseLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 16 / 12,
                    color: _Tokens.gray1,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                      color: _Tokens.gray2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ongoingCard(Map<String, dynamic> booking) {
    final type = _bookingTypeLabel(booking);
    final dateText = _formatBookingDate(
        booking['scheduledFor'] ?? booking['createdAt']);
    final startsIn = _formatStartsIn(booking);

    final iconAsset = type == 'Flexi'
        ? 'assets/dashboard/unlimited.svg'
        : 'assets/dashboard/routing.svg';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _Tokens.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _Tokens.primaryBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(iconAsset, width: 28, height: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 20 / 15,
                          color: _Tokens.gray1,
                        ),
                      ),
                    ),
                    if (dateText.isNotEmpty)
                      Text(
                        dateText,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                          color: _Tokens.dark,
                        ),
                      ),
                  ],
                ),
                if (startsIn.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Starts in: ',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 16 / 12,
                          color: _Tokens.gray2,
                        ),
                      ),
                      Text(
                        startsIn,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                          color: _Tokens.gray1,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Recommended Bookings ───────────────

  Widget _recommendedBookings() {
    // Show completed/cancelled history as the "recommended" carousel — this
    // keeps the screen consistent with what the previous dashboard surfaced
    // until a real recommendations endpoint exists.
    final recent = _recentBookings.where((b) {
      final s = (b['status'] ?? '').toString();
      return s == 'COMPLETED' || s == 'CANCELLED';
    }).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            'Recommended Bookings',
            onTap: () => pushTo(context, const HistoryScreen()),
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No bookings yet',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: Colors.grey.shade600),
              ),
            )
          else
            // Card width scales to the screen (with a small peek of the next
            // card) so it never overflows narrow devices — matches the Figma
            // ratio of ~350/393.
            SizedBox(
              height: 224,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                  width: MediaQuery.of(context).size.width - 44,
                  child: _recommendedCard(recent[i], i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recommendedCard(Map<String, dynamic> booking, int index) {
    // Alternate the date-badge style like the Figma mock (dark / yellow).
    final badgeYellow = index.isOdd;
    final type = _bookingTypeLabel(booking);
    final iconAsset = type == 'Round Trip'
        ? 'assets/dashboard/repeat.svg'
        : type == 'Flexi'
            ? 'assets/dashboard/unlimited.svg'
            : 'assets/dashboard/routing.svg';
    final dateText = _formatBookingDate(
        booking['scheduledFor'] ?? booking['createdAt']);
    final fare = (booking['finalFare'] ?? booking['fare'] ?? 0).toDouble();
    final distanceKm = (booking['distanceKm'] ?? 0).toDouble();
    final durationMin = (booking['durationMin'] ?? 0) as num;
    final estimateUsage = durationMin > 0
        ? (durationMin >= 60
            ? '${(durationMin / 60).toStringAsFixed(durationMin % 60 == 0 ? 0 : 1)} Hrs'
            : '${durationMin.toInt()} min')
        : '—';

    final pickup = booking['pickup'] ?? booking['pickupLocation'] ?? {};
    final drop = booking['drop'] ?? booking['dropLocation'] ?? {};
    final pickupAddr = (pickup is Map ? pickup['address'] : '')?.toString() ?? '';
    final dropAddr = (drop is Map ? drop['address'] : '')?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _Tokens.border),
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
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _Tokens.lightAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AssetIcon(iconAsset, width: 28, height: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                type,
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 20 / 15,
                                  color: _Tokens.gray1,
                                ),
                              ),
                            ),
                            if (dateText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeYellow
                                      ? _Tokens.yellow
                                      : _Tokens.dark,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  dateText,
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 13 / 11,
                                    color: badgeYellow
                                        ? const Color(0xFF191919)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Estimate Usage: ',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 16 / 12,
                                color: _Tokens.gray2,
                              ),
                            ),
                            Text(
                              estimateUsage,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 16 / 12,
                                color: _Tokens.gray1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 1,
                              height: 16,
                              color: _Tokens.border,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Total Dist.: ',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 16 / 12,
                                color: _Tokens.gray2,
                              ),
                            ),
                            Text(
                              distanceKm > 0
                                  ? '${distanceKm.toStringAsFixed(distanceKm % 1 == 0 ? 0 : 1)} km'
                                  : '—',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 16 / 12,
                                color: _Tokens.gray1,
                              ),
                            ),
                          ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
                height: 1,
                color: _Tokens.border,
                margin: const EdgeInsets.symmetric(horizontal: 0)),
            // Address block
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const AssetIcon('assets/dashboard/current_location.svg',
                          width: 20, height: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickupAddr.isNotEmpty ? pickupAddr : 'Pickup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 18 / 13,
                            color: _Tokens.gray1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: Container(
                      width: 2,
                      height: 12,
                      color: _Tokens.border,
                    ),
                  ),
                  Row(
                    children: [
                      const AssetIcon('assets/dashboard/location.svg',
                          width: 20, height: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dropAddr.isNotEmpty ? dropAddr : 'Drop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 18 / 13,
                            color: _Tokens.gray1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Fare strip
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _Tokens.primaryBg,
                border: Border(top: BorderSide(color: _Tokens.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AssetIcon('assets/dashboard/moneys.svg',
                      width: 20, height: 20),
                  const SizedBox(width: 8),
                  Text(
                    '₹${fare.toStringAsFixed(0)}',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 20 / 15,
                      color: _Tokens.dark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── Bottom slide-button (Online / Offline) ───────────────

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _Tokens.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Obx(() => Text(
                  _bc.isOnline.value
                      ? 'You are online'
                      : 'Check-in to get more bookings',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: _Tokens.gray2,
                  ),
                )),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Obx(() => _onlineButton()),
            ),
          ],
        ),
      ),
    );
  }

  /// Yellow slide-to-confirm control matching the Figma: a white chevron
  /// handle on the left that the driver drags across the track to toggle
  /// status. The action label ("Online" to go online, "Offline" to go
  /// offline) sits centered with a faded decorative rectangle on the right.
  Widget _onlineButton() {
    return _SlideToToggle(
      online: _bc.isOnline.value,
      loading: _bc.isLoading.value,
      onToggle: () async {
        await _bc.toggleOnline();
        if (mounted) _fetchDashboard();
      },
    );
  }
}

/// Slide-to-confirm button used to switch the driver between online and
/// offline. The driver drags the white chevron handle from the left edge to
/// the right edge of the yellow track to fire [onToggle]; an incomplete drag
/// springs the handle back to the start.
class _SlideToToggle extends StatefulWidget {
  const _SlideToToggle({
    required this.online,
    required this.loading,
    required this.onToggle,
  });

  final bool online;
  final bool loading;
  final Future<void> Function() onToggle;

  @override
  State<_SlideToToggle> createState() => _SlideToToggleState();
}

class _SlideToToggleState extends State<_SlideToToggle> {
  static const double _trackHeight = 48;
  static const double _handleWidth = 56;
  static const double _handleHeight = 44;
  static const double _margin = 2;

  double _dragX = 0;
  bool _dragging = false;

  @override
  void didUpdateWidget(_SlideToToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the handle to the start whenever the status flips or a load begins.
    if (oldWidget.online != widget.online || widget.loading) {
      _dragX = 0;
      _dragging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _handleWidth - _margin * 2;

        void onDragUpdate(DragUpdateDetails d) {
          if (widget.loading) return;
          setState(() {
            _dragging = true;
            _dragX = (_dragX + d.delta.dx).clamp(0, maxDrag);
          });
        }

        Future<void> onDragEnd(DragEndDetails d) async {
          if (widget.loading) return;
          final completed = _dragX >= maxDrag * 0.85;
          setState(() {
            _dragging = false;
            _dragX = 0;
          });
          if (completed) await widget.onToggle();
        }

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: _Tokens.yellow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Faded decorative rectangle (right side)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.asset(
                      'assets/dashboard/button_rect.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Centered label / loader
              Center(
                child: widget.loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_Tokens.gray1),
                        ),
                      )
                    : Text(
                        widget.online ? 'Offline' : 'Online',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 22 / 17,
                          color: const Color(0xFF191919),
                        ),
                      ),
              ),
              // White chevron handle (draggable)
              AnimatedPositioned(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: _margin + _dragX,
                top: _margin,
                child: GestureDetector(
                  onHorizontalDragUpdate: onDragUpdate,
                  onHorizontalDragEnd: onDragEnd,
                  child: Container(
                    width: _handleWidth,
                    height: _handleHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _Tokens.green.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: AssetIcon(
                        'assets/dashboard/chevron.svg',
                        width: 24,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

