import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device's phone dialer for [countryCode][phone].
/// Returns false if there's no number or the dialer can't be opened.
Future<bool> launchPhoneDialer(String countryCode, String phone) async {
  if (phone.trim().isEmpty) return false;
  final uri = Uri.parse("tel:$countryCode$phone");
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Opens Google Maps (the native app when installed, otherwise the browser)
/// with driving directions to [lat],[lng] — the device's current location is
/// used as the origin, matching the Figma "open in Google Maps" flow.
Future<bool> launchMapsDirections(double lat, double lng) async {
  final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
  try {
    // Prefer the Google Maps app; fall back to the platform default handler.
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
    return await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    return false;
  }
}

/// Thin wrapper over the household accept/booking payload
/// (`{ booking, customer, bookingNumber, categoryName }`) exposing the fields
/// the partner direction screens render. Keeps both the "Start customer
/// direction" and the en-route screens fully data-driven from one place.
class DirectionData {
  final Map<String, dynamic> data;
  const DirectionData(this.data);

  Map<String, dynamic> get booking {
    final b = data['booking'];
    return (b is Map) ? Map<String, dynamic>.from(b) : {};
  }

  Map<String, dynamic> get customer {
    final c = data['customer'];
    return (c is Map) ? Map<String, dynamic>.from(c) : {};
  }

  Map<String, dynamic>? get address {
    final a = booking['address'];
    return (a is Map) ? Map<String, dynamic>.from(a) : null;
  }

  String get serviceType =>
      (booking['serviceType'] ?? 'Household Service').toString();

  String get category {
    final c = (data['categoryName'] ?? '').toString();
    if (c.isNotEmpty) return c;
    final cat = booking['categoryId'] ?? booking['category'];
    if (cat is Map && (cat['name'] ?? '').toString().isNotEmpty) {
      return cat['name'].toString();
    }
    return serviceType;
  }

  String get serviceDetail {
    final d = (booking['description'] ?? '').toString();
    return d.isNotEmpty ? d : serviceType;
  }

  String get estTime {
    final d = booking['estimatedDuration'];
    if (d is num) return "Est time : ${d.toInt()} Mins";
    return "Est time : 0 Mins";
  }

  String get amount {
    final v =
        booking['finalCost'] ?? booking['estimatedCost'] ?? booking['actualCost'];
    return v == null ? "—" : "₹ $v";
  }

  String get bookingNumber {
    final n = (data['bookingNumber'] ?? '').toString();
    if (n.isNotEmpty) return n;
    final id = (booking['_id'] ?? '').toString();
    return id.isEmpty ? "—" : "#${id.substring(id.length - 4)}";
  }

  String get bookingId => (booking['_id'] ?? '').toString();

  String get fullAddress {
    final a = address;
    if (a == null) return 'Address not provided';
    return (a['fullAddress'] ?? a['address'] ?? '—').toString();
  }

  String get distanceText {
    final d =
        booking['distance'] ?? booking['distanceKm'] ?? booking['distanceInKm'];
    if (d is num) {
      final km = d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
      return "$km Km";
    }
    return (booking['distanceText'] ?? '').toString();
  }

  double? get lat {
    final v = address?['lat'];
    return (v is num) ? v.toDouble() : null;
  }

  double? get lng {
    final v = address?['lng'];
    return (v is num) ? v.toDouble() : null;
  }

  String get phone => (customer['phone'] ?? '').toString();
  String get countryCode => (customer['countryCode'] ?? '').toString();

  /// Backend-provided price breakdown rows: [{label, quantity, amount}].
  List<Map<String, dynamic>> get priceBreakdown {
    final list = data['priceBreakdown'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  num get totalAmount {
    final v = data['totalAmount'];
    if (v is num) return v;
    final fc = booking['finalCost'];
    return (fc is num) ? fc : 0;
  }

  String get totalAmountLabel => "₹$totalAmount";

  num get subtotal {
    final v = booking['estimatedCost'];
    return (v is num) ? v : totalAmount;
  }

  String get subtotalLabel => "₹$subtotal";

  /// Platform service charge (commission) for this booking — computed and sent
  /// by the backend from the admin's CommissionConfig. 0 when none applies.
  num get serviceCharge {
    final v = booking['serviceCharge'];
    return (v is num) ? v : 0;
  }

  String get serviceChargeLabel => "₹$serviceCharge";

  /// e.g. "1Hrs 45 min" from the booking's estimated duration (minutes).
  String get estimatedDurationLabel {
    final d = booking['estimatedDuration'];
    if (d is num && d > 0) {
      final h = d ~/ 60;
      final m = (d % 60).toInt();
      if (h > 0 && m > 0) return "${h}Hrs $m min";
      if (h > 0) return "${h}Hrs";
      return "$m min";
    }
    return "";
  }

  /// Service start time formatted as "Today h:mm a" (falls back to now).
  String get startTimeLabel {
    final raw = booking['startedAt'];
    DateTime dt;
    try {
      dt = raw != null ? DateTime.parse(raw.toString()).toLocal() : DateTime.now();
    } catch (_) {
      dt = DateTime.now();
    }
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    var h = dt.hour % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return "Today $h:$m $ampm";
  }
}

/// The three stacked info cards shared by both direction screens: service
/// details, customer address and service charge.
class DirectionDetailsCards extends StatelessWidget {
  final DirectionData d;

  /// Live road distance (e.g. "1.2 Km") computed from the actual driving route.
  /// When provided it overrides the booking's stored straight-line distance so
  /// the card reflects the real shortest-path distance shown on the map.
  final String? distanceOverride;

  const DirectionDetailsCards({super.key, required this.d, this.distanceOverride});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _serviceDetailsCard(),
        const SizedBox(height: 16),
        _customerAddressSection(),
        const SizedBox(height: 14),
        _serviceChargeCard(),
      ],
    );
  }

  Widget _serviceDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
                        text: d.category,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                d.estTime,
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
            d.serviceDetail,
            style: const TextStyle(
                fontSize: 12, color: Colors.black, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

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
            Builder(builder: (_) {
              final distance = (distanceOverride?.isNotEmpty ?? false)
                  ? distanceOverride!
                  : d.distanceText;
              if (distance.isEmpty) return const SizedBox.shrink();
              return Text(
                distance,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: HexColor("#2C54C1"),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: 0.8,
          child: Text(
            d.fullAddress,
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

  Widget _serviceChargeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x40DDDDDD), blurRadius: 8)],
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
                d.amount,
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
                d.bookingNumber,
                style: TextStyle(fontSize: 12, color: HexColor("#275FC8")),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

/// A white, outlined pill action used for the Call / Chat / Map buttons.
class DirectionActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const DirectionActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = HexColor("#2C54C1");
    final fg = filled ? Colors.white : primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: filled ? Colors.white : HexColor("#E1E6EF")),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000), blurRadius: 1.5, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w400, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
