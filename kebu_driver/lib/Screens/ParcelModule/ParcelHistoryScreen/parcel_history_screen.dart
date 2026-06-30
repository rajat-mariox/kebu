import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelHistoryDetailScreen/parcel_history_detail_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Parcel partner delivery History — Figma node 159:14644.
/// Backend-driven: sections + cards come from
/// `GET /driver/app/delivery/history`.
class ParcelHistoryScreen extends StatefulWidget {
  const ParcelHistoryScreen({super.key});

  @override
  State<ParcelHistoryScreen> createState() => _ParcelHistoryScreenState();
}

class _ParcelHistoryScreenState extends State<ParcelHistoryScreen> {
  static final Color _primary = HexColor("#F32054");
  static final Color _shade1 = HexColor("#132235");
  static final Color _shade2 = HexColor("#364B63");
  static final Color _shade3 = HexColor("#607080");
  static final Color _border = HexColor("#E1E6EF");

  bool _loading = true;
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getDeliveryHistory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data != null) {
        _sections = (res.data['sections'] as List?) ?? [];
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
          _header(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primary))
                : _sections.isEmpty
                    ? _emptyState()
                    : _list(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
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
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text("History",
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              InkWell(
                onTap: () {},
                child: const Icon(Icons.tune, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("No deliveries yet.",
              style: GoogleFonts.nunito(
                  fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: Container(
        color: Colors.white,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _sections.length,
          itemBuilder: (_, i) {
            final section = _sections[i] as Map;
            final items = (section['items'] as List?) ?? [];
            return Column(
              children: [
                _sectionLabel(section['label']?.toString() ?? ''),
                const SizedBox(height: 16),
                ...items.map((it) {
                  final m = Map<String, dynamic>.from(it as Map);
                  final id = m['deliveryId']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: id.isEmpty
                          ? null
                          : () => Get.to(() =>
                              ParcelHistoryDetailScreen(deliveryId: id)),
                      child: _card(m),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _border)),
        const SizedBox(width: 16),
        Text(label.toUpperCase(),
            style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w700, color: _shade3)),
        const SizedBox(width: 16),
        Expanded(child: Container(height: 1, color: _border)),
      ],
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final delivered = (d['status']?.toString() ?? '') == 'DELIVERED';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                // Name + ID and date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['customerName']?.toString() ?? '',
                              style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _shade1)),
                          const SizedBox(height: 4),
                          Text("ID: ${d['refId'] ?? ''}",
                              style: GoogleFonts.nunito(
                                  fontSize: 12, color: _shade2)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: _shade2),
                        const SizedBox(width: 6),
                        Text(d['date']?.toString() ?? '',
                            style: GoogleFonts.nunito(
                                fontSize: 13, color: _shade2)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Pickup
                _locationRow(d['pickupAddress']?.toString() ?? '',
                    withBottomBorder: true),
                // Drop
                _locationRow(d['dropAddress']?.toString() ?? '',
                    withBottomBorder: false),
                const SizedBox(height: 12),
                // Type / distance / duration
                Row(
                  children: [
                    Expanded(
                      child: _metric(Icons.local_shipping_outlined,
                          d['typeLabel']?.toString() ?? ''),
                    ),
                    Expanded(
                      child: _metric(Icons.route,
                          "${d['distanceKm'] ?? 0}km", center: true),
                    ),
                    Expanded(
                      child: _metric(Icons.access_time,
                          d['durationLabel']?.toString() ?? '',
                          end: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: HexColor("#E9F0F7")),
          // Fare bar
          Container(
            width: double.infinity,
            color: delivered ? _primary : HexColor("#F0F5FF"),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined,
                    size: 20, color: delivered ? Colors.white : _primary),
                const SizedBox(width: 8),
                Text("₹${d['fare'] ?? 0}",
                    style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: delivered ? Colors.white : _primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow(String address, {required bool withBottomBorder}) {
    return Container(
      decoration: BoxDecoration(
        border: withBottomBorder
            ? Border(bottom: BorderSide(color: _border))
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(color: _primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(address.isEmpty ? "—" : address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(fontSize: 15, color: _shade1)),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String text,
      {bool center = false, bool end = false}) {
    return Row(
      mainAxisAlignment: end
          ? MainAxisAlignment.end
          : center
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _shade2),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _shade2)),
        ),
      ],
    );
  }
}
