import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/BookARideModule/PaymentScreen/payment_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/CleaningOrderPlaced/cleaning_order_placed.dart';
import 'package:kebu_customer/Screens/CleaningModule/ServiceWaitingScreen/service_waiting_screen.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/wallet_api_service.dart';

class CleaningReviewBookingScreen extends StatefulWidget {
  const CleaningReviewBookingScreen({super.key});
  @override
  State<CleaningReviewBookingScreen> createState() =>
      _CleaningReviewBookingScreenState();
}

class _CleaningReviewBookingScreenState
    extends State<CleaningReviewBookingScreen> {
  // ===== Design tokens (Figma node 777:33740) =====
  static final Color _pink = HexColor('#E61978');
  static final Color _purple = HexColor('#461E98');
  static final Color _accent = HexColor('#D50069');
  static final Color _ink = HexColor('#161938');
  static final Color _sub = HexColor('#4E4E4E');

  final controller = Get.find<HouseholdBookingController>();
  final TextEditingController _promoController = TextEditingController();

  static const double _taxRate = 0.18;

  double serviceCharge = 0;
  double taxes = 0;
  double discount = 0;
  double walletBalance = 0;
  bool redeemWallet = false;
  String? appliedPromoCode;
  List<dynamic> starterPacks = [];
  bool isLoading = true;

  /// Multiple booking = a date range was chosen; each day is one session.
  bool get _isMultiple => controller.endDate.value != null;
  int get _sessions {
    final s = controller.selectedDate.value;
    final e = controller.endDate.value;
    if (s == null || e == null) return 1;
    return e.difference(s).inDays + 1;
  }

  @override
  void initState() {
    super.initState();
    // Seed from the package the user picked on the previous screen so the
    // fare is correct even before the network calls return. For a multiple
    // booking the charge is per-session price × number of days.
    serviceCharge = controller.servicePrice.value * _sessions;
    taxes = (serviceCharge * _taxRate).roundToDouble();
    _loadBookingData();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingData() async {
    final pkgId = controller.packageId.value;
    final hasValidPackage = pkgId.length == 24;
    final results = await Future.wait([
      HouseholdApiService.getStarterPacks(
          controller.categoryId.value.isNotEmpty
              ? controller.categoryId.value
              : 'default'),
      WalletApiService.getWallet(),
      if (hasValidPackage)
        HouseholdApiService.getBookingEstimate(
            packageId: pkgId, totalSessions: _sessions),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0].success && results[0].data != null) {
        // getStarterPacks returns { subscriptionPlans, starterOffers }.
        final d = results[0].data;
        starterPacks = (d['subscriptionPlans'] as List?) ??
            (d['starterOffers'] as List?) ??
            (d['starterPacks'] as List?) ??
            [];
      }
      if (results[1].success && results[1].data != null) {
        walletBalance = (results[1].data['balance'] ?? 0).toDouble();
      }
      // Authoritative fare from the backend estimate when we have a real
      // packageId; otherwise compute from the backend-sourced package price.
      if (hasValidPackage && results.length > 2 && results[2].success &&
          results[2].data != null) {
        final est = results[2].data;
        serviceCharge = (est['subtotal'] ?? serviceCharge).toDouble();
        taxes = (est['taxes'] ?? taxes).toDouble();
      } else {
        serviceCharge = controller.servicePrice.value * _sessions;
        taxes = (serviceCharge * _taxRate).roundToDouble();
      }
      isLoading = false;
    });
  }

  // ----- Fare maths -----
  double get _walletDeduction {
    if (!redeemWallet) return 0;
    final payable = serviceCharge + taxes - discount;
    return walletBalance < payable ? walletBalance : payable.clamp(0, payable);
  }

  double get _totalPayable =>
      (serviceCharge + taxes - discount - _walletDeduction)
          .clamp(0, double.infinity)
          .toDouble();

  String _money(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _applyPromo(String code) async {
    final subtotal = serviceCharge + taxes;
    final response = await CustomerFeaturesApiService.applyPromoCode(
      code: code,
      orderType: 'HOUSEHOLD',
      orderAmount: subtotal,
    );
    if (!mounted) return;
    if (response.success && response.data != null) {
      final offer = response.data['offer'];
      final offerDiscount = offer is Map ? offer['discount'] : null;
      final parsed =
          (offerDiscount ?? response.data['discount'] ?? 0).toDouble();
      if (parsed <= 0) {
        _toast('Promo code could not be applied');
        return;
      }
      setState(() {
        appliedPromoCode = code;
        discount = parsed;
      });
      _toast('Promo applied: -₹${_money(discount)}');
    } else {
      final raw = response.message ?? '';
      _toast(raw.isNotEmpty ? raw.replaceAll('_', ' ') : 'Invalid promo code');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final gradientH = topInset + 96;
    final cardTop = topInset + 80;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _bottomBar(),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: gradientH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_pink, _purple],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: cardTop),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _serviceCard(),
                  const SizedBox(height: 20),
                  _starterPackCard(),
                  const SizedBox(height: 20),
                  Text('Offers and Discounts',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: HexColor('#2A2A2A'))),
                  const SizedBox(height: 12),
                  _promoCard(),
                  const SizedBox(height: 16),
                  _walletCard(),
                  const SizedBox(height: 16),
                  _refundPolicyCard(),
                  const SizedBox(height: 20),
                  Text('Fare Summary',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: HexColor('#2A2A2A'))),
                  const SizedBox(height: 12),
                  _fareSummaryCard(),
                ],
              ),
            ),
            // Header row 1: back + title
            Positioned(
              top: topInset + 4,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('Review Booking',
                        style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4)),
                  ),
                ],
              ),
            ),
            // Header row 2: location line + "Change" (aligned together)
            Positioned(
              top: topInset + 42,
              left: 20,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/home.png',
                      width: 20,
                      height: 20,
                      color: Colors.white,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.home_outlined,
                          size: 20,
                          color: Colors.white)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _addressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: -0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Text('Change',
                          style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.4)),
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

  String get _addressLabel {
    final l = controller.addressLabel.value;
    if (l.isNotEmpty) return l;
    final a = controller.selectedAddress.value;
    return a.isNotEmpty ? a : 'Select address';
  }

  // ==================== SERVICE CARD ====================

  String _rangeStr(DateTime s, DateTime e) {
    final sameMonth = s.month == e.month && s.year == e.year;
    return sameMonth
        ? '${s.day}-${e.day} ${DateFormat('MMM').format(e)}'
        : '${DateFormat('d MMM').format(s)} - ${DateFormat('d MMM').format(e)}';
  }

  Widget _serviceCard() {
    final date = controller.selectedDate.value;
    final end = controller.endDate.value;
    final isMulti = _isMultiple;
    final dateLabel = isMulti ? 'Dates' : 'Date';
    final dateStr = isMulti && date != null && end != null
        ? _rangeStr(date, end)
        : (date != null ? DateFormat('d MMM, EEE').format(date) : '--');
    final startsAt = controller.selectedTimeSlot.value.isNotEmpty
        ? controller.selectedTimeSlot.value
        : '--';
    final duration = controller.selectedDuration.value.isNotEmpty
        ? controller.selectedDuration.value
        : (controller.packageName.value.isNotEmpty
            ? controller.packageName.value
            : '--');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: HexColor('#DA1A7B').withOpacity(0.03),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/family_expert.png',
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          width: 46,
                          height: 46,
                          color: _pink.withOpacity(0.1),
                          child: Icon(Icons.cleaning_services, color: _pink),
                        )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expert Service',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _ink)),
                    if (isMulti)
                      Text('$_sessions sessions',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: _sub)),
                  ],
                ),
              ),
              Text('₹${_money(serviceCharge)}',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          _dottedLine(),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _infoColumn(dateLabel, dateStr)),
                VerticalDivider(
                    width: 1, thickness: 1, color: HexColor('#E2E2E2')),
                const SizedBox(width: 12),
                Expanded(child: _infoColumn('Starts at', startsAt)),
                VerticalDivider(
                    width: 1, thickness: 1, color: HexColor('#E2E2E2')),
                const SizedBox(width: 12),
                Expanded(child: _infoColumn('Duration', duration)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(color: _sub, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500, fontSize: 14, color: _ink)),
      ],
    );
  }

  // ==================== STARTER PACK ====================

  Widget _starterPackCard() {
    const String title = 'Save more with STARTER PACK';
    String subtitle = 'Bundle bookings and save';
    if (starterPacks.isNotEmpty && starterPacks.first is Map) {
      final p = starterPacks.first as Map;
      final name = (p['name'] ?? p['title'] ?? '').toString();
      final price = p['price'] ?? p['amount'] ?? p['packPrice'];
      final benefits = p['benefits'];
      final disc = benefits is Map ? benefits['discountPercentage'] : null;
      final sessions = p['sessions'] ?? p['totalSessions'] ?? p['count'];
      if (sessions != null && price != null) {
        subtitle = '$sessions bookings for just ₹${_money(price as num)}';
      } else if (price != null) {
        subtitle = name.isNotEmpty
            ? '$name · ₹${_money(price as num)}'
            : '₹${_money(price as num)}'
                '${disc != null ? ' · save $disc%' : ''}';
      } else if (disc != null) {
        subtitle = 'Save $disc% on every booking';
      }
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: HexColor('#E9E9E9')),
        gradient: LinearGradient(
          colors: [HexColor('#FEFEF6'), HexColor('#FDF6AB')],
        ),
      ),
      child: Row(
        children: [
          Image.asset('assets/discount.png',
              width: 39,
              height: 39,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.card_giftcard, color: _accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: HexColor('#2B3233').withOpacity(0.5))),
              ],
            ),
          ),
          InkWell(
            onTap: () => _toast('Starter pack coming soon'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_pink, _purple],
                ),
              ),
              child: Text('Add',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PROMO ====================

  Widget _promoCard() {
    final applied = appliedPromoCode != null && appliedPromoCode!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: applied ? _removePromo : _openPromoSheet,
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accent),
          gradient: LinearGradient(
            colors: [
              HexColor('#FFE6F2').withOpacity(0.5),
              Colors.white.withOpacity(0.5)
            ],
          ),
        ),
        child: Row(
          children: [
            Image.asset('assets/discount.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.local_offer_outlined, color: _accent)),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  applied
                      ? 'Promo applied: $appliedPromoCode'
                      : 'Select a promo code',
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: applied
                          ? Colors.green.shade700
                          : HexColor('#2A2A2A')),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(applied ? 'Remove' : 'View Offers/Apply',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: HexColor('#D21A7C'))),
          ],
        ),
      ),
    );
  }

  void _removePromo() {
    setState(() {
      appliedPromoCode = null;
      discount = 0;
    });
    _promoController.clear();
  }

  void _openPromoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply promo code',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            TextField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter promo code',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final code = _promoController.text.trim();
                  Navigator.pop(ctx);
                  if (code.isNotEmpty) _applyPromo(code);
                },
                child: Text('Apply',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== WALLET ====================

  Widget _walletCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => redeemWallet = !redeemWallet),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 1.5,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: redeemWallet ? _accent : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: HexColor('#E9E9E9')),
              ),
              child: redeemWallet
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Redeem using wallet',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Credit Balance: ₹${_money(walletBalance)}',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: HexColor('#2B3233').withOpacity(0.5))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== REFUND POLICY ====================

  Widget _refundPolicyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 1.5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Refund & cancellation policy',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500, fontSize: 14, color: _ink)),
          const SizedBox(height: 8),
          Text(
              'Full refund if cancelled 30 min before scheduled time. Refund for partial cancellations shall be adjusted against discounts',
              style: GoogleFonts.poppins(
                  color: _sub, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  // ==================== FARE SUMMARY ====================

  Widget _fareSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 1.5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _fareRow('Service Charge', '₹${_money(serviceCharge)}'),
          const SizedBox(height: 10),
          _dottedLine(),
          const SizedBox(height: 10),
          _fareRow('Taxes', '₹${_money(taxes)}'),
          const SizedBox(height: 10),
          _dottedLine(),
          const SizedBox(height: 10),
          _fareRow(
            'Offer / Coupon',
            '-₹${_money(discount)}',
            valueColor: discount > 0 ? _accent : null,
            info: true,
          ),
          if (redeemWallet && _walletDeduction > 0) ...[
            const SizedBox(height: 10),
            _dottedLine(),
            const SizedBox(height: 10),
            _fareRow('Wallet', '-₹${_money(_walletDeduction)}',
                valueColor: _accent),
          ],
          const SizedBox(height: 10),
          _dottedLine(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Payable',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              Text('₹${_money(_totalPayable)}',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fareRow(String label, String value,
      {Color? valueColor, bool info = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.poppins(fontSize: 14, color: HexColor('#2B3233'))),
            if (info) ...[
              const SizedBox(width: 5),
              Tooltip(
                message:
                    'Use your discount coupons and avail the great deals.',
                child: Icon(Icons.info_outline, size: 14, color: _accent),
              ),
            ],
          ],
        ),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14,
                color: valueColor ?? HexColor('#2B3233'))),
      ],
    );
  }

  // ==================== BOTTOM BAR ====================

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Image.asset('assets/credit.png',
                      width: 34,
                      height: 34,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.account_balance_wallet_outlined,
                          color: _purple)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Payment Method',
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.black)),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: _choosePaymentMethod,
                        child: Row(
                          children: [
                            Text(_paymentLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black)),
                            const Icon(Icons.keyboard_arrow_down, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${_money(_totalPayable)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('View Breakup',
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: HexColor('#2C67F2'))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _paymentButton(),
            ],
          ),
        ),
      ),
    );
  }

  String get _paymentLabel =>
      controller.paymentMethod.value.toLowerCase() == 'cash'
          ? 'Cash'
          : 'Online';

  void _choosePaymentMethod() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in const ['Cash', 'Online'])
              ListTile(
                leading: Icon(
                    m == 'Cash'
                        ? Icons.payments_outlined
                        : Icons.credit_card,
                    color: _purple),
                title: Text(m, style: GoogleFonts.poppins(fontSize: 14)),
                trailing: _paymentLabel == m
                    ? Icon(Icons.check_circle, color: _accent)
                    : null,
                onTap: () {
                  controller.setPaymentMethod(m.toLowerCase());
                  Navigator.pop(ctx);
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _paymentButton() {
    return InkWell(
      onTap: _placeBooking,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pink, _purple],
          ),
        ),
        child: Text('Payment',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  String _isoDate(DateTime? d) => DateFormat('yyyy-MM-dd')
      .format(d ?? DateTime.now().add(const Duration(days: 1)));

  Future<void> _placeBooking() async {
    final categoryId = controller.categoryId.value.isNotEmpty
        ? controller.categoryId.value
        : 'default';
    final serviceType = controller.serviceType.value.isNotEmpty
        ? controller.serviceType.value
        : 'SINGLE';
    final timeSlot = controller.selectedTimeSlot.value.isNotEmpty
        ? controller.selectedTimeSlot.value
        : '10:00 AM - 12:00 PM';
    final addressMap = {
      'address': controller.selectedAddress.value,
      'lat': controller.selectedLat.value,
      'lng': controller.selectedLng.value,
    };
    final pkgId = controller.packageId.value;
    final isMultiple = controller.endDate.value != null;

    // Multiple booking (date range) → /services/booking/multiple;
    // single booking → /services/booking.
    final response = isMultiple
        ? await HouseholdApiService.createMultipleBooking(
            categoryId: categoryId,
            serviceType: serviceType,
            packageId: pkgId.length == 24 ? pkgId : null,
            bookingType: 'MULTIPLE',
            startDate: _isoDate(controller.selectedDate.value),
            endDate: _isoDate(controller.endDate.value),
            durationMinutes: controller.durationMinutes.value > 0
                ? controller.durationMinutes.value
                : null,
            timeSlot: timeSlot,
            address: addressMap,
            paymentMethod: controller.paymentMethod.value.toUpperCase(),
            promoCode: appliedPromoCode,
          )
        : await HouseholdApiService.createBooking(
            categoryId: categoryId,
            serviceType: serviceType,
            preferredDate: _isoDate(controller.selectedDate.value),
            preferredTimeSlot: timeSlot,
            address: addressMap,
            paymentMethod: controller.paymentMethod.value.toUpperCase(),
            estimatedCost: _totalPayable,
            promoCode: appliedPromoCode,
          );
    if (!mounted) return;
    if (!response.success) {
      _toast(response.message?.replaceAll('_', ' ') ?? 'Booking failed');
      return;
    }

    final booking = response.data is Map ? response.data['booking'] : null;
    final bookingId = (booking is Map ? booking['_id'] : null)?.toString();
    final isCash = controller.paymentMethod.value.toLowerCase() == 'cash';

    // Cash → wait (up to a minute) for a partner to accept, then confirm; if
    // none accepts it auto-cancels. Online → pay first (Razorpay). With no
    // booking id we can't track, so fall back to the plain confirmation.
    if (bookingId == null || bookingId.isEmpty) {
      pushTo(context, const CleaningOrderPlaced());
    } else if (isCash) {
      pushTo(context, ServiceWaitingScreen(bookingId: bookingId));
    } else {
      pushTo(
        context,
        PaymentScreen(
          bookingId: bookingId,
          amount: _totalPayable,
          paymentType: 'SERVICE_PAYMENT',
          title: 'Payment',
          confirmLabel: 'Confirm (₹${_money(_totalPayable)})',
          brandColors: [_pink, _purple],
          selectedAccent: HexColor('#3880F1'),
        ),
      );
    }
  }

  // ==================== SHARED ====================

  Widget _dottedLine() {
    return LayoutBuilder(
      builder: (context, c) {
        const dash = 4.0, gap = 4.0;
        final count = (c.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
                width: dash, height: 1, color: HexColor('#E2E2E2')),
          ),
        );
      },
    );
  }
}
