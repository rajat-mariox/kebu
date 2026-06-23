import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/TipScreen/tip_screen.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';

/// Driver rating + fare breakdown (Figma node 1:2458). Driver photo/name,
/// vehicle, payment method and the full fare breakdown come from the booking;
/// the rating is submitted to the backend via rateBooking.
class DriverRatingScreen extends StatefulWidget {
  final String? bookingId;
  const DriverRatingScreen({super.key, this.bookingId});

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  static final Color _yellow = HexColor('#FFD546');

  int userRating = 0;
  String driverPhoto = '';
  String vehicleName = '';
  String paymentMethodLabel = '';
  double tripFare = 0;
  double discount = 0;
  double totalPaid = 0;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    if (widget.bookingId == null) return;
    final response =
        await BookingApiService.getBookingDetails(widget.bookingId!);
    if (!mounted || !response.success || response.data == null) return;
    final booking = response.data['booking'] ?? response.data;
    setState(() {
      final driver = booking['driverId'];
      driverPhoto =
          (driver is Map ? driver['profileImage'] : null)?.toString() ?? '';
      final vType = booking['vehicleTypeId'];
      vehicleName =
          (vType is Map ? vType['name'] : null)?.toString() ?? 'Kebu Ride';
      paymentMethodLabel =
          _humanizeMethod((booking['paymentMethod'] ?? 'CASH').toString());
      tripFare = (booking['fare'] ?? 0).toDouble();
      discount = ((booking['discount'] ?? 0).toDouble()) +
          ((booking['subscriptionDiscount'] ?? 0).toDouble()) +
          ((booking['promoDiscount'] ?? 0).toDouble());
      totalPaid = (booking['finalFare'] ?? 0).toDouble();
      userRating = (booking['rating'] as num?)?.round() ?? 0;
    });
  }

  String _humanizeMethod(String m) {
    switch (m.toUpperCase()) {
      case 'WALLET':
        return 'Kebu Wallet';
      case 'CASH':
        return 'Cash';
      case 'CARD':
        return 'Card';
      case 'UPI':
        return 'UPI';
      default:
        return m;
    }
  }

  int get _discountPct =>
      tripFare > 0 ? (discount / tripFare * 100).round() : 0;

  Future<void> _submitAndContinue() async {
    if (widget.bookingId != null && userRating > 0) {
      await BookingApiService.rateBooking(widget.bookingId!,
          rating: userRating, feedback: '');
    }
    if (mounted) {
      pushTo(context,
          TipScreen(bookingId: widget.bookingId, rating: userRating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _yellow,
      bottomNavigationBar: _doneButton(),
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
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: Column(
                  children: [
                    _avatar(),
                    const SizedBox(height: 20),
                    Text('How was the driver?',
                        style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Colors.black)),
                    const SizedBox(height: 10),
                    Text('Help Kebu do better by rating this trip',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.4))),
                    const SizedBox(height: 28),
                    _stars(),
                    const SizedBox(height: 28),
                    _card(rows: [
                      _row('Ride',
                          vehicleName.isNotEmpty ? vehicleName : 'Kebu Ride'),
                      _row('Payment',
                          paymentMethodLabel.isNotEmpty
                              ? paymentMethodLabel
                              : 'Cash'),
                    ]),
                    const SizedBox(height: 16),
                    _card(rows: [
                      _row('Trip Fare', '₹ ${tripFare.toStringAsFixed(2)}'),
                      _row(
                          _discountPct > 0
                              ? 'Discounts ($_discountPct%)'
                              : 'Discounts',
                          '-${discount.toStringAsFixed(2)}'),
                      const Divider(height: 24, thickness: 1),
                      _row('Total Paid', '₹${totalPaid.toStringAsFixed(2)}',
                          bold: true),
                    ]),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HexColor('#F0F0F0'),
        image: hasPhoto
            ? DecorationImage(
                image: NetworkImage(driverPhoto), fit: BoxFit.cover)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? null
          : Image.asset('assets/driver_icon.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person, size: 50, color: Colors.grey.shade400)),
    );
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < userRating;
        return GestureDetector(
          onTap: () => setState(() => userRating = i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? _yellow : Colors.grey.shade400,
              size: 44,
            ),
          ),
        );
      }),
    );
  }

  Widget _card({required List<Widget> rows}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0 && rows[i] is! Divider) const SizedBox(height: 12),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(String left, String right, {bool bold = false}) {
    final style = GoogleFonts.poppins(
        fontSize: 14,
        color: HexColor('#252524'),
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: style),
        Text(right, style: style),
      ],
    );
  }

  Widget _doneButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _submitAndContinue,
          child: Container(
            height: 48,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _yellow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Done',
                style: GoogleFonts.poppins(
                    color: HexColor('#3C4043'),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
