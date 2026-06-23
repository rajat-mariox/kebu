import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/DriverRatingScreen/driver_rating_screen.dart';
import 'package:kebu_customer/Services/payment_api_service.dart';

/// Payment-success receipt (Figma node 1:2392). Receipt details are fetched
/// from the backend (which proxies Razorpay's payment record), so ref number,
/// time, method, amount and payer are all live — no hardcoded data.
class PaymentSuccessScreen extends StatefulWidget {
  final double? amount;
  final String? orderId; // razorpay payment id (pay_xxx)
  final String? bookingId;
  const PaymentSuccessScreen(
      {super.key, this.amount, this.orderId, this.bookingId});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  static final Color _yellow = HexColor('#FFD546');

  String refNumber = '—';
  String paymentTime = '—';
  String paymentMethod = '—';
  String senderName = '—';
  double? amount;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    amount = widget.amount;
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      refNumber = widget.orderId!;
      _loadPaymentDetails();
    } else {
      isLoading = false;
    }
  }

  Future<void> _loadPaymentDetails() async {
    final response = await PaymentApiService.getPaymentDetails(widget.orderId!);
    if (!mounted) return;
    if (response.success && response.data != null) {
      // Backend returns the Razorpay payment object under `payment`.
      final p = (response.data['payment'] ?? response.data) as Map;
      setState(() {
        refNumber = (p['id'] ?? widget.orderId ?? '—').toString();
        final createdAt = p['created_at'];
        if (createdAt is num) {
          paymentTime = DateFormat('d MMM yyyy, HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(createdAt.toInt() * 1000));
        }
        paymentMethod = _humanizeMethod((p['method'] ?? '').toString());
        final card = p['card'];
        senderName = (card is Map ? card['name'] : null)?.toString() ??
            p['vpa']?.toString() ??
            p['email']?.toString() ??
            p['contact']?.toString() ??
            '—';
        final amt = p['amount'];
        if (amt is num) amount = amt / 100.0;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  String _humanizeMethod(String m) {
    switch (m.toLowerCase()) {
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      case 'emi':
        return 'EMI';
      case '':
        return '—';
      default:
        return '${m[0].toUpperCase()}${m.substring(1)}';
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
                padding: const EdgeInsets.fromLTRB(29, 60, 29, 24),
                child: _receiptCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        PhysicalShape(
          clipper: _ReceiptClipper(),
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Payment Success!',
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: HexColor('#121212'))),
                const SizedBox(height: 6),
                Text('Your payment has been successfully done.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: HexColor('#474747'))),
                const SizedBox(height: 24),
                Divider(color: HexColor('#EDEDED'), thickness: 1, height: 1),
                const SizedBox(height: 24),
                Text('Total Payment',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: HexColor('#474747'))),
                const SizedBox(height: 6),
                Text('₹ ${amount != null ? amount!.toStringAsFixed(0) : '—'}',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: HexColor('#121212'))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _detail('Ref Number', refNumber)),
                    const SizedBox(width: 12),
                    Expanded(child: _detail('Payment Time', paymentTime)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _detail('Payment Method', paymentMethod)),
                    const SizedBox(width: 12),
                    Expanded(child: _detail('Sender Name', senderName)),
                  ],
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('PDF receipt will be available soon')),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_outlined,
                          size: 22, color: HexColor('#3D3D3D')),
                      const SizedBox(width: 8),
                      Text('Get PDF Receipt',
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: HexColor('#3D3D3D'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Overlapping green tick badge
        const Positioned(
          top: -28,
          child: _SuccessBadge(),
        ),
        if (isLoading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _detail(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: HexColor('#EDEDED')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: HexColor('#707070'))),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HexColor('#121212'))),
        ],
      ),
    );
  }

  Widget _doneButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () =>
              pushTo(context, DriverRatingScreen(bookingId: widget.bookingId)),
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

/// White circle with a green tick — overlaps the top of the receipt.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HexColor('#54B26E'),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 22),
      ),
    );
  }
}

/// Receipt shape: rounded top corners + scalloped (ticket) bottom edge.
class _ReceiptClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double topR = 12;
    const double notch = 8; // scallop radius
    final path = Path();
    path.moveTo(0, topR);
    path.quadraticBezierTo(0, 0, topR, 0);
    path.lineTo(size.width - topR, 0);
    path.quadraticBezierTo(size.width, 0, size.width, topR);
    path.lineTo(size.width, size.height - notch);

    final int count = (size.width / (notch * 2)).floor();
    for (int i = count - 1; i >= 0; i--) {
      final double cx = notch + i * notch * 2;
      // semicircle dipping upward into the card → scalloped edge
      path.arcToPoint(
        Offset(cx - notch, size.height - notch),
        radius: const Radius.circular(notch),
        clockwise: true,
      );
    }
    path.lineTo(0, topR);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
