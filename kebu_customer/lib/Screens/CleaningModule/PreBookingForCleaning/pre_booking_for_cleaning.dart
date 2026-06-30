import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/SelectDateScreen/select_date_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/ServiceDetailsScreen/service_details_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/ServiceInfoScreen/service_info_screen.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/household_api_service.dart';

class PreBookingForCleaning extends StatefulWidget {
  const PreBookingForCleaning({super.key});
  @override
  State<PreBookingForCleaning> createState() => _PreBookingForCleaningState();
}

class _PreBookingForCleaningState extends State<PreBookingForCleaning> {
  // ===== Design tokens (from Figma node 687:40632) =====
  static final Color _pink = HexColor('#E61978');
  static final Color _purple = HexColor('#461E98');
  static final Color _accentPink = HexColor('#D50069');
  // Time-slot card outline in the open/active design (Figma node 732:33890):
  // a soft pink rather than the neutral grey used elsewhere.
  static final Color _slotBorder = HexColor('#F0B8D4');

  List<dynamic> servicePackages = [];
  List<dynamic> starterPacks = [];
  List<dynamic> serviceTypes = [];
  List<dynamic> householdOffers = [];
  Map<String, dynamic>? singleBookingConfig;
  Map<String, dynamic>? multipleBookingConfig;
  bool isLoading = true;

  // Live "experts active around you" (backend: GET /services/active-experts).
  // Null until resolved; stays null if location is unavailable so we can fall
  // back to a static map + generic copy instead of showing "0 experts".
  int? activeExpertsCount;
  double? _userLat;
  double? _userLng;

