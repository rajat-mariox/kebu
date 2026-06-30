import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kebu_driver/Screens/DriverModule/SupportChatScreen/support_chat_screen.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelHistoryScreen/parcel_history_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Parcel drop-off payment "Summary" — Figma node 159:15484.
/// Backend-driven: amount, recipient contact and payment method come from
/// `GET /driver/app/delivery/:id/detail`. "Collected Cash" marks the delivery
/// DELIVERED and frees the partner.
class ParcelDeliverySummaryScreen extends StatefulWidget {
  final String deliveryId;
  const ParcelDeliverySummaryScreen({super.key, required this.deliveryId});

  @override
  State<ParcelDeliverySummaryScreen> createState() =>
      _ParcelDeliverySummaryScreenState();
}

class _ParcelDeliverySummaryScreenState
    extends State<ParcelDeliverySummaryScreen> {
  static final Color _primary = HexColor("#F32054");
  static final Color _gradTop = HexColor("#F52059");
  static final Color _gradBottom = HexColor("#D91916");
  static final Color _green = HexColor("#08875D");

  bool _loading = true;
  bool _collecting = false;
  Map<String, dynamic>? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getDeliveryDetail(widget.deliveryId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data != null) {
        _d = Map<String, dynamic>.from(res.data['delivery'] as Map);
      }
    });
  }

  num get _amount => (_d?['fee'] as num?) ?? 0;
  String get _contact => _d?['recipientContact']?.toString() ?? '';

  Future<void> _callContact() async {
    if (_contact.isEmpty) {
      Get.snackbar('Contact', 'No recipient contact available.');
      return;
    }
    final uri = Uri.parse('tel:$_contact');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _collectedCash() async {
    if (_collecting) return;
    setState(() => _collecting = true);
    final res = await DriverApiService.updateDeliveryStatus(
        widget.deliveryId, 'DELIVERED');
    if (!mounted) return;
    setState(() => _collecting = false);
    if (res.success) {
      Get.snackbar('Delivered', 'Payment collected — delivery completed.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Get.snackbar('Error',
          res.message.isEmpty ? 'Could not complete delivery' : res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(),
          _amountBand(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primary))
                : _body(),
          ),
          _footer(),
          _bottomNav(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradTop, _gradBottom],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.chevron_left,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Text("Summary",
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountBand() {
    return Container(
      width: double.infinity,
      color: _green,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text("Amount to be Collected",
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("₹${_amount.toStringAsFixed(2)}",
                  style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 34 / 28,
                      letterSpacing: -0.4,
                      color: Colors.white)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showFareBreakdown,
                child: const Icon(Icons.info_outline,
                    color: Colors.white, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fare Calculations modal (Figma 159:15566) — rendered from the backend
  /// `fareBreakdown` so the line items stay backend-driven.
  void _showFareBreakdown() {
    final fb = _d?['fareBreakdown'];
    if (fb == null) {
      Get.snackbar('Fare', 'Fare breakdown not available.');
      return;
    }
    final items = (fb['items'] as List?) ?? [];
    final adjustments = (fb['adjustments'] as List?) ?? [];
    final subTotal = (fb['subTotal'] as num?) ?? 0;
    final grandTotal = (fb['grandTotal'] as num?) ?? 0;

    String money(num n) {
      final v = n.abs();
      final s = v == v.roundToDouble() && v < 1000
          ? v.toStringAsFixed(v.truncateToDouble() == v ? 1 : 2)
          : v.toStringAsFixed(2);
      return "₹$s";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating dark close button above the sheet.
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: HexColor("#132235"),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Fare Calculations",
                          style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: HexColor("#132235"))),
                      const SizedBox(height: 36),
                      ...items.map((it) => _fareRow(
                            it['label']?.toString() ?? '',
                            "+ ${money((it['amount'] as num?) ?? 0)}",
                          )),
                      const SizedBox(height: 20),
                      Container(height: 1, color: HexColor("#E1E6EF")),
                      const SizedBox(height: 20),
                      _fareRow("Sub Total", money(subTotal),
                          bold: true, valueSize: 17),
                      ...adjustments.map((a) {
                        final amt = (a['amount'] as num?) ?? 0;
                        final sign = amt < 0 ? "- " : "+ ";
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _fareRow(
                              a['label']?.toString() ?? '', "$sign${money(amt)}"),
                        );
                      }),
                      const SizedBox(height: 20),
                      Container(height: 1, color: HexColor("#E1E6EF")),
                      const SizedBox(height: 20),
                      _fareRow("Grand Total", money(grandTotal),
                          bold: true, valueSize: 22),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fareRow(String label, String value,
      {bool bold = false, double valueSize = 15}) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  color: HexColor("#132235"))),
        ),
        Text(value,
            style: GoogleFonts.nunito(
                fontSize: valueSize,
                fontWeight: FontWeight.w700,
                color: HexColor("#132235"))),
      ],
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Text("QR Code",
              style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HexColor("#132235"))),
          const SizedBox(height: 8),
          Text("Scan & Pay",
              style: GoogleFonts.nunito(
                  fontSize: 15, color: HexColor("#364B63"))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(10),
            child: QrImageView(
              data: _qrPayload(),
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Payload encoded in the Scan & Pay QR. Until a payment-gateway VPA is
  /// wired, this carries the delivery reference + amount so the customer app
  /// can resolve the payment.
  String _qrPayload() {
    return 'kebu-delivery:${widget.deliveryId}:amount=${_amount.toStringAsFixed(2)}';
  }

  Widget _footer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HexColor("#E1E6EF"))),
      ),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _pill(
                      icon: Icons.call,
                      label: "Contact",
                      color: HexColor("#086634"),
                      onTap: _callContact,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pill(
                      icon: Icons.confirmation_number_outlined,
                      label: "Raise Ticket",
                      color: HexColor("#E02D3C"),
                      onTap: () =>
                          Get.to(() => const SupportChatScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _collecting ? null : _collectedCash,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 2,
                        top: 2,
                        bottom: 2,
                        child: Container(
                          width: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.keyboard_double_arrow_right,
                              color: _primary, size: 26),
                        ),
                      ),
                      _collecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text("Collected Cash",
                              style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x12000000), blurRadius: 30, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, "Home",
                  active: true,
                  onTap: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst)),
              _navItem(Icons.account_balance_wallet_outlined, "Earnings",
                  onTap: () => _comingSoon("Earnings")),
              _navItem(Icons.calendar_today_outlined, "Bookings",
                  onTap: () => Get.to(() => const ParcelHistoryScreen())),
              _navItem(Icons.person_outline, "Profile",
                  onTap: () => _comingSoon("Profile")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label,
      {bool active = false, required VoidCallback onTap}) {
    final color = active ? _primary : HexColor("#C0C5C2");
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 9,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }

  void _comingSoon(String what) {
    Get.snackbar(what, "$what screen is coming soon.",
        snackPosition: SnackPosition.BOTTOM);
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HexColor("#E1E6EF")),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.nunito(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}
