import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/app_bar.dart';
import 'package:kebu_customer/Services/customer_features_api_service.dart';
import 'package:kebu_customer/Services/payment_api_service.dart';
import 'package:kebu_customer/Utils/PrefsManager/prefs_manager.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class ManagePlanScreen extends StatefulWidget {
  const ManagePlanScreen({super.key});
  @override
  State<ManagePlanScreen> createState() => _ManagePlanScreenState();
}

class _ManagePlanScreenState extends State<ManagePlanScreen> {
  List<dynamic> plans = [];
  Map<String, dynamic>? activeSub;
  String? selectedPlanId;
  bool isLoading = true;
  bool isSubscribing = false;

  late final Razorpay _razorpay;
  String? _pendingOrderId;
  String? _pendingPlanId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    final plansRes = await CustomerFeaturesApiService.getSubscriptionPlans();
    final subRes = await CustomerFeaturesApiService.getMySubscription();

    if (mounted) {
      setState(() {
        if (plansRes.success && plansRes.data != null) {
          plans = plansRes.data['plans'] ?? plansRes.data ?? [];
        }
        if (subRes.success && subRes.data != null) {
          activeSub = subRes.data['subscription'] ?? subRes.data;
          if (activeSub != null && activeSub!['_id'] == null) activeSub = null;
        }
        if (plans.isNotEmpty && selectedPlanId == null) {
          selectedPlanId = plans.first['_id']?.toString();
        }
        isLoading = false;
      });
    }
  }

  Map<String, dynamic>? get selectedPlan {
    if (selectedPlanId == null) return null;
    return plans.firstWhere((p) => p['_id']?.toString() == selectedPlanId,
        orElse: () => null);
  }

  Future<void> _subscribe() async {
    final plan = selectedPlan;
    if (plan == null) return;

    final isTrialAvailable = plan['isTrialAvailable'] == true;

    if (isTrialAvailable) {
      setState(() => isSubscribing = true);
      final res = await CustomerFeaturesApiService.subscribeToPlan(
        planId: selectedPlanId!,
        isTrial: true,
      );
      if (mounted) {
        setState(() => isSubscribing = false);
        if (res.success) {
          _showSuccessDialog(plan, isTrial: true);
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? 'Failed to subscribe')),
          );
        }
      }
      return;
    }

    setState(() => isSubscribing = true);
    final price = (plan['price'] ?? 0).toDouble();

    final orderRes = await PaymentApiService.createPaymentOrder(
      amount: price,
      type: 'SERVICE_PAYMENT',
      referenceId: 'subscription_$selectedPlanId',
    );

    if (!mounted) return;

    if (orderRes.success && orderRes.data != null) {
      final orderId = orderRes.data['orderId'] ?? orderRes.data['order']?['id'];
      final keyId = orderRes.data['keyId'] ?? orderRes.data['key'];

      if (orderId != null && keyId != null) {
        _pendingOrderId = orderId;
        _pendingPlanId = selectedPlanId;

        final amountPaise = (price * 100).round();
        final prefill = <String, dynamic>{};
        final storedMobile = Prefs.mobile_number.trim();
        if (storedMobile.isNotEmpty) prefill['contact'] = storedMobile;

        final options = {
          'key': keyId,
          'amount': amountPaise,
          'name': 'Kebu',
          'description': '${plan['name']} Subscription',
          'order_id': orderId,
          'prefill': prefill,
          'theme': {'color': '#FF3B59'},
          'retry': {'enabled': true, 'max_count': 1},
        };

        try {
          _razorpay.open(options);
        } catch (e) {
          setState(() => isSubscribing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to open Razorpay: $e')),
          );
        }
      } else {
        setState(() => isSubscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid payment order response')),
        );
      }
    } else {
      setState(() => isSubscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(orderRes.message ?? 'Failed to create payment order')),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final razorpayOrderId = response.orderId ?? _pendingOrderId ?? '';
    final razorpayPaymentId = response.paymentId ?? '';
    final razorpaySignature = response.signature ?? '';

    final verifyRes = await PaymentApiService.verifyPayment(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      type: 'SERVICE_PAYMENT',
      referenceId: 'subscription_$_pendingPlanId',
      amount: selectedPlan != null ? (selectedPlan!['price'] ?? 0).toDouble() : 0,
    );

    if (!mounted) return;

    if (verifyRes.success) {
      final subRes = await CustomerFeaturesApiService.subscribeToPlan(
        planId: _pendingPlanId!,
        paymentId: razorpayPaymentId,
      );

      if (mounted) {
        setState(() => isSubscribing = false);
        if (subRes.success) {
          _showSuccessDialog(selectedPlan!, isTrial: false);
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(subRes.message ??
                    'Payment done but subscription failed. Contact support.')),
          );
        }
      }
    } else {
      setState(() => isSubscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment verification failed')),
      );
    }

    _pendingOrderId = null;
    _pendingPlanId = null;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => isSubscribing = false);
    _pendingOrderId = null;
    _pendingPlanId = null;

    final raw = response.message?.trim() ?? '';
    final isJunkMessage = raw.isEmpty ||
        raw.toLowerCase() == 'undefined' ||
        raw.toLowerCase() == 'null';

    final String shown;
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      shown = 'Payment cancelled';
    } else if (isJunkMessage) {
      shown = 'Payment failed. Please try again.';
    } else {
      shown = raw;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(shown)));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'External wallet selected: ${response.walletName ?? 'Wallet'}')),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> plan, {required bool isTrial}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text("Congratulations!",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text("You're now a Kebu One Pass Member",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [HexColor("#FFD546"), HexColor("#FF155E")]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text("KEBU ONE PASS",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "${plan['name']} – ${isTrial ? 'Trial' : 'Paid'}",
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HexColor("#FFD546"),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text("Start Exploring Benefits",
                    style: GoogleFonts.poppins(
                        color: Colors.black, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          commonAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 55, left: 12, right: 12),
              child: Row(
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
                    "Manage Plan",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Container(
              width: MediaQuery.of(context).size.width,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: isLoading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(60),
                          child: CircularProgressIndicator()))
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(30, 26, 30, 18),
                                  child: Text(
                                    activeSub != null
                                        ? "Your Membership"
                                        : "1st Month Free Trial",
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: HexColor("#1B1D21"),
                                    ),
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    color: HexColor("#8F92A1").withOpacity(0.15)),
                                const SizedBox(height: 20),

                                if (activeSub != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: _buildActiveSubCard(),
                                  ),

                                if (activeSub == null)
                                  ...plans.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final plan = entry.value;
                                    final planId = plan['_id']?.toString() ?? '';
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 0, 20, 16),
                                      child: _buildPlanCard(
                                          plan,
                                          selectedPlanId == planId,
                                          planId,
                                          index),
                                    );
                                  }),

                                const SizedBox(height: 4),
                                // Grey separator bar
                                Container(
                                    height: 10,
                                    color: HexColor("#8F92A1").withOpacity(0.12)),
                                const SizedBox(height: 22),

                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 26),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildBenefitRow("Price Lock Guarantee"),
                                      _buildBenefitRow("Zero Wait Guarantee"),
                                      _buildBenefitRow(
                                          "Unlimited Deliveries & Services",
                                          isNew: true),
                                      _buildBenefitRow("Priority Rides"),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),

                        // Bottom CTA
                        if (plans.isNotEmpty && activeSub == null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(20, 8, 20,
                                MediaQuery.of(context).padding.bottom + 16),
                            child: GestureDetector(
                              onTap: isSubscribing ? null : _subscribe,
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      HexColor("#FFD546"),
                                      HexColor("#FF155E")
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isSubscribing
                                          ? "Processing..."
                                          : "Continue To Payment",
                                      style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    if (!isSubscribing) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward,
                                          color: Colors.white, size: 20),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Plan visual (colour + icon) per Figma ----
  Map<String, dynamic> _planVisual(String name, int index) {
    final n = name.toLowerCase();
    if (n.contains('annual') || n.contains('year')) {
      return {'color': HexColor("#F5418F"), 'icon': Icons.star_rounded};
    }
    if (n.contains('quarter')) {
      return {'color': HexColor("#1977F2"), 'icon': Icons.rocket_launch_rounded};
    }
    if (n.contains('month')) {
      return {
        'color': HexColor("#6C5CE7"),
        'icon': Icons.workspace_premium_rounded
      };
    }
    const palette = [Color(0xFF6C5CE7), Color(0xFF1977F2), Color(0xFFF5418F)];
    const icons = [
      Icons.workspace_premium_rounded,
      Icons.rocket_launch_rounded,
      Icons.star_rounded
    ];
    return {
      'color': palette[index % palette.length],
      'icon': icons[index % icons.length]
    };
  }

  Widget _buildPlanCard(
      Map<String, dynamic> plan, bool isSelected, String planId, int index) {
    final name = (plan['name'] ?? '').toString();
    final price = plan['price'] ?? 0;
    final isTrialAvailable = plan['isTrialAvailable'] == true;
    final imageUrl = plan['image']?.toString() ?? '';
    final tag = (plan['tag']?.toString() ?? '').toUpperCase();
    final isBestValue = tag == 'BEST VALUE' ||
        name.toLowerCase().contains('annual') ||
        name.toLowerCase().contains('year');

    final visual = _planVisual(name, index);
    final accent = HexColor("#1977F2");

    return GestureDetector(
      onTap: () => setState(() => selectedPlanId = planId),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? accent : Colors.transparent,
                width: isSelected ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x14263944),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: visual['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              visual['icon'] as IconData,
                              color: Colors.white,
                              size: 24))
                      : Icon(visual['icon'] as IconData,
                          color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                // Name + best value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: HexColor("#1A1A1A")),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              HexColor("#FFD147"),
                              HexColor("#FF395A")
                            ]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text("BEST VALUE",
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                ),
                // Price
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "₹ $price",
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HexColor("#191919")),
                          ),
                          if (isTrialAvailable)
                            TextSpan(
                              text: "/month",
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: HexColor("#191919")),
                            ),
                        ],
                      ),
                    ),
                    if (isTrialAvailable) ...[
                      const SizedBox(height: 4),
                      Text("after trial",
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.6,
                              color: HexColor("#525B63"))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Selected corner star ribbon
          if (isSelected)
            Positioned(
              top: -2,
              left: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveSubCard() {
    final plan = activeSub!['planId'];
    final planName = plan is Map ? plan['name'] : 'Kebu One Pass';
    final isTrial = activeSub!['isTrial'] == true;
    final endDate = activeSub!['endDate'] ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [HexColor("#FFD546"), HexColor("#FF155E")]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text("KEBU ONE PASS",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("$planName${isTrial ? ' – Trial' : ''}",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text("Valid till $endDate",
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text, {bool isNew = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: HexColor("#4FBF67"), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    letterSpacing: 0.28,
                    color: Colors.black)),
          ),
          if (isNew) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: HexColor("#1977F2")),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("New!",
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: HexColor("#1977F2"))),
            ),
          ],
        ],
      ),
    );
  }
}
