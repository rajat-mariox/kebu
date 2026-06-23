import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/FeedbackThanksScreen/feed_back_thanks_screen.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';

/// Tip screen (Figma node 1:2473). Driver photo + star count come from the
/// booking; the tip is charged via the backend (POST /customer/tip).
class TipScreen extends StatefulWidget {
  final String? bookingId;
  final int? rating;
  const TipScreen({super.key, this.bookingId, this.rating});

  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  static final Color _yellow = HexColor('#FFD546');

  double? selectedAmount;
  final List<double> tipAmounts = [10, 20, 30, 50, 75, 100, 150, 200, 250];
  bool isSendingTip = false;

  String driverPhoto = '';
  int rating = 0;

  @override
  void initState() {
    super.initState();
    rating = widget.rating ?? 0;
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    if (widget.bookingId == null) return;
    final res = await BookingApiService.getBookingDetails(widget.bookingId!);
    if (!mounted || !res.success || res.data == null) return;
    final booking = res.data['booking'] ?? res.data;
    setState(() {
      final driver = booking['driverId'];
      driverPhoto =
          (driver is Map ? driver['profileImage'] : null)?.toString() ?? '';
      rating = widget.rating ?? (booking['rating'] as num?)?.round() ?? rating;
    });
  }

  Future<void> _payTip() async {
    if (selectedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tip amount')),
      );
      return;
    }
    if (widget.bookingId != null) {
      setState(() => isSendingTip = true);
      await CustomerFeaturesApiService.addTip(
          bookingId: widget.bookingId!, amount: selectedAmount!);
      if (!mounted) return;
      setState(() => isSendingTip = false);
    }
    if (mounted) pushTo(context, const FeedBackThanksScreen());
  }

  void _skip() => pushTo(context, const FeedBackThanksScreen());

  Future<void> _customAmount() async {
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Enter Custom Amount', style: GoogleFonts.poppins()),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter amount in ₹',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value != null && value > 0) setState(() => selectedAmount = value);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _yellow,
      bottomNavigationBar: _bottomBar(),
      body: Column(
        children: [
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  children: [
                    _avatar(),
                    const SizedBox(height: 18),
                    Text(rating > 0 ? 'Wow $rating Stars!' : 'Add a tip?',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black)),
                    const SizedBox(height: 10),
                    Text(
                        "Would you like to add a tip to make your driver's day?",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.4))),
                    const SizedBox(height: 24),
                    _tipGrid(),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _customAmount,
                      child: Text('Enter custom amount',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: HexColor('#015EA3'))),
                    ),
                    const SizedBox(height: 18),
                    Divider(color: HexColor('#EDEDED'), thickness: 1),
                    const SizedBox(height: 16),
                    Text(
                        'Tip will be charged from your Kebu Wallet.\n100% of the tip goes to drivers.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.5))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final hasPhoto = driverPhoto.startsWith('http');
    return Container(
      width: 110,
      height: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HexColor('#F0F0F0'),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(driverPhoto), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Image.asset('assets/driver_icon.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person, size: 50, color: Colors.grey.shade400)),
    );
  }

  Widget _tipGrid() {
    return Column(
      children: [
        for (var i = 0; i < tipAmounts.length; i += 3) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: i + c < tipAmounts.length
                      ? _tipChip(tipAmounts[i + c])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _tipChip(double amount) {
    final selected = selectedAmount == amount;
    return GestureDetector(
      onTap: () => setState(() => selectedAmount = amount),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _yellow : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: selected ? _yellow : HexColor('#E4E4E4')),
        ),
        child: Text('₹ ${amount.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(
                fontSize: 15,
                color: HexColor('#252524'),
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HexColor('#FFF9E3'),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _yellow),
                  ),
                  child: Text('Skip',
                      style: GoogleFonts.poppins(
                          color: HexColor('#3C4043'), fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: isSendingTip ? null : _payTip,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isSendingTip ? 'Paying…' : 'Pay Tip',
                      style: GoogleFonts.poppins(
                          color: HexColor('#3C4043'), fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
