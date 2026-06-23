import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/BookARideModule/RideFindingScreen/ride_finding_screen.dart';
import 'package:kebu_customer/Services/payment_api_service.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Online-payment screen shown when the rider picks "UPI / Online" on the
/// booking screen. Mirrors the Figma "Payments" design: a list of preferred
/// modes + UPI apps with a single "Confirm & Pay" action. The ride is only
/// booked AFTER the payment is captured and verified, so whatever the user
/// pays drives the ride.
class RidePaymentScreen extends StatefulWidget {
  /// Ride fare to charge (in rupees).
  final double amount;

  const RidePaymentScreen({super.key, required this.amount});

  @override
  State<RidePaymentScreen> createState() => _RidePaymentScreenState();
}

class _PayMethod {
  final String key;
  final String name;
  final String asset;
  final String? subtitle;
  final String? badge;

  /// Razorpay checkout method to pre-select (upi / wallet / card).
  final String razorpayMethod;

  const _PayMethod({
    required this.key,
    required this.name,
    required this.asset,
    required this.razorpayMethod,
    this.subtitle,
    this.badge,
  });
}

class _RidePaymentScreenState extends State<RidePaymentScreen> {
  final BookingController _bc = Get.find<BookingController>();

  static final Color _kYellow = HexColor("#FFD546");

  static const List<_PayMethod> _preferred = [
    _PayMethod(
      key: 'gpay',
      name: 'Google Pay',
      asset: 'assets/payments/google_pay_icon.png',
      razorpayMethod: 'upi',
    ),
    _PayMethod(
      key: 'paytm',
      name: 'Paytm',
      asset: 'assets/payments/paytm_icon.png',
      razorpayMethod: 'wallet',
    ),
    _PayMethod(
      key: 'card',
      name: '•••• 9999',
      asset: 'assets/payments/mastercard_icon.png',
      razorpayMethod: 'card',
      badge: 'Secured',
    ),
  ];

  static const List<_PayMethod> _upi = [
    _PayMethod(
      key: 'phonepe',
      name: 'PhonePe UPI',
      asset: 'assets/payments/phone_pay.png',
      razorpayMethod: 'upi',
      subtitle: 'Low success rate currently',
    ),
    _PayMethod(
      key: 'mobikwik',
      name: 'Mobikwik',
      asset: 'assets/payments/mobikwik_icon.png',
      razorpayMethod: 'wallet',
    ),
    _PayMethod(
      key: 'cred',
      name: 'CRED pay',
      asset: 'assets/payments/cred_pay.png',
      razorpayMethod: 'wallet',
    ),
  ];

  String _selectedKey = 'gpay';
  bool _processing = false;

  late final Razorpay _razorpay;
  String? _pendingOrderId;

  _PayMethod get _selected =>
      [..._preferred, ..._upi].firstWhere((m) => m.key == _selectedKey);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── Payment + booking flow ──────────────────────────────────────────────

  Future<void> _payAndBook() async {
    if (_processing) return;
    if (widget.amount <= 0) {
      Fluttertoast.showToast(msg: 'Invalid fare amount.');
      return;
    }

    setState(() => _processing = true);

    final orderRes = await PaymentApiService.createPaymentOrder(
      amount: widget.amount,
      type: 'BOOKING_PAYMENT',
    );

    if (!orderRes.success || orderRes.data == null) {
      if (!mounted) return;
      setState(() => _processing = false);
      Fluttertoast.showToast(
          msg: orderRes.message ?? 'Could not start payment. Try again.');
      return;
    }

    _pendingOrderId = orderRes.data['orderId']?.toString();
    final keyId = orderRes.data['keyId']?.toString();
    if (_pendingOrderId == null || keyId == null) {
      if (!mounted) return;
      setState(() => _processing = false);
      Fluttertoast.showToast(msg: 'Payment configuration missing.');
      return;
    }

    final contact = Prefs.mobile_number.trim();
    final options = {
      'key': keyId,
      'amount': (widget.amount * 100).round(),
      'name': 'Kebu',
      'description': 'Ride fare',
      'order_id': _pendingOrderId,
      'prefill': {if (contact.isNotEmpty) 'contact': contact},
      'method': _selected.razorpayMethod,
      'theme': {'color': '#FFD546'},
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      Fluttertoast.showToast(msg: 'Unable to open Razorpay: $e');
    }
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    // Payment captured → create the booking with the proof so the backend
    // marks it PAID after verifying the signature, then drive the ride.
    final booked = await _bc.createBooking(
      razorpayOrderId: response.orderId ?? _pendingOrderId,
      razorpayPaymentId: response.paymentId,
      razorpaySignature: response.signature,
    );
    _pendingOrderId = null;

    if (!mounted) return;
    setState(() => _processing = false);

    if (booked) {
      replaceRouteKeepingRoot(
        context,
        RideFindingScreen(bookingId: _bc.bookingId.value),
      );
    } else {
      Fluttertoast.showToast(
        msg: _bc.errorMessage.value.isNotEmpty
            ? _bc.errorMessage.value
            : 'Payment done but booking failed. Please contact support.',
      );
    }
  }

