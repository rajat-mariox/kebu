import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/PaymentScreen/payment_screen.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';

/// Completed-ride summary (Figma node 1:2191). Fare, duration, CO₂ (from
/// distance), drop and subscription savings come from the booking; the rating
/// + quick-feedback tags are submitted to the backend via rateBooking.
class DestinationSummeryScreen extends StatefulWidget {
  final String? bookingId;
  const DestinationSummeryScreen({super.key, this.bookingId});

  @override
  State<DestinationSummeryScreen> createState() =>
      _DestinationSummeryScreenState();
}

class _DestinationSummeryScreenState extends State<DestinationSummeryScreen> {
  static final Color _yellow = HexColor('#FFD546');
  static final Color _ink = HexColor('#212020');

  String totalFare = '--';
  double fareAmount = 0; // numeric fare, passed to the payment screen
  String duration = '--';
  String dropAddress = '';
  String co2Saved = '0';
  int metroPointsEarned = 0;
  int? metroPointsTotal; // backend-driven if/when available
  double subscriptionDiscount = 0;
  String subscriptionPlanName = '';
  bool isLoading = true;

  // Payment state — for cash rides (or anything already PAID) there is
  // nothing to pay online, so the bottom action becomes a "Done" that wraps
  // up the ride instead of opening the payment screen.
  String paymentMethod = 'CASH';
  String paymentStatus = 'PENDING';

