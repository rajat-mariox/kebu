import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/map_warmup.dart';
import 'package:kebu_customer/Screens/BookARideModule/BookARide/book_a_ride_screen.dart';
import 'package:kebu_customer/Screens/BookARideModule/BookingDetail/booking_detail_screen.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/LiveTracking/live_tracking_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/PreBookingForCleaning/pre_booking_for_cleaning.dart';
import 'package:kebu_customer/Screens/CleaningModule/HouseholdLiveTracking/household_live_tracking_screen.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:kebu_customer/Screens/Screens/ManagePlanScreen/manage_plan_screen.dart';
import 'package:kebu_customer/Screens/Screens/WalletScreen/wallet_screen.dart';
import 'package:kebu_customer/Screens/SendParcelModule/SendParcelScreen/send_parcel_screen.dart';
import 'package:kebu_customer/Services/user_api_service.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/wallet_api_service.dart';
import 'package:kebu_customer/Services/socket_service.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Widget screen)? onServiceSelected;
  final VoidCallback? onServiceBack;
  const HomeScreen({super.key, this.onServiceSelected, this.onServiceBack});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String userName = "";
  String userPhoto = "";
  String userLocation = "Location";
  String referralCode = "KEBU50";
  double walletBalance = 0;
  List<dynamic> recentBookings = [];
  List<dynamic> offers = [];
  List<dynamic> latestOffers = [];
  List<dynamic> limitedOffers = [];
  List<dynamic> justForYouOffers = [];
  bool isLoading = true;

  // Active household/service booking (so the customer can resume tracking after
  // the app is killed). Null when there's nothing in progress.
  Map<String, dynamic>? _activeService;
  static const _serviceActiveStatuses = {
    'ACCEPTED',
    'PROVIDER_ASSIGNED',
    'PROVIDER_EN_ROUTE',
    'PROVIDER_ARRIVED',
    'IN_PROGRESS',
  };
  // Ride statuses that should surface the resume mini-tracker.
  static const _rideActiveStatuses = {
    'SEARCHING',
    'ASSIGNED',
    'DRIVER_ARRIVED',
    'PICKED',
    'IN_PROGRESS',
  };

  String _selectedChip = 'Trending';
  int _bookingPage = 0;
  final PageController _bookingPageController =
      PageController(viewportFraction: 0.92);

  @override
  void initState() {
    super.initState();
    _loadData();
    SocketService().connect();
    _checkActiveBooking();
    _checkActiveServiceBooking();

    final bookingController = Get.find<BookingController>();
    if (bookingController.pickupLat.value == 0 &&
        !bookingController.currentLocationLoaded.value) {
      bookingController.detectCurrentLocation();
    }

    // Pre-warm the native Google Maps SDK while the user is on the home screen
    // so "Book a cab" and live-tracking maps render instantly when opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MapWarmup.ensure(context);
    });
  }

  @override
  void dispose() {
    _bookingPageController.dispose();
    super.dispose();
  }

  void _shareReferral() {
    final code = referralCode.isEmpty ? "KEBU50" : referralCode;
    final text = "Join KebuOne and get ₹50 in your wallet! "
        "Use my referral code: $code\n"
        "Download now: https://kebu.app/refer/$code";
    Share.share(text);
  }

  Future<void> _checkActiveBooking() async {
    final bc = Get.find<BookingController>();
    await bc.checkActiveBooking();
    // No auto-open — the floating ride mini-tracker (reactive on the
    // controller's bookingStatus) lets the user resume tracking on tap.
    if (mounted) setState(() {});
  }

  /// Resume support: if the user has an accepted/in-progress service booking,
  /// surface a banner so they can reopen live tracking after an app restart.
  Future<void> _checkActiveServiceBooking() async {
    final res = await HouseholdApiService.getActiveBooking();
    if (!mounted) return;
    Map<String, dynamic>? active;
    if (res.success && res.data != null && res.data['booking'] is Map) {
      final b = Map<String, dynamic>.from(res.data['booking']);
      final status = (b['status'] ?? '').toString();
      if (_serviceActiveStatuses.contains(status)) active = b;
    }
    if (active != _activeService) setState(() => _activeService = active);
  }

  void _openServiceTracking(Map<String, dynamic> b) {
    final bookingId = (b['_id'] ?? '').toString();
    if (bookingId.isEmpty) return;
    final provider = (b['providerId'] is Map)
        ? Map<String, dynamic>.from(b['providerId'])
        : <String, dynamic>{};
    final address = (b['address'] is Map)
        ? Map<String, dynamic>.from(b['address'])
        : <String, dynamic>{};
    pushTo(
      context,
      HouseholdLiveTrackingScreen(
        bookingId: bookingId,
        provider: provider,
        destinationLat: (address['lat'] as num?)?.toDouble() ?? 0,
        destinationLng: (address['lng'] as num?)?.toDouble() ?? 0,
        destinationAddress: (address['fullAddress'] ?? '').toString(),
        otp: (b['otp'] ?? '').toString(),
      ),
    );
  }

  String _serviceStatusLabel(String s) {
    switch (s) {
      case 'PROVIDER_EN_ROUTE':
        return 'Partner on the way';
      case 'PROVIDER_ARRIVED':
        return 'Partner arrived';
      case 'IN_PROGRESS':
        return 'Service in progress';
      default:
        return 'Partner assigned';
    }
  }

  String _rideStatusLabel(String s) {
    switch (s) {
      case 'SEARCHING':
        return 'Finding your driver';
      case 'DRIVER_ARRIVED':
        return 'Driver arrived';
      case 'PICKED':
      case 'IN_PROGRESS':
        return 'Trip in progress';
      default:
        return 'Driver assigned';
    }
  }

  /// Floating resume mini-tracker for an active cab ride (same white style as
  /// the household one). Tapping reopens live tracking.
  Widget _rideMiniTracker(String status) {
    final driver = Get.find<BookingController>().driverInfo;
    final name = (driver['fullName'] ?? 'Your driver').toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => pushTo(context, const LiveTrackingScreen()),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
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
                  color: HexColor('#F4F4F6'),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_taxi_rounded,
                    color: HexColor('#1B1D21'), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rideStatusLabel(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: HexColor('#1B1D21'),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$name • Tap to track',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.black54, size: 22),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact floating "mini screen" pinned above the bottom nav so an active
  /// service is always reachable after an app restart — tap to expand into full
  /// live tracking.
  Widget _miniTracker() {
    final b = _activeService!;
    final status = (b['status'] ?? '').toString();
    final provider = (b['providerId'] is Map)
        ? Map<String, dynamic>.from(b['providerId'])
        : <String, dynamic>{};
    final name = (provider['fullName'] ?? 'Your partner').toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openServiceTracking(b),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
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
                  color: HexColor('#F4F4F6'),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.near_me_rounded,
                    color: HexColor('#1B1D21'), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceStatusLabel(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: HexColor('#1B1D21'),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$name • Tap to track',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.black54, size: 22),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      UserApiService.getProfile(),
      BookingApiService.getBookingHistory(limit: 2, status: 'COMPLETED'),
      CustomerFeaturesApiService.getOffers(),
      CustomerFeaturesApiService.getReferralInfo(),
      WalletApiService.getWallet(),
    ]);

    if (mounted) {
      setState(() {
        isLoading = false;
        if (results[0].success && results[0].data != null) {
          userName = results[0].data['fullName'] ?? "";
          userPhoto = results[0].data['profileImage']?.toString() ?? "";
        }
        if (results[1].success && results[1].data != null) {
          final bookings = (results[1].data['bookings'] as List? ?? [])
              .whereType<Map>()
              .map((b) => Map<String, dynamic>.from(b))
              .where((booking) {
                final rawUserId = booking['userId'];
                final bookingUserId = rawUserId is Map
                    ? rawUserId['_id']?.toString()
                    : rawUserId?.toString();

                final matchesCurrentUser = bookingUserId == null ||
                    bookingUserId.isEmpty ||
                    bookingUserId == Prefs.user_id;

                return matchesCurrentUser &&
                    booking['status']?.toString().toUpperCase() == 'COMPLETED';
              }).toList();

          recentBookings = bookings.take(2).toList();
        }
        if (results[2].success && results[2].data != null) {
          final data = results[2].data;
          offers = data['offers'] ?? [];
          latestOffers = data['latestOffers'] ?? [];
          limitedOffers = data['limitedOffers'] ?? [];
          justForYouOffers = data['justForYouOffers'] ?? [];
        }
        if (results[3].success && results[3].data != null) {
          referralCode = results[3].data['referralCode'] ?? "KEBU50";
        }
        if (results[4].success && results[4].data != null) {
          walletBalance = (results[4].data['balance'] ?? 0).toDouble();
        }
      });
    }
  }

  // ==================== NAVIGATION HELPERS ====================

  void _openService(Widget Function() builder) {
    if (widget.onServiceSelected != null) {
      widget.onServiceSelected!(builder());
    } else {
      pushTo(context, builder());
    }
  }

  void _comingSoon(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$feature is coming soon"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingController = Get.find<BookingController>();
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              children: [
            // ==================== HEADER (gradient) ====================
            commonAppBar(
              height: 200,
              context: context,
              child: Container(
                padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "Hi, ${userName.isNotEmpty ? userName : 'there'}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    pushTo(context, const ManagePlanScreen()),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: width * 0.45,
                                child: Obx(() {
                                  final pickupAddress =
                                      bookingController.pickupAddress.value.trim();
                                  final hasResolvedAddress =
                                      pickupAddress.isNotEmpty &&
                                          pickupAddress != 'My current location';
                                  final headerLocation = hasResolvedAddress
                                      ? pickupAddress
                                      : 'Detecting location…';
                                  return Text(
                                    headerLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _walletButton(),
                    const SizedBox(width: 10),
                    const NotificationIconButton(
                      height: 30,
                      margin: EdgeInsets.only(top: 4),
                    ),
                  ],
                ),
              ),
            ),

            // ==================== WHITE BODY ====================
            Column(
              children: [
                const SizedBox(height: 140),
                Container(
                  width: width,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(32),
                      topLeft: Radius.circular(32),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(32),
                      topLeft: Radius.circular(32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -------- WELCOME --------
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome 👋",
                                style: GoogleFonts.dmSans(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: HexColor("#1B1D21"),
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Need a helping hand today?",
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // -------- SERVICE GRID --------
                        _serviceGrid(),

                        const SizedBox(height: 28),

                        // -------- OFFERS & NEWS --------
                        _offersSection(),

                        const SizedBox(height: 28),

                        // -------- RECENT BOOKINGS --------
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            "Recent bookings",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: HexColor("#333333"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _recentBookingsCarousel(),

                        const SizedBox(height: 28),

                        // -------- INVITE FRIENDS --------
                        _inviteCard(),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  final s = bookingController.bookingStatus.value;
                  if (!_rideActiveStatuses.contains(s)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: _activeService != null ? 10 : 0),
                    child: _rideMiniTracker(s),
                  );
                }),
                if (_activeService != null) _miniTracker(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HEADER WIDGETS ====================

  Widget _walletButton() {
    return GestureDetector(
      onTap: () async {
        await pushTo(context, const WalletScreen());
        final res = await WalletApiService.getWallet();
        if (res.success && res.data != null && mounted) {
          setState(() => walletBalance = (res.data['balance'] ?? 0).toDouble());
        }
      },
      child: Container(
        width: 66,
        height: 40,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: HexColor("#FF9900")),
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    "₹ ${walletBalance.toStringAsFixed(0)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      color: HexColor("#100F0E"),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: HexColor("#FF9900"),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                "Wallet",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SERVICE GRID ====================

  Widget _serviceGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _coloredServiceTile(
                "Book a Ride",
                "assets/book_a_ride.png",
                [HexColor("#FFD546"), HexColor("#FFB800")],
                () => _openService(
                    () => BookARideScreen(onBack: widget.onServiceBack)),
              ),
              const SizedBox(width: 12),
              _coloredServiceTile(
                "Send Parcel",
                "assets/send_parcel.png",
                [HexColor("#F52059"), HexColor("#D91916")],
                () => _openService(
                    () => SendParcelScreen(onBack: widget.onServiceBack)),
              ),
              const SizedBox(width: 12),
              _coloredServiceTile(
                "House Help",
                "assets/house_hold_service.png",
                [HexColor("#226DD2"), HexColor("#3B2FA8")],
                () => _openService(() => const PreBookingForCleaning()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _lightServiceTile(
                "Recharge",
                "assets/recharge.png",
                () => _comingSoon("Recharge"),
              ),
              const SizedBox(width: 12),
              _lightServiceTile(
                "Pay Bills",
                "assets/pay_bills.png",
                () => _comingSoon("Pay Bills"),
              ),
              const SizedBox(width: 12),
              _lightServiceTile(
                "Bookings",
                "assets/bookings.png",
                () => _comingSoon("Bookings"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coloredServiceTile(
      String title, String asset, List<Color> gradient, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient.map((c) => c.withOpacity(0.28)).toList(),
            ),
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(asset, width: 58, height: 58, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HexColor("#282828"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lightServiceTile(String title, String asset, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: HexColor("#FFE6E6").withOpacity(0.5),
            border: Border.all(color: HexColor("#585858").withOpacity(0.25)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(asset, width: 62, height: 62, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HexColor("#282828"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== OFFERS & NEWS ====================

  List<Map<String, dynamic>> get _allOffers {
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final src in [offers, latestOffers, limitedOffers, justForYouOffers]) {
      for (final o in src) {
        if (o is Map) {
          final m = Map<String, dynamic>.from(o);
          final key = "${m['title']}|${m['code']}|${m['image'] ?? m['bannerImage']}";
          if (seen.add(key)) list.add(m);
        }
      }
    }
    return list;
  }

  List<Map<String, dynamic>> get _defaultOffers => [
        {
          'title': 'Upgrade to Kebu One Pass',
          'subtitle': 'Unlock VIP Mobility & Services',
          'tag': 'Get 1 Month Free',
          'targetService': 'subscription',
        },
        {
          'title': '10% Off',
          'subtitle': 'Online Payment',
          'tag': 'New User',
          'code': 'KEBU10',
        },
      ];

  List<String> get _offerChips {
    final tags = <String>{};
    for (final o in _allOffers) {
      final t = (o['tag'] ?? '').toString().trim();
      if (t.isNotEmpty) tags.add(t);
    }
    return ['Trending', ...tags];
  }

  List<Map<String, dynamic>> get _visibleOffers {
    final source = _allOffers.isEmpty ? _defaultOffers : _allOffers;
    if (_selectedChip == 'Trending') return source;
    final filtered = source
        .where((o) => (o['tag'] ?? '').toString() == _selectedChip)
        .toList();
    return filtered.isEmpty ? source : filtered;
  }

  Widget _offersSection() {
    final chips = _offerChips;
    final cards = _visibleOffers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          child: Text(
            "Offers & News",
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HexColor("#1B1D21"),
              letterSpacing: -0.35,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: chips.map((c) => _offerChip(c)).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _offerCard(cards[i]),
          ),
        ),
      ],
    );
  }

  Widget _offerChip(String label) {
    final selected = label == _selectedChip;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedChip = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? HexColor("#FD6B22") : Colors.transparent,
            border: selected
                ? null
                : Border.all(color: HexColor("#1B1D21").withOpacity(0.5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: -0.3,
              color: selected
                  ? Colors.white
                  : HexColor("#1B1D21").withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    final title = (offer['title'] ?? '').toString();
    final subtitle =
        (offer['subtitle'] ?? offer['description'] ?? '').toString();
    final image = (offer['image'] ?? offer['bannerImage'] ?? '').toString();
    final tag = (offer['tag'] ?? '').toString();
    final isPass = (offer['targetService']?.toString() == 'subscription') ||
        title.toLowerCase().contains('kebu one');
    final endDateRaw = offer['endDate']?.toString();
    final endsIn = endDateRaw != null ? _formatEndsIn(endDateRaw) : null;

    final gradient = isPass
        ? [HexColor("#61628B"), HexColor("#1E1F48")]
        : [HexColor("#FFD546"), HexColor("#FF155E")];

    return GestureDetector(
      onTap: () => _openOfferTarget(offer),
      child: Container(
        width: 272,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPass
                            ? HexColor("#FD6B22")
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (tag.isNotEmpty) const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 10,
                      ),
                    ),
                  ],
                  if (endsIn != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          endsIn,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 80,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _offerPlaceholder(isPass),
                    )
                  : _offerPlaceholder(isPass),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerPlaceholder(bool isPass) {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isPass ? Icons.workspace_premium : Icons.local_offer,
        color: Colors.white,
        size: 34,
      ),
    );
  }

  String? _formatEndsIn(String endDateIso) {
    final end = DateTime.tryParse(endDateIso);
    if (end == null) return null;
    final now = DateTime.now();
    final diff = end.difference(now);
    if (diff.isNegative) return "Expired";
    if (diff.inDays >= 1) return "Ends in ${diff.inDays}d";
    if (diff.inHours >= 1) return "Ends in ${diff.inHours}h";
    if (diff.inMinutes >= 1) return "Ends in ${diff.inMinutes}m";
    return "Ending soon";
  }

  void _openOfferTarget(Map<String, dynamic> offer) {
    final target = (offer['targetService'] ?? 'none').toString();
    switch (target) {
      case 'booking':
        _openService(() => BookARideScreen(onBack: widget.onServiceBack));
        break;
      case 'cleaning':
        _openService(() => const PreBookingForCleaning());
        break;
      case 'parcel':
        _openService(() => SendParcelScreen(onBack: widget.onServiceBack));
        break;
      case 'subscription':
        pushTo(context, const ManagePlanScreen());
        break;
      default:
        final code = (offer['code'] ?? '').toString();
        if (code.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Use code $code at checkout")),
          );
        }
        break;
    }
  }

  // ==================== INVITE FRIENDS ====================

  Widget _inviteCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      child: GestureDetector(
        onTap: _shareReferral,
        child: Container(
          height: 148,
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: HexColor("#FFF8F8"),
            border: Border.all(color: HexColor("#FFD347")),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Invite your friends to\ntry KebuOne",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          referralCode,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.4,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [HexColor("#FFD546"), HexColor("#FF155E")],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Share invite code",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                "assets/invite_icon.png",
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== RECENT BOOKINGS ====================

  Widget _recentBookingsCarousel() {
    if (recentBookings.isEmpty) {
      return _emptyBookingCard();
    }

    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _bookingPageController,
            itemCount: recentBookings.length,
            onPageChanged: (i) => setState(() => _bookingPage = i),
            itemBuilder: (_, i) => SingleChildScrollView(
              child: _bookingTile(
                Map<String, dynamic>.from(recentBookings[i] as Map),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ),
        if (recentBookings.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(recentBookings.length, (i) {
              final active = i == _bookingPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 8,
                width: active ? 22 : 8,
                decoration: BoxDecoration(
                  color: active ? HexColor("#0A84FF") : HexColor("#D9D9D9"),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _emptyBookingCard() {
    final bookingController = Get.find<BookingController>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Start your first booking",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Book a ride with your current location and then choose your destination.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                bookingController.resetBooking(redetectLocation: true);
                _openService(
                    () => BookARideScreen(onBack: widget.onServiceBack));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HexColor("#FFD546"),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                "Start Your First Booking",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingTile(Map<String, dynamic> booking, {EdgeInsetsGeometry? margin}) {
    final pickupAddress =
        booking['pickup']?['address']?.toString() ?? 'Pickup location';
    final dropAddress =
        booking['drop']?['address']?.toString() ?? 'Drop location';
    final finalFare =
        booking['finalFare'] ?? booking['estimatedFare'] ?? booking['fare'] ?? 0;

    // Driver info (populated object)
    final driver = booking['driverId'] is Map
        ? Map<String, dynamic>.from(booking['driverId'] as Map)
        : <String, dynamic>{};
    final driverName = (driver['fullName']?.toString().trim().isNotEmpty ?? false)
        ? driver['fullName'].toString()
        : 'Driver';
    final driverImage = driver['profileImage']?.toString() ?? '';
    final driverRating = _parseRating(
      booking['rating'] ?? driver['rating'],
    );
    final driverRatingText =
        driverRating != null ? driverRating.toStringAsFixed(1) : '—';

    // Vehicle info (populated object)
    final vehicleType = booking['vehicleTypeId'] is Map
        ? Map<String, dynamic>.from(booking['vehicleTypeId'] as Map)
        : (booking['vehicleType'] is Map
            ? Map<String, dynamic>.from(booking['vehicleType'] as Map)
            : <String, dynamic>{});
    final vehicleName = vehicleType['name']?.toString() ?? 'Ride';
    final vehicleImage = vehicleType['image']?.toString() ?? '';
    final maxSeats = vehicleType['maxSeats']?.toString() ?? '-';

    // Passenger info — for booked-for-someone-else, prefer rider; else fall back
    // to the logged-in customer (from userId populate, then prefs).
    final user = booking['userId'] is Map
        ? Map<String, dynamic>.from(booking['userId'] as Map)
        : <String, dynamic>{};
    final rider = booking['riderId'] is Map
        ? Map<String, dynamic>.from(booking['riderId'] as Map)
        : <String, dynamic>{};
    final riderName = (booking['riderName']?.toString().trim().isNotEmpty ?? false)
        ? booking['riderName'].toString()
        : (rider['fullName']?.toString() ?? '');
    final riderPhone = (booking['riderPhone']?.toString().trim().isNotEmpty ?? false)
        ? booking['riderPhone'].toString()
        : (rider['mobileNumber']?.toString() ?? '');
    final riderPhoto = rider['profileImage']?.toString() ?? '';
    final isForSelf = riderName.isEmpty && riderPhone.isEmpty;
    final passengerName = isForSelf
        ? ((user['fullName']?.toString().trim().isNotEmpty ?? false)
            ? user['fullName'].toString()
            : (userName.isNotEmpty ? userName : 'Self'))
        : riderName;
    final passengerPhone = isForSelf
        ? ((user['mobileNumber']?.toString().trim().isNotEmpty ?? false)
            ? user['mobileNumber'].toString()
            : Prefs.mobile_number)
        : riderPhone;
    final passengerPhoto = isForSelf
        ? ((user['profileImage']?.toString().trim().isNotEmpty ?? false)
            ? user['profileImage'].toString()
            : userPhoto)
        : riderPhoto;

    final createdAt = _formatDateTime(booking['createdAt']?.toString());
    final status = booking['status']?.toString() ?? 'Booked';
    final bookingId = booking['_id']?.toString() ?? '';

    return Container(
      margin: margin ?? const EdgeInsets.only(left: 20, right: 20, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: bookingId.isEmpty
              ? null
              : () => pushTo(
                  context,
                  BookingDetailScreen(
                    bookingId: bookingId,
                    initialBooking: booking,
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _driverAvatar(driverImage),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        if (vehicleImage.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              vehicleImage,
                              width: 28,
                              height: 18,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            vehicleName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    "₹$finalFare",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(
                        left: 7, right: 7, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      color: HexColor("#0A84FF"),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          driverRatingText,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.star, size: 19, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),

          Container(
            height: 1,
            width: MediaQuery.of(context).size.width,
            color: HexColor("#ECECEC"),
          ),

          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickupAddress,
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
              margin: const EdgeInsets.only(left: 20, right: 20),
              child: Image.asset("assets/dotted_line.png")),

          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dropAddress,
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Container(
            height: 1,
            width: MediaQuery.of(context).size.width,
            color: HexColor("#ECECEC"),
          ),

          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Image.asset("assets/clock.png", height: 22),
                  const SizedBox(height: 2),
                  Text(createdAt['time']!,
                      style: GoogleFonts.poppins(fontSize: 11)),
                ],
              ),
              Column(
                children: [
                  Image.asset("assets/calendar.png", height: 22),
                  const SizedBox(height: 2),
                  Text(createdAt['date']!,
                      style: GoogleFonts.poppins(fontSize: 11)),
                ],
              ),
              Column(
                children: [
                  Image.asset("assets/car_seat.png", height: 22),
                  const SizedBox(height: 2),
                  Text("$maxSeats Seats",
                      style: GoogleFonts.poppins(fontSize: 11)),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 22),
                  const SizedBox(height: 2),
                  Text(_prettyStatus(status),
                      style: GoogleFonts.poppins(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),

          Container(
            height: 1,
            width: MediaQuery.of(context).size.width,
            color: HexColor("#ECECEC"),
          ),

          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _personAvatar(passengerPhoto),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Passenger Information",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isForSelf
                          ? "$passengerName (Self)"
                          : passengerName.isNotEmpty
                              ? passengerName
                              : 'Guest',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    if (passengerPhone.isNotEmpty)
                      Text(
                        passengerPhone,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
            ],
          ),
        ),
          ),
        ),
    );
  }

  Widget _driverAvatar(String url) => _personAvatar(url, size: 42);

  Widget _personAvatar(String url, {double size = 42}) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Colors.grey.shade500,
      ),
    );

    final trimmed = url.trim();
    if (trimmed.isEmpty) return placeholder;

    return ClipOval(
      child: Image.network(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }

  double? _parseRating(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _prettyStatus(String raw) {
    final s = raw.toUpperCase();
    switch (s) {
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'PICKED':
        return 'Picked up';
      case 'DRIVER_ARRIVED':
        return 'Arrived';
      case 'ASSIGNED':
        return 'Assigned';
      case 'SEARCHING':
        return 'Searching';
      case 'NO_DRIVERS':
        return 'No drivers';
      default:
        return raw;
    }
  }

  Map<String, String> _formatDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return {'date': '-', 'time': '-'};
    }

    try {
      final date = DateTime.parse(value).toLocal();
      return {
        'date': DateFormat('dd/MM/yyyy').format(date),
        'time': DateFormat('hh:mm a').format(date),
      };
    } catch (_) {
      return {'date': value, 'time': '-'};
    }
  }
}