  bool isOpen = true;
  String openTime = '06:00';
  String closeTime = '20:00';
  String closedMessage =
      "We are currently closed. Please check back during our service hours.";
  // Customer-facing arrival promise shown in the header ("arriving at your
  // doorstep in <arrivalEta>"). Backend-driven via getServiceHours; the default
  // keeps the Figma copy if the backend omits the field.
  String arrivalEta = '10 mins';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadActiveExperts();
  }

  /// Resolve the user's location, then ask the backend how many experts are
  /// currently online nearby. Reuses the location the app already fetched at
  /// startup (BookingController) for an instant result; only falls back to a
  /// fresh GPS fix if that isn't ready. Best-effort throughout.
  Future<void> _loadActiveExperts() async {
    try {
      double? lat;
      double? lng;

      // Fast path — the permanent BookingController already has the app-start
      // location, so reuse it instead of waiting on a fresh GPS fix.
      try {
        final bc = Get.find<BookingController>();
        if (bc.pickupLat.value != 0 && bc.pickupLng.value != 0) {
          lat = bc.pickupLat.value;
          lng = bc.pickupLng.value;
        }
      } catch (_) {/* controller not registered */}

      // Fall back to a device fix only if startup location isn't available.
      if (lat == null || lng == null) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 12),
              ),
            );
        lat = pos.latitude;
        lng = pos.longitude;
      }

      final res = await HouseholdApiService.getActiveExperts(lat: lat, lng: lng);
      if (!mounted) return;
      setState(() {
        _userLat = lat;
        _userLng = lng;
        if (res.success && res.data != null) {
          activeExpertsCount = (res.data['count'] as num?)?.toInt() ?? 0;
        }
      });
    } catch (_) {
      // Location unavailable / denied — keep the static fallback.
    }
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      HouseholdApiService.getServicePackages('default'),
      HouseholdApiService.getStarterPacks('default'),
      HouseholdApiService.getServiceTypes('default'),
      HouseholdApiService.getServiceHours(),
      CustomerFeaturesApiService.getOffers(),
      HouseholdApiService.getBookingTypeConfigs(),
    ]);
    if (mounted) {
      setState(() {
        if (results[0].success && results[0].data != null) {
          servicePackages = results[0].data['packages'] ?? [];
        }
        if (results[1].success && results[1].data != null) {
          starterPacks = results[1].data['starterPacks'] ?? [];
        }
        if (results[2].success && results[2].data != null) {
          serviceTypes = results[2].data['serviceTypes'] ?? [];
        }
        if (results[3].success && results[3].data != null) {
          final h = results[3].data;
          isOpen = h['isOpen'] == true;
          openTime = (h['openTime'] ?? '06:00').toString();
          closeTime = (h['closeTime'] ?? '20:00').toString();
          closedMessage = (h['closedMessage'] ?? closedMessage).toString();
          final eta = (h['arrivalEta'] ?? '').toString().trim();
          if (eta.isNotEmpty) arrivalEta = eta;
        }
        if (results[4].success && results[4].data != null) {
          final all = (results[4].data['offers'] as List?) ?? const [];
          householdOffers = all.where((o) {
            final a = (o is Map ? (o['applicableOn'] ?? '') : '')
                .toString()
                .toUpperCase();
            return a == 'HOUSEHOLD' || a == 'ALL';
          }).toList();
        }
        if (results[5].success && results[5].data != null) {
          final list = (results[5].data['bookingTypes'] as List?) ?? const [];
          for (final raw in list) {
            if (raw is! Map) continue;
            final cfg = Map<String, dynamic>.from(raw);
            final key = (cfg['bookingType'] ?? '').toString().toUpperCase();
            if (key == 'SINGLE') singleBookingConfig = cfg;
            if (key == 'MULTIPLE') multipleBookingConfig = cfg;
          }
        }
        isLoading = false;
      });
    }
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $suffix';
  }

  String _hourLabel(String raw) => _formatTime(raw)
      .replaceAll(':00', '')
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    // This screen is placed inside DashboardScreen's Scaffold.body. The outer
    // Scaffold owns the BottomNavigationBar, so we don't add our own Scaffold.
    final mq = MediaQuery.of(context);
    final trailingSpace = mq.viewPadding.bottom + 110;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: [
            _buildHeader(),
            Container(
              margin: const EdgeInsets.only(top: 250),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  topLeft: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  _buildTimeSlots(),
                  if (householdOffers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildOffersSection(),
                  ],
                  const SizedBox(height: 14),
                  _buildPrebookSection(),
                  const SizedBox(height: 12),
                  _buildServicesSection(),
                  const SizedBox(height: 12),
                  _buildVerifiedExpertsCard(),
                  const SizedBox(height: 12),
                  _buildActiveExpertsCard(),
                  SizedBox(height: trailingSpace),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HEADER ====================

  Widget _buildHeader() {
    final width = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 275,
      width: width,
      child: Stack(
        children: [
          // Gradient background
          Container(
            height: 275,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_pink, _purple],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          // Night-city / moon texture (soft light blend)
          Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: Image.asset(
                'assets/moon_icon_with_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                color: Colors.white.withOpacity(0.18),
                colorBlendMode: BlendMode.softLight,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Badges row
          Positioned(
            top: 78,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: _badge('assets/stopwatch.png',
                      "India's First", 'Quick Service App'),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _badge('assets/trust.png', 'Trusted by',
                      '50,000+ families'),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _badge('assets/high_five.png', 'One booking.',
                      'Multiple services'),
                ),
              ],
            ),
          ),

          // Logo + status line + closed sign
          Positioned(
            top: 132,
            left: 16,
            right: 14,
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
                            child: Image.asset(
                              'assets/logo/kebu_logo_horizontal_light.png',
                              height: 26,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _nowPill(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _statusLine(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _closedSign(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String icon, String line1, String line2) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(icon, height: 18, width: 18, fit: BoxFit.contain),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 8.5,
                        height: 1.15,
                        letterSpacing: -0.3)),
                Text(line2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 8.5,
                        height: 1.15,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nowPill() {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Now',
        style: GoogleFonts.poppins(
          color: HexColor('#2D0690'),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _statusLine() {
    final reopen = _hourLabel(openTime);
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 16, letterSpacing: -0.4),
        children: isOpen
            ? [
                // Figma node 732:33651 — "arriving at your doorstep in 10 mins"
                // with the ETA in gold semibold.
                const TextSpan(text: 'arriving at your doorstep in '),
                TextSpan(
                  text: arrivalEta,
                  style: TextStyle(
                    color: HexColor('#FFD546'),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                // Figma (node 687:41448) renders this title-cased with the
                // last word in medium weight: "Back at 6 am Tomorrow".
                TextSpan(text: 'Back at ${reopen.toLowerCase()} '),
                const TextSpan(
                  text: 'Tomorrow',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
      ),
    );
  }

  Widget _closedSign() {
    // Open state (Figma node 732:33591) keeps the header right side clear —
    // the logo + arrival line span the full width. Only the closed state shows
    // a sign.
    if (isOpen) return const SizedBox.shrink();
    return Image.asset(
      'assets/we_are_closed.png',
      width: 100,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  // ==================== TIME SLOTS ====================

  Widget _buildTimeSlots() {
    // Fully backend-driven: durations/prices come from getServicePackages.
    // While loading show a spinner; if the backend returns none, show an empty
    // state instead of inventing hardcoded slots.
    if (isLoading) {
      return const SizedBox(
        height: 139,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (servicePackages.isEmpty) {
      return Container(
        height: 139,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: Text(
          'No slots available right now',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
        ),
      );
    }
    final cards = <Widget>[];
    for (final pkg in servicePackages) {
      final name = (pkg['name'] ?? '').toString();
      final original = pkg['originalPrice'];
      final discounted = pkg['discountedPrice'];
      final offer = pkg['appliedOffer'] as Map<String, dynamic>?;
      final displayPrice = offer != null
          ? '${offer['finalPrice']}'
          : '${discounted ?? original ?? 0}';
      final strikePrice = '${original ?? discounted ?? 0}';
      final savingsPct = offer != null
          ? (offer['savingsPercent'] as num?)?.toInt() ??
              (pkg['discountPercentage'] as num?)?.toInt() ??
              0
          : (pkg['discountPercentage'] as num?)?.toInt() ?? 0;
      cards.add(_slotCard(name, displayPrice, strikePrice, savingsPct,
          pkg is Map ? pkg : const {}));
    }
    return SizedBox(
      height: 139,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  Widget _slotCard(
      String time, String price, String oldPrice, int savingsPct, Map pkg) {
    return Container(
      width: 123,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slotBorder),
      ),
      child: Column(
        children: [
          // Discount banner (Figma node 732:33891 — light-pink bg, pink text).
          Container(
            width: double.infinity,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HexColor('#FEE2F1'),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Text(
              savingsPct > 0 ? '$savingsPct% OFF' : 'OFFER',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: HexColor('#E51979'),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(time,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '₹$price',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: '  ₹$oldPrice',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.black,
                ),
              ),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 13, left: 13, right: 13),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: isOpen ? () => _openSlot(pkg) : null,
              child: Container(
                height: 31,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: isOpen ? _accentPink : Colors.black),
                ),
                child: Text(
                  isOpen ? 'Book Now' : 'Unavailable',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Book Now" on a duration slot → service details, seeded with whatever
  /// service/category context the package carries so the next screen scopes to
  /// it. Falls back to the generic single-booking flow when none is present.
  void _openSlot(Map pkg) {
    final serviceId = (pkg['serviceId'] ?? pkg['_id'] ?? '').toString();
    final categoryId = (pkg['categoryId'] ?? '').toString();
    final slug = (pkg['slug'] ?? pkg['serviceType'] ?? '').toString();
    pushTo(
      context,
      ServiceDetailsScreen(
        bookingType: 'SINGLE',
        serviceId: serviceId.isNotEmpty ? serviceId : null,
        categoryId: categoryId.isNotEmpty ? categoryId : null,
        serviceType: slug.isNotEmpty ? slug : null,
      ),
    );
  }

  // ==================== OFFERS ====================

  Widget _buildOffersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentPink.withOpacity(0.06), _purple.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Offers For You',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Grab them while we are open',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: householdOffers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _offerCard(householdOffers[i] as Map),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerCard(Map offer) {
    final title = (offer['title'] ?? 'Offer').toString();
    final code = (offer['code'] ?? '').toString();
    final discountType = (offer['discountType'] ?? '').toString().toUpperCase();
    final discountValue = offer['discountValue'];
    final subtitle = discountValue != null && discountType.isNotEmpty
        ? (discountType == 'PERCENTAGE'
            ? '$discountValue% OFF'
            : '₹$discountValue OFF')
        : (offer['subtitle'] ?? offer['description'] ?? '').toString();
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_pink, _purple],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
          const Spacer(),
          if (code.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: Text('Code: $code',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  // ==================== PREBOOK ====================

  Widget _buildPrebookSection() {
    final showSingle = singleBookingConfig == null
        ? true
        : (singleBookingConfig!['isActive'] != false);
    final showMultiple = multipleBookingConfig == null
        ? true
        : (multipleBookingConfig!['isActive'] != false);

    // Design order (node 687:40632): Single Booking on the left,
    // Multiple Booking on the right.
    final tiles = <Widget>[];
    if (showSingle) {
      tiles.add(_prebookButton(
        fallbackText: 'Single\nBooking',
        icon: 'assets/red_alarm.png',
        config: singleBookingConfig,
        bookingType: 'SINGLE',
      ));
    }
    if (showMultiple) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(width: 12));
      tiles.add(_prebookButton(
        fallbackText: 'Multiple\nBooking',
        icon: 'assets/blue_calender.png',
        config: multipleBookingConfig,
        bookingType: 'MULTIPLE',
      ));
    }

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prebook For Convenience',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Tap To Select Your Slot',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 16),
          if (tiles.isNotEmpty) Row(children: tiles),
        ],
      ),
    );
  }

  Widget _prebookButton({
    required String fallbackText,
    required String icon,
    Map<String, dynamic>? config,
    String bookingType = 'SINGLE',
  }) {
    final rawTitle = (config?['title'] as String?)?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle.replaceAll(' ', '\n')
        : fallbackText;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // A package is only a duration/price — the service is chosen separately,
        // so ask which service before sending the user into the booking flow.
        onTap: () => _pickServiceThenBook(bookingType),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accentPink),
            color: Colors.white.withOpacity(0.5),
          ),
          child: Row(
            children: [
              Image.asset(icon, width: 44, height: 44, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Home prebook has no service context, so let the user pick one first, then
  /// continue into the matching booking flow scoped to that service. Falls back
  /// to the generic flow only if no services are available yet.
  void _pickServiceThenBook(String bookingType) {
    if (serviceTypes.isEmpty) {
      pushTo(
        context,
        bookingType == 'MULTIPLE'
            ? const SelectDateScreen()
            : ServiceDetailsScreen(bookingType: bookingType),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
              child: Text('Select a service',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Choose which service you want to book',
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: Colors.black54)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: serviceTypes.whereType<Map>().map((raw) {
                  final s = Map<String, dynamic>.from(raw);
                  final name =
                      (s['serviceType'] ?? s['name'] ?? '').toString();
                  final slug = (s['slug'] ?? '').toString();
                  final id = (s['_id'] ?? '').toString();
                  final catId = (s['categoryId'] ?? '').toString();
                  final asset = _serviceAssetFor(name);
                  return ListTile(
                    leading: SizedBox(
                      width: 36,
                      height: 36,
                      child: asset.isNotEmpty
                          ? Image.asset(asset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.cleaning_services,
                                  color: _accentPink))
                          : Icon(Icons.cleaning_services, color: _accentPink),
                    ),
                    title: Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      if (bookingType == 'MULTIPLE') {
                        pushTo(
                          context,
                          SelectDateScreen(
                            categoryId: catId.isNotEmpty ? catId : null,
                            serviceType: slug.isNotEmpty ? slug : null,
                            serviceName: name.isNotEmpty ? name : null,
                          ),
                        );
                      } else {
                        pushTo(
                          context,
                          ServiceDetailsScreen(
                            categoryId: catId.isNotEmpty ? catId : null,
                            serviceId: id.isNotEmpty ? id : null,
                            serviceType: slug.isNotEmpty ? slug : null,
                            serviceName: name.isNotEmpty ? name : null,
                            bookingType: 'SINGLE',
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== OUR SERVICES ====================

  Widget _buildServicesSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Our Services',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Book Hourly And Avail Multiple Services',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 16),
          if (serviceTypes.isEmpty)
            _servicesEmptyState()
          else
            ..._buildServiceTilePairs(),
        ],
      ),
    );
  }

  List<Widget> _buildServiceTilePairs() {
    final tiles = <Widget>[];
    for (var i = 0; i < serviceTypes.length; i += 2) {
      final left = serviceTypes[i];
      final right = i + 1 < serviceTypes.length ? serviceTypes[i + 1] : null;
      tiles.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _serviceTile(left as Map)),
          const SizedBox(width: 12),
          Expanded(
            child: right != null
                ? _serviceTile(right as Map)
                : const SizedBox.shrink(),
          ),
        ],
      ));
      if (i + 2 < serviceTypes.length) {
        tiles.add(const SizedBox(height: 12));
      }
    }
    return tiles;
  }

  Widget _serviceTile(Map service) {
    // Backend stores the label as `serviceType`; keep `name`/`title` as
    // fallbacks for any legacy payloads.
    final title = (service['serviceType'] ??
            service['name'] ??
            service['title'] ??
            '')
        .toString();
    final image = (service['image'] ?? '').toString();
    final icon = (service['icon'] ?? '').toString();
    final slug = (service['slug'] ?? '').toString();
    final categoryId = (service['categoryId'] ?? '').toString();
    final isNetwork =
        image.startsWith('http://') || image.startsWith('https://');
    // An emoji icon (e.g. "🧹") has no ascii letters and isn't a URL/asset —
    // render it as a glyph instead of trying (and failing) to load an image.
    final isEmojiIcon = image.isEmpty &&
        icon.isNotEmpty &&
        !icon.startsWith('http') &&
        !icon.startsWith('assets/') &&
        !RegExp(r'[a-zA-Z]').hasMatch(icon);
    // A bundled illustration for a recognised service name ('' if unknown).
    final figmaAsset = _serviceAssetFor(title);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => pushTo(
        context,
        // Tapping a service opens its info screen (inclusions / exclusions /
        // requirements); "Book Now"/"Pre Book" there continue to the booking
        // flow. Category drives the tab strip; slug pre-selects this service.
        ServiceInfoScreen(
          categoryId: categoryId.isNotEmpty ? categoryId : 'default',
          initialSlug: slug.isNotEmpty ? slug : null,
        ),
      ),
      child: Container(
        height: 74,
        padding: const EdgeInsets.only(left: 8, top: 5, right: 4, bottom: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accentPink),
          color: Colors.white.withOpacity(0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500, height: 1.15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 56,
              width: 56,
              child: _serviceIcon(
                image: image,
                isNetwork: isNetwork,
                figmaAsset: figmaAsset,
                icon: icon,
                isEmojiIcon: isEmojiIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolve the tile artwork. Priority: an admin-uploaded image, then the
  /// bundled Figma illustration matched by service name, then an emoji icon
  /// (for custom services), then a neutral placeholder.
  Widget _serviceIcon({
    required String image,
    required bool isNetwork,
    required String figmaAsset,
    required String icon,
    required bool isEmojiIcon,
  }) {
    if (image.isNotEmpty) {
      return isNetwork
          ? Image.network(image,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _illustrationOrEmoji(figmaAsset, icon, isEmojiIcon))
          : Image.asset(image,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _illustrationOrEmoji(figmaAsset, icon, isEmojiIcon));
    }
    return _illustrationOrEmoji(figmaAsset, icon, isEmojiIcon);
  }

  Widget _illustrationOrEmoji(String figmaAsset, String icon, bool isEmojiIcon) {
    if (figmaAsset.isNotEmpty) {
      return Image.asset(figmaAsset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              isEmojiIcon ? _emojiIcon(icon) : _serviceIconFallback());
    }
    return isEmojiIcon ? _emojiIcon(icon) : _serviceIconFallback();
  }

  Widget _emojiIcon(String icon) =>
      Center(child: Text(icon, style: const TextStyle(fontSize: 34)));

  Widget _serviceIconFallback() => Icon(
        Icons.home_repair_service_outlined,
        color: Colors.grey.shade400,
      );

  /// Map a recognised service name to its bundled Figma illustration. Returns
  /// '' for unrecognised names so a custom service falls back to its emoji.
  String _serviceAssetFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('everyday') || n.contains('daily')) {
      return 'assets/every_day_cleaning.png';
    }
    if (n.contains('weekly')) return 'assets/weekly_cleaning.png';
    // 'dish' must be checked before 'wash' — "dishwashing" contains "wash".
    if (n.contains('dish')) return 'assets/diswash.png';
    if (n.contains('laundry') || n.contains('wash')) {
      return 'assets/washing_machine.png';
    }
    if (n.contains('bath') || n.contains('toilet')) {
      return 'assets/bathroom_toilet.png';
    }
    if (n.contains('kitchen') || n.contains('cook') || n.contains('prep')) {
      return 'assets/kitchen_prep.png';
    }
    return '';
  }

  Widget _servicesEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.home_repair_service_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('Services coming soon',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('New services will appear here once added',
              style:
                  GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ==================== VERIFIED EXPERTS ====================

  Widget _buildVerifiedExpertsCard() {
    return _sectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/family_expert.png',
            width: 110,
            height: 89,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: _accentPink.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Verified Experts',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(
                  'With valid ID proof & a spotless background for your peace of mind',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.black87, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVE EXPERTS NEARBY ====================

  Widget _buildActiveExpertsCard() {
    final count = activeExpertsCount;
    final title = count == null
        ? 'Experts active around you'
        : '$count ${count == 1 ? 'expert' : 'experts'} currently active around you';
    final hasLocation = _userLat != null && _userLng != null;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 141,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white),
              ),
              child: hasLocation
                  ? GoogleMapWidget(
                      centerLat: _userLat,
                      centerLng: _userLng,
                      pickupLat: _userLat,
                      pickupLng: _userLng,
                      zoom: 14,
                      interactive: false,
                      liteModeEnabled: true,
                      showZoomButtons: false,
                      showMyLocation: false,
                    )
                  : Image.asset(
                      'assets/map_view.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: HexColor('#EFEFEF'),
                        alignment: Alignment.center,
                        child: Icon(Icons.map_outlined,
                            size: 40, color: Colors.grey.shade400),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED ====================

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accentPink.withOpacity(0.05), _purple.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