  // Rating + quick feedback (submitted to the backend).
  int rating = 0;
  final Set<String> selectedTags = {};
  bool _submitting = false;
  static const _tags = ['Driver polite', 'Bike fast', 'Time saved'];

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    if (widget.bookingId == null) {
      setState(() => isLoading = false);
      return;
    }
    final response =
        await BookingApiService.getBookingDetails(widget.bookingId!);
    if (!mounted) return;
    if (response.success && response.data != null) {
      final booking = response.data['booking'] ?? response.data;
      setState(() {
        final fare = (booking['finalFare'] ?? booking['fare'] ?? 0);
        totalFare = '${_asNum(fare)}';
        fareAmount = (fare as num).toDouble();
        final mins = booking['durationMin'] ?? booking['duration'] ?? 0;
        duration = '${_asNum(mins)} mins';
        final drop = booking['drop'] ?? booking['dropLocation'] ?? {};
        dropAddress = (drop is Map ? drop['address'] : null)?.toString() ?? '';
        final distKm = (booking['distanceKm'] ?? 0).toDouble();
        co2Saved = (distKm * 0.12).toStringAsFixed(1); // ~0.12 kg CO₂/km saved
        // MetroPoints has no dedicated backend yet — use the field if the
        // backend ever sends it, else derive earned from the fare.
        metroPointsEarned = (booking['metroPointsEarned'] as num?)?.round() ??
            ((fare as num).toDouble() * 0.1).round();
        final bal = booking['metroPointsBalance'] ?? booking['metroPoints'];
        metroPointsTotal = bal is num ? bal.round() : null;
        subscriptionDiscount =
            (booking['subscriptionDiscount'] ?? 0).toDouble();
        subscriptionPlanName =
            booking['subscriptionPlanName']?.toString() ?? '';
        rating = (booking['rating'] as num?)?.round() ?? 0;
        paymentMethod =
            (booking['paymentMethod'] ?? 'CASH').toString().toUpperCase();
        paymentStatus =
            (booking['paymentStatus'] ?? 'PENDING').toString().toUpperCase();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  num _asNum(dynamic v) {
    if (v is num) return v == v.roundToDouble() ? v.toInt() : v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// True when the fare is settled in cash (collected by the driver in
  /// person) or already marked PAID — i.e. no online payment is due.
  bool get _isCashOrPaid =>
      paymentMethod == 'CASH' || paymentStatus == 'PAID';

  Future<void> _submitRating() async {
    if (widget.bookingId == null || rating == 0 || _submitting) return;
    _submitting = true;
    final res = await BookingApiService.rateBooking(
      widget.bookingId!,
      rating: rating,
      feedback: selectedTags.isEmpty ? null : selectedTags.join(', '),
    );
    _submitting = false;
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
    }
  }

  /// Wrap up a settled (cash/paid) ride: submit any rating the customer
  /// gave, clear the active-booking state and return to the dashboard so the
  /// ride is fully closed out on the customer side.
  Future<void> _finishRide() async {
    if (rating > 0) await _submitRating();
    if (!mounted) return;
    try {
      Get.find<BookingController>().resetBooking();
    } catch (_) {
      // Controller may not be registered if reached cold — safe to ignore.
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
    ));
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _yellow,
      bottomNavigationBar: _bottomBar(),
      body: Column(
        children: [
          // Yellow header
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 10, 12, 14),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios,
                      size: 20, color: Colors.black),
                ),
                const SizedBox(width: 6),
                Text('Completed Ride',
                    style: GoogleFonts.inter(
                        color: HexColor('#2D3134'),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const NotificationIconButton(height: 30),
              ],
            ),
          ),
          // White sheet
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
                      child: Column(
                        children: [
                          _successIcon(),
                          const SizedBox(height: 16),
                          Text("You've reached your destination!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: HexColor('#121212'))),
                          const SizedBox(height: 6),
                          Text(
                            dropAddress.isNotEmpty
                                ? dropAddress
                                : 'Your destination',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: HexColor('#474747')),
                          ),
                          const SizedBox(height: 24),
                          _fareCard(),
                          const SizedBox(height: 16),
                          _metroCard(),
                          const SizedBox(height: 24),
                          _stars(),
                          const SizedBox(height: 18),
                          _tagsRow(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successIcon() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: HexColor('#E7F2DD'),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_circle_rounded,
          size: 40, color: HexColor('#7AB648')),
    );
  }

  Widget _fareCard() {
    return _card(
      child: Column(
        children: [
          Text('Total : $totalFare      |      $duration',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: _ink)),
          if (subscriptionDiscount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: HexColor('#4CAF50').withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 14, color: HexColor('#2E7D32')),
                  const SizedBox(width: 6),
                  Text(
                    '${subscriptionPlanName.isNotEmpty ? subscriptionPlanName : 'Kebu Pass'} saved you ₹${subscriptionDiscount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: HexColor('#2E7D32')),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'You saved $co2Saved kg CO₂ compared to taking only a cab. Great choice for a greener planet!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: _ink, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _metroCard() {
    return _card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.card_giftcard, color: _ink, size: 20),
              const SizedBox(width: 8),
              Text('You earned +$metroPointsEarned MetroPoints',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600, color: _ink)),
            ],
          ),
          if (metroPointsTotal != null) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: GoogleFonts.poppins(fontSize: 14, color: _ink),
                children: [
                  const TextSpan(text: 'Total : '),
                  TextSpan(
                    text: '$metroPointsTotal MetroPoints',
                    style: TextStyle(color: HexColor('#015EA3')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: () {
            setState(() => rating = i + 1);
            _submitRating();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? _yellow : Colors.grey.shade400,
              size: 40,
            ),
          ),
        );
      }),
    );
  }

  Widget _tagsRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: _tags.map((t) {
        final sel = selectedTags.contains(t);
        return GestureDetector(
          onTap: () {
            setState(() => sel ? selectedTags.remove(t) : selectedTags.add(t));
            _submitRating();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? _yellow.withOpacity(0.25) : HexColor('#F4F4F4'),
              borderRadius: BorderRadius.circular(7),
              border: sel ? Border.all(color: _yellow) : null,
            ),
            child: Text(t,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: HexColor('#2D3134'))),
          ),
        );
      }).toList(),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 0)),
        ],
      ),
      child: child,
    );
  }

  Widget _bottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // For cash rides (driver collects in person) or anything already
            // PAID there's nothing to pay online — the action finishes the
            // ride (submits any rating, then returns Home). Otherwise it opens
            // the payment screen.
            GestureDetector(
              onTap: _isCashOrPaid
                  ? _finishRide
                  : () => pushTo(
                      context,
                      PaymentScreen(
                        bookingId: widget.bookingId,
                        amount: fareAmount > 0 ? fareAmount : null,
                      )),
              child: Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _yellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_isCashOrPaid ? 'Done' : 'Pay',
                    style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 16,
                        letterSpacing: -0.4)),
              ),
            ),
            const SizedBox(height: 12),
            // Download Invoice
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invoice will be available soon')),
              ),
              child: Container(
                height: 56,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _yellow),
                ),
                child: Text('Download Invoice',
                    style: GoogleFonts.poppins(
                        color: _yellow, fontSize: 16, letterSpacing: -0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
