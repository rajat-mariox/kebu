import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/BookARide/book_a_ride_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/AcRepairScreen/ac_repair_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/HouseHoldService/house_hold_service.dart';
import 'package:kebu_customer/Screens/CleaningModule/PreBookingForCleaning/pre_booking_for_cleaning.dart';
import 'package:kebu_customer/Screens/SendParcelModule/SendParcelScreen/send_parcel_screen.dart';
import 'package:kebu_customer/Screens/Screens/ScratchCardScreen/scratch_card_screen.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});
  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<dynamic> offers = [];
  List<dynamic> scratchCards = [];
  bool isLoading = true;

  // Figma gradient palettes
  final List<List<Color>> _latestGradients = [
    [const Color(0xFF2369CF), const Color(0xFF1E5BB5)],
    [const Color(0xFFFFD546), const Color(0xFFFF155E)],
    [const Color(0xFF7E57C2), const Color(0xFF5E35B1)],
  ];
  final List<List<Color>> _jfyGradients = [
    [const Color(0xFF11CEC0), const Color(0xFF138884)],
    [const Color(0xFFFFDB60), const Color(0xFFFC7651)],
    [const Color(0xFF3F8AF8), const Color(0xFF1657B5)],
  ];

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _loadScratchCards();
  }

  Future<void> _loadOffers() async {
    final response = await CustomerFeaturesApiService.getOffers();
    if (response.success && response.data != null && mounted) {
      setState(() {
        offers = response.data['offers'] ?? [];
        isLoading = false;
      });
    } else if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadScratchCards() async {
    final response = await CustomerFeaturesApiService.getScratchCards();
    if (response.success && response.data != null && mounted) {
      setState(() => scratchCards = response.data['cards'] ?? []);
    }
  }

  List<dynamic> get _unscratchedCards =>
      scratchCards.where((c) => (c['status'] ?? '') == 'UNSCRATCHED').toList();

  void _openScratchCards() {
    pushTo(context, const ScratchCardScreen()).then((_) {
      if (mounted) _loadScratchCards();
    });
  }

  List<dynamic> _filter(String section) =>
      offers.where((o) => (o['section'] ?? '') == section).toList();

  void _onOfferTap(Map offer) {
    final applicableOn = (offer['applicableOn'] ?? '').toString().toUpperCase();
    final target = (offer['targetService'] ?? '').toString().toLowerCase();
    final categories = (offer['categories'] as List?) ?? const [];
    final firstCategory = categories.isNotEmpty ? categories.first : null;
    String? categoryId;
    String? categoryName;
    if (firstCategory is Map) {
      categoryId = firstCategory['_id']?.toString();
      categoryName = firstCategory['name']?.toString();
    } else if (firstCategory is String) {
      categoryId = firstCategory;
    }

    String flow = target;
    if (flow.isEmpty || flow == 'none') {
      if (applicableOn == 'CAB') {
        flow = 'booking';
      } else if (applicableOn == 'DELIVERY') {
        flow = 'parcel';
      } else if (applicableOn == 'HOUSEHOLD') {
        flow = 'cleaning';
      }
    }

    switch (flow) {
      case 'booking':
        pushTo(context, const BookARideScreen());
        break;
      case 'parcel':
        pushTo(context, const SendParcelScreen());
        break;
      case 'cleaning':
        if (categoryId != null && categoryId.isNotEmpty) {
          pushTo(
            context,
            AcRepairScreen(
              serviceName: categoryName ?? 'Service',
              categoryId: categoryId,
            ),
          );
        } else {
          pushTo(context, const HouseHoldService());
        }
        break;
      default:
        pushTo(context, const PreBookingForCleaning());
    }
  }

  String _discountText(Map o) {
    final type = (o['type'] ?? '').toString().toUpperCase();
    final value = o['value'];
    if (type == 'PERCENTAGE' && value != null) return '$value% Off';
    if (type == 'FLAT' && value != null) return '₹$value Off';
    if (type == 'CASHBACK' && value != null) return '₹$value Cashback';
    return (o['title'] ?? 'Offer').toString();
  }

  String _subtitle(Map o) =>
      (o['subtitle'] ?? o['description'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
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
                      "Offers",
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

            Container(
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _scratchHeader(),
                        const SizedBox(height: 14),
                        _scratchRow(),
                        const SizedBox(height: 28),
                        _sectionTitle("Latest Offers"),
                        const SizedBox(height: 14),
                        _latestRow(),
                        const SizedBox(height: 28),
                        _sectionTitle("Limited Offer"),
                        const SizedBox(height: 14),
                        _limitedBlock(),
                        const SizedBox(height: 28),
                        _sectionTitle("Just for you"),
                        const SizedBox(height: 14),
                        _justForYouRow(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- SCRATCH & WIN ----------------
  Widget _scratchHeader() {
    final count = _unscratchedCards.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          Text(
            "Scratch & Win",
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.35,
              color: HexColor('#1B1D21'),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF155E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$count new",
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (scratchCards.isNotEmpty)
            GestureDetector(
              onTap: _openScratchCards,
              child: Text(
                "See all",
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: HexColor('#2369CF'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _scratchRow() {
    final cards = _unscratchedCards;
    if (cards.isEmpty) {
      return _emptyPlaceholder('Complete a ride to win scratch cards 🎁');
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _scratchCard(cards[i] as Map),
      ),
    );
  }

  Widget _scratchCard(Map c) {
    final expiresAt = DateTime.tryParse((c['expiresAt'] ?? '').toString());
    return GestureDetector(
      onTap: _openScratchCards,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [HexColor('#FFB800'), HexColor('#FF7A00')],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
            const Spacer(),
            Text(
              'Tap to Scratch',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'A surprise reward is waiting!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white70),
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Expires ${expiresAt.day}/${expiresAt.month}',
                style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Text(
          text,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.35,
            color: HexColor('#1B1D21'),
          ),
        ),
      );

  Widget _emptyPlaceholder(String msg) => Container(
        height: 90,
        margin: const EdgeInsets.symmetric(horizontal: 26),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg,
            style: GoogleFonts.dmSans(color: Colors.grey.shade600, fontSize: 13)),
      );

  Widget _offerImage(String url, double w, double h) {
    if (url.isEmpty) return const SizedBox.shrink();
    return Image.network(
      url,
      width: w,
      height: h,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  // ---------------- LATEST ----------------
  Widget _latestRow() {
    final list = _filter('latest');
    if (list.isEmpty) return _emptyPlaceholder('No latest offers right now');
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _latestCard(list[i] as Map, i),
      ),
    );
  }

  Widget _latestCard(Map o, int i) {
    final g = _latestGradients[i % _latestGradients.length];
    final img = (o['image'] ?? o['bannerImage'] ?? '').toString();
    final code = (o['code'] ?? '').toString();
    return GestureDetector(
      onTap: () => _onOfferTap(o),
      child: Container(
        width: 290,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (img.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _offerImage(img, 120, 100),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _discountText(o),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(o),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Code : ',
                            style: GoogleFonts.dmSans(
                                color: Colors.white, fontSize: 10)),
                        Text(code,
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- LIMITED ----------------
  Widget _limitedBlock() {
    final list = _filter('limited');
    if (list.isEmpty) return _emptyPlaceholder('No limited-time offers');
    final o = list.first as Map;
    final img = (o['image'] ?? o['bannerImage'] ?? '').toString();
    final code = (o['code'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: GestureDetector(
        onTap: () => _onOfferTap(o),
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF1E4B), Color(0xFFE11B2A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (img.isNotEmpty)
                Positioned(
                  right: -10,
                  top: 0,
                  bottom: 0,
                  child: _offerImage(img, 180, 170),
                ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('Limited Offer',
                              style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _discountText(o),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(o),
                      style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (code.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Code : ',
                              style: GoogleFonts.dmSans(
                                  color: Colors.white, fontSize: 10)),
                          Text(code,
                              style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                        ],
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

  // ---------------- JUST FOR YOU ----------------
  Widget _justForYouRow() {
    final list = _filter('just_for_you');
    if (list.isEmpty) return _emptyPlaceholder('Nothing personalised yet');
    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (_, i) => _justForYouCard(list[i] as Map, i),
      ),
    );
  }

  Widget _justForYouCard(Map o, int i) {
    final g = _jfyGradients[i % _jfyGradients.length];
    final img = (o['image'] ?? o['bannerImage'] ?? '').toString();
    return GestureDetector(
      onTap: () => _onOfferTap(o),
      child: Container(
        width: 124,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: img.isNotEmpty
                  ? ClipOval(
                      child: Image.network(img,
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.cleaning_services,
                              color: Colors.white,
                              size: 22)),
                    )
                  : const Icon(Icons.cleaning_services,
                      color: Colors.white, size: 22),
            ),
            Column(
              children: [
                Text(
                  (o['title'] ?? 'Service').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _discountText(o),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ORDER NOW',
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: -0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
