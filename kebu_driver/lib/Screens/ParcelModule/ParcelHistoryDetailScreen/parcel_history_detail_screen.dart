import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// History → delivery details — Figma node 159:14786.
/// Backend-driven: reads the `tripInfo` block from
/// `GET /driver/app/delivery/:id/detail`.
class ParcelHistoryDetailScreen extends StatefulWidget {
  final String deliveryId;
  const ParcelHistoryDetailScreen({super.key, required this.deliveryId});

  @override
  State<ParcelHistoryDetailScreen> createState() =>
      _ParcelHistoryDetailScreenState();
}

class _ParcelHistoryDetailScreenState extends State<ParcelHistoryDetailScreen> {
  static final Color _primary = HexColor("#F32054");
  static final Color _shade1 = HexColor("#132235");
  static final Color _border = HexColor("#E1E6EF");
  static final Color _blue = HexColor("#2F6FED");

  bool _loading = true;
  Map<String, dynamic>? _trip;

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
        final d = Map<String, dynamic>.from(res.data['delivery'] as Map);
        if (d['tripInfo'] != null) {
          _trip = Map<String, dynamic>.from(d['tripInfo'] as Map);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: HexColor("#F0F5FA"),
      body: Column(
        children: [
          _header(_trip?['refId']?.toString() ?? ''),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primary))
                : _trip == null
                    ? Center(
                        child: Text("Details unavailable",
                            style: GoogleFonts.nunito(color: Colors.grey)))
                    : _body(_trip!),
          ),
        ],
      ),
    );
  }

  Widget _header(String title) {
    return Container(
      color: _primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _pickupDestinationCard(t),
          const SizedBox(height: 16),
          _basicDetailsCard(t),
          const SizedBox(height: 16),
          _fareCard(t),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String t) {
    return Text(t,
        style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700, color: HexColor("#132234")));
  }

  Widget _pickupDestinationCard(Map<String, dynamic> t) {
    return _card(
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 54,
            bottom: 18,
            child: Container(width: 2, color: _border),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("PICKUP & DESTINATION"),
              const SizedBox(height: 12),
              _endpointRow(
                dotColor: HexColor("#08875D"),
                title: "Started : ${t['startedLabel'] ?? ''}",
                address: t['pickupAddress']?.toString() ?? '',
              ),
              const SizedBox(height: 16),
              _endpointRow(
                dotColor: _primary,
                title: t['endedLabel'] != null &&
                        t['endedLabel'].toString().isNotEmpty
                    ? "Ended : ${t['endedLabel']}"
                    : "Ended : —",
                address: t['dropAddress']?.toString() ?? '',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _endpointRow({
    required Color dotColor,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _shade1)),
              const SizedBox(height: 4),
              Text(address.isEmpty ? "—" : address,
                  style: GoogleFonts.nunito(fontSize: 13, color: _shade1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _basicDetailsCard(Map<String, dynamic> t) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("BASIC DETAILS"),
          const SizedBox(height: 12),
          _kv("Trip ID:", t['refId']?.toString() ?? ''),
          _kv("Trip Type:", t['tripType']?.toString() ?? ''),
          _kv("Trip Distance:", "${t['tripDistanceKm'] ?? 0} km"),
          _kv("Trip Duration:", t['tripDurationLabel']?.toString() ?? ''),
          _kv("Vehicle Type:", t['vehicleTypeName']?.toString() ?? '—',
              last: true),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: GoogleFonts.nunito(fontSize: 15, color: _shade1)),
          ),
          Text(v,
              style: GoogleFonts.nunito(fontSize: 15, color: _shade1)),
        ],
      ),
    );
  }

  Widget _fareCard(Map<String, dynamic> t) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("ESTIMATED FARE DETAILS"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text("Estimated Total Fare:",
                    style: GoogleFonts.nunito(fontSize: 15, color: _shade1)),
              ),
              Text("₹${t['estimatedTotalFare'] ?? 0}",
                  style: GoogleFonts.nunito(fontSize: 15, color: _shade1)),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _border),
          const SizedBox(height: 16),
          Center(
            child: Text("Earned money from trip:",
                style: GoogleFonts.nunito(fontSize: 13, color: _blue)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text("₹${t['earnedMoney'] ?? 0}",
                style: GoogleFonts.nunito(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _blue)),
          ),
        ],
      ),
    );
  }
}
