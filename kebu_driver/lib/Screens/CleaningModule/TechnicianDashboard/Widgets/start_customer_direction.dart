import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/osm_map_widget.dart';
import 'package:kebu_driver/Screens/CleaningModule/ConfirmOtpScreen/confirm_otp_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown right after a household partner accepts a service.
///
/// Fully backend-driven: every field — the service category & details, est.
/// time, customer address & distance, service charge, booking id and the
/// customer's contact (Call/Chat) — comes from the `accept` response payload
/// (`{ booking, customer, bookingNumber, categoryName }`). A map at the top
/// pins the customer's location. Matches the Figma "Cleaning" direction screen.
class StartCustomerDirection extends StatefulWidget {
  /// The accept-service response: { booking, customer, bookingNumber, categoryName }.
  final Map<String, dynamic> data;

  const StartCustomerDirection({super.key, this.data = const {}});

  @override
  State<StartCustomerDirection> createState() => _StartCustomerDirectionState();
}

class _StartCustomerDirectionState extends State<StartCustomerDirection> {
  Map<String, dynamic> get _booking {
    final b = widget.data['booking'];
    return (b is Map) ? Map<String, dynamic>.from(b) : {};
  }

  Map<String, dynamic> get _customer {
    final c = widget.data['customer'];
    return (c is Map) ? Map<String, dynamic>.from(c) : {};
  }

  Map<String, dynamic>? get _address {
    final a = _booking['address'];
    return (a is Map) ? Map<String, dynamic>.from(a) : null;
  }

  String get _category {
    final c = (widget.data['categoryName'] ?? '').toString();
    if (c.isNotEmpty) return c;
    final cat = _booking['categoryId'] ?? _booking['category'];
    if (cat is Map && (cat['name'] ?? '').toString().isNotEmpty) {
      return cat['name'].toString();
    }
    return _serviceType;
  }

  String get _serviceType =>
      (_booking['serviceType'] ?? 'Household Service').toString();

  String get _serviceDetail {
    final d = (_booking['description'] ?? '').toString();
    return d.isNotEmpty ? d : _serviceType;
  }

  String get _estTime {
    final d = _booking['estimatedDuration'];
    if (d is num) return "Est time : ${d.toInt()} Mins";
    return "Est time : 0 Mins";
  }

  String get _amount {
    final v = _booking['finalCost'] ??
        _booking['estimatedCost'] ??
        _booking['actualCost'];
    return v == null ? "—" : "₹ $v";
  }

  String get _bookingNumber {
    final n = (widget.data['bookingNumber'] ?? '').toString();
    if (n.isNotEmpty) return n;
    final id = (_booking['_id'] ?? '').toString();
    return id.isEmpty ? "—" : "#${id.substring(id.length - 4)}";
  }

  String get _fullAddress {
    final a = _address;
    if (a == null) return 'Address not provided';
    return (a['fullAddress'] ?? a['address'] ?? '—').toString();
  }

  String get _distanceText {
    final d = _booking['distance'] ??
        _booking['distanceKm'] ??
        _booking['distanceInKm'];
    if (d is num) {
      final km = d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
      return "$km Km";
    }
    return (_booking['distanceText'] ?? '').toString();
  }

  double? get _lat {
    final v = _address?['lat'];
    return (v is num) ? v.toDouble() : null;
  }

  double? get _lng {
    final v = _address?['lng'];
    return (v is num) ? v.toDouble() : null;
  }

  Future<void> _callCustomer() async {
    final phone = (_customer['phone'] ?? '').toString();
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: "Customer phone not available");
      return;
    }
    final code = (_customer['countryCode'] ?? '').toString();
    final uri = Uri.parse("tel:$code$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Fluttertoast.showToast(msg: "Could not open dialer");
    }
  }

  void _chatCustomer() {
    // A dedicated provider↔customer chat thread is not wired for household
    // bookings yet; surface a clear message rather than a dead button.
    Fluttertoast.showToast(msg: "Chat will be available soon");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor("#FBFBFB"),
      body: Stack(
        children: [
          // Map background pinned to the customer's location.
          Positioned.fill(
            child: OsmMapWidget(
              centerLat: _lat,
              centerLng: _lng,
              dropLat: _lat,
              dropLng: _lng,
              zoom: 15,
              interactive: true,
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: HexColor("#E1E6EF")),
                  ),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
              ),
            ),
          ),

          // Bottom details sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: _detailsSheet(),
          ),
        ],
      ),
    );
  }

  Widget _detailsSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 4,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _serviceDetailsCard(),
            const SizedBox(height: 16),
            _customerAddressSection(),
            const SizedBox(height: 14),
            _serviceChargeCard(),
            const SizedBox(height: 16),
            _callChatButtons(),
            const SizedBox(height: 16),
            _startDirectionButton(),
          ],
        ),
      ),
    );
  }

  // ── Service details card ──
  Widget _serviceDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w400),
                    children: [
                      const TextSpan(text: "Service details - "),
                      TextSpan(
                        text: _category,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _estTime,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF275FC8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _serviceDetail,
            style: const TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Customer address ──
  Widget _customerAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Customer Address.",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black),
            ),
            const Spacer(),
            if (_distanceText.isNotEmpty)
              Text(
                _distanceText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HexColor("#2C54C1"),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: 0.8,
          child: Text(
            _fullAddress,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: Colors.black,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  // ── Service charge card ──
  Widget _serviceChargeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40DDDDDD),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Service charge",
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                _amount,
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                "Your Booking ID is",
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
              const SizedBox(width: 6),
              Text(
                _bookingNumber,
                style: TextStyle(fontSize: 12, color: HexColor("#275FC8")),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Call / Chat ──
  Widget _callChatButtons() {
    return Row(
      children: [
        Expanded(child: _outlinedAction(Icons.call, "Call", _callCustomer)),
        const SizedBox(width: 12),
        Expanded(
          child: _outlinedAction(
              Icons.chat_bubble_outline, "Chat", _chatCustomer),
        ),
      ],
    );
  }

  Widget _outlinedAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HexColor("#E1E6EF")),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), blurRadius: 1.5, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: HexColor("#2C54C1")),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: HexColor("#2C54C1"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Start customer direction ──
  Widget _startDirectionButton() {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () => pushTo(context, const ConfirmOtpScreen()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HexColor("#2C54C1"),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Start customer direction",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
