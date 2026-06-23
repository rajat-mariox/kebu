import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/book_a_ride_appbar.dart';
import 'package:kebu_customer/CommonWidgets/button_widget.dart';
import 'package:kebu_customer/Screens/BookARideModule/PaymentSuccessScreen/payment_success_screen.dart';
import 'package:kebu_customer/Services/payment_api_service.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final String? keyId;
  final String? orderId;
  final double? amount;
  final String paymentType;
  final String? referenceId;
  final String? userName;
  final String? email;
  final String? contact;

  /// The method the user picked on the previous screen (e.g. "Google Pay",
  /// "Paytm", "•••• 9999"). Used to pre-select the method on Razorpay checkout.
  final String? preferredMethod;

  const PaymentCheckoutScreen({
    super.key,
    this.keyId,
    this.orderId,
    this.amount,
    this.paymentType = 'BOOKING_PAYMENT',
    this.referenceId,
    this.userName,
    this.email,
    this.contact,
    this.preferredMethod,
  });

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late final Razorpay _razorpay;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  /// Map a UI method label to a Razorpay checkout method type so the gateway
  /// opens pre-selected on it (upi / card / wallet / netbanking).
  String? _razorpayMethod(String? uiMethod) {
    if (uiMethod == null) return null;
    final m = uiMethod.toLowerCase();
    if (m.contains('upi') ||
        m.contains('google pay') ||
        m.contains('gpay') ||
        m.contains('phonepe')) {
      return 'upi';
    }
    if (m.contains('paytm') ||
        m.contains('mobikwik') ||
        m.contains('cred') ||
        m.contains('wallet')) {
      return 'wallet';
    }
    if (m.contains('card') ||
        m.contains('•') ||
        m.contains('mastercard') ||
        m.contains('visa') ||
        RegExp(r'\d{4}').hasMatch(m)) {
      return 'card';
    }
    if (m.contains('netbank') || m.contains('bank')) return 'netbanking';
    return null;
  }

  Future<void> _openCheckout() async {
    if (widget.keyId == null || widget.orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment order is missing')),
      );
      return;
    }

    setState(() => isProcessing = true);

    final amountPaise = ((widget.amount ?? 0) * 100).round();

    // Fall back to the logged-in user's stored mobile so Razorpay's checkout
    // does not prompt for contact details every time. Razorpay treats an empty
    // string as "ask the user", so only set the field when we actually have it.
    final prefillContact = (widget.contact?.trim().isNotEmpty ?? false)
        ? widget.contact!.trim()
        : Prefs.mobile_number.trim();

    final prefill = <String, dynamic>{};
    if (prefillContact.isNotEmpty) prefill['contact'] = prefillContact;
    if ((widget.email ?? '').isNotEmpty) prefill['email'] = widget.email;
    if ((widget.userName ?? '').isNotEmpty) prefill['name'] = widget.userName;

    // Pre-select the method the user chose on the previous screen so Razorpay
    // opens directly on it instead of the full method list.
    final method = _razorpayMethod(widget.preferredMethod);
    if (method != null) prefill['method'] = method;

    final options = {
      'key': widget.keyId,
      'amount': amountPaise,
      'name': 'Kebu',
      'description': 'Kebu payment',
      'order_id': widget.orderId,
      'prefill': prefill,
      'theme': {
        'color': '#FF3B59',
      },
      'retry': {
        'enabled': true,
        'max_count': 1,
      },
      'send_sms_hash': true,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open Razorpay: $e')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final razorpayOrderId = response.orderId ?? widget.orderId ?? '';
    final razorpayPaymentId = response.paymentId ?? '';
    final razorpaySignature = response.signature ?? '';

    final verifyResponse = await PaymentApiService.verifyPayment(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      type: widget.paymentType,
      referenceId: widget.referenceId,
      amount: widget.amount,
    );

    if (!mounted) return;
    setState(() => isProcessing = false);

    if (verifyResponse.success) {
      pushTo(
        context,
        PaymentSuccessScreen(
          amount: widget.amount ?? 0,
          orderId: razorpayPaymentId,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verifyResponse.message ?? 'Payment verification failed',
          ),
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => isProcessing = false);

    // razorpay_flutter sends the cancellation code as PAYMENT_CANCELLED.
    // It also occasionally serializes the message as the literal string
    // "undefined" / "null" when the native error has no description, which
    // would otherwise be shown to the user verbatim — strip those.
    final raw = response.message?.trim() ?? '';
    final isJunkMessage =
        raw.isEmpty || raw.toLowerCase() == 'undefined' || raw.toLowerCase() == 'null';

    final String shown;
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      shown = 'Payment cancelled';
    } else if (isJunkMessage) {
      shown = 'Payment failed. Please try again.';
    } else {
      shown = raw;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(shown)),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName ?? 'Wallet'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          bookARideAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 15, right: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        SizedBox(width: 5),
                        Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
                        SizedBox(width: 3),
                        Text(
                          "Checkout",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Image.asset("assets/ride_notification_icon.png", height: 28),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 110),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: HexColor("#FFD546"), width: 3),
                      ),
                      child: const Icon(Icons.payments_outlined, size: 38),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Center(
                    child: Text(
                      'Razorpay Checkout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Complete your payment securely using Razorpay.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _infoRow('Amount', 'Rs ${(widget.amount ?? 0).toStringAsFixed(2)}'),
                  _infoRow('Order ID', widget.orderId ?? '-'),
                  _infoRow('Payment Type', widget.paymentType),
                  if ((widget.referenceId ?? '').isNotEmpty)
                    _infoRow('Reference', widget.referenceId!),
                  const Spacer(),
                  ButtonWidget(
                    height: 52,
                    backgroundColor: HexColor("#FFD546"),
                    linearGradient: LinearGradient(
                      colors: [HexColor("#FFD546"), HexColor("#FFD546")],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    text: isProcessing ? "Processing..." : "Pay with Razorpay",
                    onTap: isProcessing ? () {} : _openCheckout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