  void _handleError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _processing = false);
    final raw = response.message?.trim() ?? '';
    final junk = raw.isEmpty ||
        raw.toLowerCase() == 'undefined' ||
        raw.toLowerCase() == 'null';
    final msg = response.code == Razorpay.PAYMENT_CANCELLED
        ? 'Payment cancelled — ride not booked'
        : (junk ? 'Payment failed. Please try again.' : raw);
    Fluttertoast.showToast(msg: msg);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Fluttertoast.showToast(
        msg: 'External wallet: ${response.walletName ?? 'Wallet'}');
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: _kYellow,
      bottomNavigationBar: _confirmBar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(19, 26, 19, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Preferred Mode'),
                      const SizedBox(height: 12),
                      _card(_preferred),
                      const SizedBox(height: 24),
                      _sectionTitle('UPI'),
                      const SizedBox(height: 12),
                      _card(_upi),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Payments',
            style: GoogleFonts.inter(
              color: const Color(0xFF2D3134),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const NotificationIconButton(height: 33),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.25,
          color: Colors.black,
        ),
      );

  Widget _card(List<_PayMethod> methods) {
    final children = <Widget>[];
    for (var i = 0; i < methods.length; i++) {
      children.add(_methodTile(methods[i]));
      if (i != methods.length - 1) {
        children.add(Divider(height: 1, thickness: 1, color: HexColor("#ECECEC")));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _methodTile(_PayMethod m) {
    final selected = _selectedKey == m.key;
    return InkWell(
      onTap: () => setState(() => _selectedKey = m.key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                _iconBox(Image.asset(m.asset,
                    width: 28, height: 28, fit: BoxFit.contain)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(m.name,
                                style: GoogleFonts.montserrat(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                          if (m.badge != null) ...[
                            const SizedBox(width: 8),
                            _securedBadge(m.badge!),
                          ],
                        ],
                      ),
                      if (m.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(m.subtitle!,
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.black)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _selector(selected),
              ],
            ),
            // Selected preferred mode expands into a quick "Pay using X" button,
            // matching the Figma design.
            if (selected)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: GestureDetector(
                  onTap: _processing ? null : _payAndBook,
                  child: Container(
                    height: 47,
                    decoration: BoxDecoration(
                      color: _kYellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Pay using ${m.name}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D3134),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(Widget child) => Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(color: HexColor("#CAC7C7"), width: 0.6),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: child,
      );

  Widget _selector(bool selected) {
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: _kYellow, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 15, color: Colors.white),
      );
    }
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HexColor("#CAC7C7"), width: 1.4),
      ),
    );
  }

  Widget _securedBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 9, color: _kYellow),
          const SizedBox(width: 3),
          Text(text,
              style: GoogleFonts.montserrat(
                  fontSize: 9, fontWeight: FontWeight.w600, color: _kYellow)),
        ],
      ),
    );
  }

  Widget _confirmBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GestureDetector(
          onTap: _processing ? null : _payAndBook,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: _kYellow,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: _processing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : Text(
                    'Confirm & Pay  ₹${widget.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black,
                      letterSpacing: -0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
