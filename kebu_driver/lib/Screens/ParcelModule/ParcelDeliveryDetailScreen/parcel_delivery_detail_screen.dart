import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Screens/ParcelModule/Controller/parcel_booking_controller.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelRequestMapScreen/parcel_request_map_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Parcel "Delivery details" screen — Figma node 158:13699.
/// Fully backend-driven: every field is read from
/// `GET /driver/app/delivery/:id/detail`.
class ParcelDeliveryDetailScreen extends StatefulWidget {
  final String deliveryId;
  const ParcelDeliveryDetailScreen({super.key, required this.deliveryId});

  @override
  State<ParcelDeliveryDetailScreen> createState() =>
      _ParcelDeliveryDetailScreenState();
}

class _ParcelDeliveryDetailScreenState
    extends State<ParcelDeliveryDetailScreen> {
  static final Color _primary = HexColor("#F32054");
  static final Color _gradTop = HexColor("#F52059");
  static final Color _gradBottom = HexColor("#D91916");
  static final Color _label = HexColor("#77869E");
  static final Color _value = HexColor("#111111");

  late final ParcelBookingController _c = Get.isRegistered<ParcelBookingController>()
      ? Get.find<ParcelBookingController>()
      : Get.put(ParcelBookingController());

  bool _loading = true;
  bool _acting = false;
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

  Future<void> _accept() async {
    if (_acting) return;
    setState(() => _acting = true);
    final ok = await _c.accept(widget.deliveryId);
    if (!mounted) return;
    setState(() => _acting = false);
    if (ok) {
      // Accepted → continue straight into the live map (en route to pickup),
      // replacing this detail so Back returns to home.
      _openMap(canAct: false, replace: true);
    }
  }

  Future<void> _reject() async {
    if (_acting) return;
    setState(() => _acting = true);
    await _c.reject(widget.deliveryId);
    if (mounted) Navigator.pop(context);
  }

  void _openMapRoute() =>
      _openMap(canAct: _d?['canAcceptReject'] == true, replace: false);

  void _openMap({required bool canAct, bool replace = false}) {
    final pickup = _d?['pickupLocation'];
    final drop = _d?['deliveryLocation'];
    if (pickup == null || pickup['lat'] == null || pickup['lng'] == null) {
      Get.snackbar('Map', 'Location not available for this request.');
      return;
    }
    if (drop == null || drop['lat'] == null || drop['lng'] == null) {
      Get.snackbar('Map', 'Drop-off location not available.');
      return;
    }
    final screen = ParcelRequestMapScreen(
      deliveryId: widget.deliveryId,
      pickupLat: (pickup['lat'] as num).toDouble(),
      pickupLng: (pickup['lng'] as num).toDouble(),
      pickupAddress: pickup['address']?.toString() ?? '',
      dropLat: (drop['lat'] as num).toDouble(),
      dropLng: (drop['lng'] as num).toDouble(),
      dropAddress: drop['address']?.toString() ?? '',
      canAct: canAct,
    );
    if (replace) {
      Get.off(() => screen);
    } else {
      Get.to(() => screen);
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
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primary))
                : _d == null
                    ? _errorState()
                    : _content(),
          ),
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
                borderRadius: BorderRadius.circular(20),
                child: const Icon(Icons.chevron_left,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Text("Delivery details",
                  style: GoogleFonts.poppins(
                      fontSize: 20, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 10),
            Text("Couldn't load delivery details.",
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final d = _d!;
    final sender = (d['sender'] as Map?) ?? {};
    final pickup = (d['pickupLocation'] as Map?) ?? {};
    final drop = (d['deliveryLocation'] as Map?);
    final pickupImages =
        ((d['pickupImages'] as List?) ?? []).cast<dynamic>();
    final canAct = d['canAcceptReject'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _senderCard(sender),
          const SizedBox(height: 24),
          _locations(
            pickup['address']?.toString() ?? '',
            drop?['address']?.toString() ?? '',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 48,
            runSpacing: 16,
            children: [
              _field("What you are sending",
                  d['whatYouAreSending']?.toString() ?? '—'),
              _field("Recipient", d['recipientName']?.toString() ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _field("Recipient contact number",
              d['recipientContact']?.toString() ?? '—'),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _field("Payment", d['paymentLabel']?.toString() ?? '—')),
              Expanded(child: _feeBlock(d['fee'])),
            ],
          ),
          if (pickupImages.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text("Pickup image(s)",
                style: GoogleFonts.poppins(fontSize: 12, color: _label)),
            const SizedBox(height: 10),
            Row(
              children: pickupImages
                  .take(4)
                  .map((u) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(u.toString(),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 64,
                                  height: 64,
                                  color: HexColor("#F1F1F1"))),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _openMapRoute,
              child: Text(
                "View Map Route",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: _primary,
                  decoration: TextDecoration.underline,
                  decorationColor: _primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (canAct) _actionButtons() else _statusPill(d['status']?.toString()),
        ],
      ),
    );
  }

  Widget _senderCard(Map sender) {
    final name = sender['name']?.toString() ?? '';
    final image = sender['image']?.toString() ?? '';
    final initials = sender['initials']?.toString() ?? '';
    final deliveries = sender['deliveriesCount'] ?? 0;
    final rating = (sender['rating'] ?? 0).toDouble();

    return Row(
      children: [
        if (image.isNotEmpty)
          CircleAvatar(radius: 28, backgroundImage: NetworkImage(image))
        else
          CircleAvatar(
            radius: 28,
            backgroundColor: HexColor("#FDE7EC"),
            child: Text(initials,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: HexColor("#EE1E49"),
                    fontWeight: FontWeight.w500)),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? "Customer" : name,
                  style: GoogleFonts.poppins(fontSize: 16, color: _value)),
              const SizedBox(height: 4),
              Text("$deliveries Deliveries",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: HexColor("#4F4F4F"))),
              const SizedBox(height: 4),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: rating,
                    itemCount: 5,
                    itemSize: 14,
                    unratedColor: HexColor("#E0E0E0"),
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star, color: Color(0xFFFFC107)),
                  ),
                  const SizedBox(width: 6),
                  Text(rating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: HexColor("#4F4F4F"))),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.two_wheeler, color: _primary, size: 22),
        ),
      ],
    );
  }

  Widget _locations(String pickup, String delivery) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.location_on, color: _primary, size: 18),
            Container(
              width: 1.5,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: HexColor("#C9D2DE"),
            ),
            Icon(Icons.location_on, color: HexColor("#2EAD6E"), size: 18),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _locBlock("Pickup Location", pickup),
              const SizedBox(height: 16),
              _locBlock("Delivery Location", delivery),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: _label)),
        const SizedBox(height: 4),
        Text(value.isEmpty ? "—" : value,
            style: GoogleFonts.poppins(
                fontSize: 14, color: _value, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _label)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, color: _value)),
      ],
    );
  }

  Widget _feeBlock(dynamic fee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: 0.5,
          child: Text("Fee:",
              style:
                  GoogleFonts.poppins(fontSize: 12, color: HexColor("#545454"))),
        ),
        const SizedBox(height: 4),
        Text("₹${fee ?? 0}",
            style: GoogleFonts.poppins(
                fontSize: 16,
                color: HexColor("#1D3557"),
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _statusPill(String? status) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          (status ?? '').isEmpty ? "—" : status!,
          style: GoogleFonts.poppins(
              fontSize: 14, color: _primary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _acting ? null : _reject,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("Reject",
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _primary)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _acting ? null : _accept,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _acting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text("Accept",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}
