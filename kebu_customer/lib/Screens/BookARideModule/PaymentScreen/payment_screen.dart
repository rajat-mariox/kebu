import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/BookARideModule/UpiCheckoutScreen/payment_checkout_screen.dart';
import 'package:kebu_customer/Services/payment_api_service.dart';

class PaymentScreen extends StatefulWidget {
  final String? bookingId;
  final double? amount;
  final String paymentType;
  final String? userName;
  final String? email;
  final String? contact;

  /// Branding overrides so the same screen can serve different modules
  /// (e.g. ride = gold, household/cleaning = pink→purple).
  final String title;
  final String? confirmLabel;
  final List<Color>? brandColors;

  /// Accent for the selected-method check + per-tile "Pay using X" button.
  /// Defaults to the ride gold; cleaning passes the Google-Pay blue.
  final Color? selectedAccent;

  const PaymentScreen({
    super.key,
    this.bookingId,
    this.amount,
    this.paymentType = 'BOOKING_PAYMENT',
    this.userName,
    this.email,
    this.contact,
    this.title = 'Payments',
    this.confirmLabel,
    this.brandColors,
    this.selectedAccent,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = "Google Pay";

  LinearGradient get _brandGradient => LinearGradient(
        colors: widget.brandColors ?? [HexColor("#FFD546"), HexColor("#FF155E")],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  Future<void> _initiatePayment() async {
    if (widget.bookingId != null) {
      final response = await PaymentApiService.createPaymentOrder(
        amount: widget.amount ?? 145,
        type: widget.paymentType,
        referenceId: widget.bookingId!,
      );
      if (response.success && mounted) {
        pushTo(
            context,
            PaymentCheckoutScreen(
              keyId: response.data?['keyId'],
              orderId: response.data?['orderId'],
              amount: widget.amount ?? 145,
              referenceId: widget.bookingId,
              paymentType: widget.paymentType,
              userName: widget.userName,
              email: widget.email,
              contact: widget.contact,
              preferredMethod: selectedMethod,
            ));
        return;
      }
    }
    pushTo(context, const PaymentCheckoutScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: GestureDetector(
            onTap: _initiatePayment,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.confirmLabel ?? "Confirm & Pay",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: 160,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.brandColors ??
                      [HexColor("#FFD546"), HexColor("#FF155E")],
                ),
              ),
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
                      widget.title,
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
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.only(top: 120),
              padding: const EdgeInsets.fromLTRB(19, 22, 19, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Preferred Mode"),
                  const SizedBox(height: 12),
                  _buildCard(children: [
                    _buildPaymentTile(
                      icon: "assets/payments/google_pay_icon.png",
                      title: "Google Pay",
                      trailing: _selector("Google Pay"),
                      onTap: () =>
                          setState(() => selectedMethod = "Google Pay"),
                    ),
                    _divider(),
                    _buildPaymentTile(
                      icon: "assets/payments/paytm_icon.png",
                      title: "Paytm",
                      onTap: () => setState(() => selectedMethod = "Paytm"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("₹${(widget.amount ?? 145).toStringAsFixed(0)}",
                              style: GoogleFonts.montserrat(
                                  color: HexColor('#8F8F8F'),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400)),
                          const SizedBox(width: 10),
                          _selector("Paytm"),
                        ],
                      ),
                    ),
                    _divider(),
                    _buildPaymentTile(
                      icon: "assets/payments/mastercard_icon.png",
                      title: "•••• 9999",
                      onTap: () => setState(() => selectedMethod = "•••• 9999"),
                      subtitleWidget: Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: HexColor("#469CFF").withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user,
                                size: 11, color: HexColor("#4681FF")),
                            const SizedBox(width: 3),
                            Text("Secured",
                                style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: HexColor("#4681FF"))),
                          ],
                        ),
                      ),
                      trailing: _selector("•••• 9999"),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _sectionTitle("UPI"),
                  const SizedBox(height: 12),
                  _buildCard(children: [
                    _buildPaymentTile(
                      icon: "assets/payments/phone_pay.png",
                      title: "PhonePe UPI",
                      subtitle: "Low success rate currently",
                      onTap: () =>
                          setState(() => selectedMethod = "PhonePe UPI"),
                      trailing: _selector("PhonePe UPI"),
                    ),
                    _divider(),
                    _buildPaymentTile(
                      icon: "assets/payments/mobikwik_icon.png",
                      title: "Mobikwik",
                      onTap: () => setState(() => selectedMethod = "Mobikwik"),
                      trailing: _selector("Mobikwik"),
                    ),
                    _divider(),
                    _buildPaymentTile(
                      icon: "assets/payments/cred_pay.png",
                      title: "CRED pay",
                      onTap: () => setState(() => selectedMethod = "CRED pay"),
                      trailing: _selector("CRED pay"),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
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

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: HexColor("#ECECEC"));

  Color get _accent => widget.selectedAccent ?? HexColor("#FFD546");

  // Accent check when selected, grey radio otherwise
  Widget _selector(String method) {
    final selected = selectedMethod == method;
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    }
    return Icon(Icons.radio_button_unchecked,
        color: Colors.grey.shade400, size: 22);
  }

  Widget _buildCard({required List<Widget> children}) {
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

  Widget _buildPaymentTile({
    required String icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isSelected = selectedMethod == title;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: HexColor("#CAC7C7"), width: 0.6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child:
                      Image.asset(icon, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          style: GoogleFonts.montserrat(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.25,
                              color: Colors.black)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle,
                              style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.black)),
                        ),
                      if (subtitleWidget != null) subtitleWidget,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (trailing != null) trailing,
              ],
            ),
            // "Pay using X" gradient button when selected
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 56),
                child: GestureDetector(
                  onTap: _initiatePayment,
                  child: Container(
                    width: double.infinity,
                    height: 47,
                    decoration: BoxDecoration(
                      color: widget.selectedAccent,
                      gradient:
                          widget.selectedAccent == null ? _brandGradient : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "Pay using $title",
                      style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
