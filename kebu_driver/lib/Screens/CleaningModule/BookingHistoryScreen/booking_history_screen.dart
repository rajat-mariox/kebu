import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';

/// "Booking History" — backend-driven list of the logged-in partner's own
/// service bookings, grouped into On Going / Pending / Completed tabs. Data
/// comes from the household dashboard endpoint (already filtered by providerId),
/// so each partner only sees their real bookings.
class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  bool _loading = true;
  int _selectedTab = 0;
  List<Map<String, dynamic>> _bookingTabs = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getHouseholdDashboard();
    if (!mounted) return;

    if (!res.success || res.data == null) {
      setState(() => _loading = false);
      showCustomToast(context,
          res.message.isNotEmpty ? res.message : 'Failed to load bookings.');
      return;
    }

    final data = Map<String, dynamic>.from(res.data as Map);
    setState(() {
      _bookingTabs = (data['bookingTabs'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (_selectedTab >= _bookingTabs.length) _selectedTab = 0;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _currentBookings {
    if (_bookingTabs.isEmpty || _selectedTab >= _bookingTabs.length) {
      return const [];
    }
    return (_bookingTabs[_selectedTab]['bookings'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: HexColor("#2C54C1"),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text("Booking History",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 19),
          if (_bookingTabs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Row(
                children: List.generate(_bookingTabs.length, (i) {
                  final label = (_bookingTabs[i]['label'] ?? '').toString();
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: i == _bookingTabs.length - 1 ? 0 : 14),
                      child: _buildTabButton(label, i),
                    ),
                  );
                }),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final bookings = _currentBookings;
    if (bookings.isEmpty) {
      final label = _bookingTabs.isEmpty
          ? ''
          : (_bookingTabs[_selectedTab]['label'] ?? '').toString().toLowerCase();
      return RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Text(
                label.isEmpty ? "No bookings yet" : "No $label services",
                style: TextStyle(color: HexColor("#6C757D"), fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(26, 16, 26, 16),
        itemCount: bookings.length,
        itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final discountLabel = (b['discountLabel'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HexColor("#EBEBEB"), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + booking ID badge.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  (b['serviceType'] ?? '').toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: HexColor("#1C1F34")),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HexColor("#2D52C0"),
                  borderRadius: BorderRadius.circular(43),
                ),
                child: Text((b['bookingNumber'] ?? '').toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Price + discount.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                (b['priceLabel'] ?? '').toString(),
                style: TextStyle(
                    fontSize: 22,
                    color: HexColor("#2D52C0"),
                    fontWeight: FontWeight.bold),
              ),
              if (discountLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  discountLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: HexColor("#3CAE5C"),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Details: location / date / handyman name (15px gaps).
          if ((b['address'] ?? '').toString().isNotEmpty)
            _infoRow("assets/location.png", text: (b['address']).toString()),
          if ((b['dateLabel'] ?? '').toString().isNotEmpty) ...[
            if ((b['address'] ?? '').toString().isNotEmpty)
              const SizedBox(height: 15),
            _infoRow("assets/calendar_2.png",
                spans: _dateSpans((b['dateLabel']).toString())),
          ],
          if ((b['customerName'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 15),
            _infoRow("assets/person_icon.png",
                text: (b['customerName']).toString()),
          ],
        ],
      ),
    );
  }

  /// Splits "28 February, 2022 at 8:30 AM" so the time renders in the dark
  /// `#1C1F34` colour like the Figma. Falls back to a single grey span.
  List<TextSpan> _dateSpans(String dateLabel) {
    final grey = TextStyle(fontSize: 12, color: HexColor("#6C757D"));
    final dark = TextStyle(fontSize: 12, color: HexColor("#1C1F34"));
    final lower = dateLabel.toLowerCase();
    final idx = lower.lastIndexOf(' at ');
    if (idx == -1) {
      return [TextSpan(text: dateLabel, style: grey)];
    }
    return [
      TextSpan(text: dateLabel.substring(0, idx + 4), style: grey),
      TextSpan(text: dateLabel.substring(idx + 4), style: dark),
    ];
  }

  static Widget _infoRow(String icon,
      {String? text, List<TextSpan>? spans}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(icon, height: 14, width: 14, color: HexColor("#6C757D")),
        const SizedBox(width: 10),
        Expanded(
          child: spans != null
              ? RichText(text: TextSpan(children: spans))
              : Text(
                  text ?? '',
                  style: TextStyle(fontSize: 12, color: HexColor("#6C757D")),
                ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? HexColor("#2E50BF") : HexColor("#F6F7F9"),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: isActive ? Colors.white : HexColor("#1C1F34"),
                fontWeight: FontWeight.w500,
                fontSize: 14),
          ),
        ),
      ),
    );
  }
}
