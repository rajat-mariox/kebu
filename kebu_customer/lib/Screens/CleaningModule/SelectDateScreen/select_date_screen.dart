import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/CleaningReviewBookingScreen/cleaning_review_booking_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/SelectDateScreen/range_calendar.dart';
import 'package:kebu_customer/Services/household_api_service.dart';

/// Multiple-booking screen (Figma node 782:34399): pick a date range, a
/// duration package, and a start time. Fully backend-driven.
class SelectDateScreen extends StatefulWidget {
  final String? categoryId;
  final String? serviceType;
  const SelectDateScreen({super.key, this.categoryId, this.serviceType});

  @override
  State<SelectDateScreen> createState() => _SelectDateScreenState();
}

class _SelectDateScreenState extends State<SelectDateScreen> {
  static final Color _pink = HexColor('#E61978');
  static final Color _purple = HexColor('#461E98');
  static final Color _accent = HexColor('#D50069');
  static final Color _ink = HexColor('#161938');
  static final Color _chipBorder = HexColor('#A9A9A9');
  static final Color _cardBorder = HexColor('#BDBDBD');
  static final Color _periodSel = HexColor('#412190');

  final controller = Get.find<HouseholdBookingController>();
  String get _categoryId => widget.categoryId ?? 'default';

  bool isLoading = true;
  bool isSlotsLoading = false;

  // Date range
  Set<DateTime> availableDays = {};
  DateTime? firstDate;
  DateTime? startDate;
  DateTime? endDate;

  // Duration + start time (same backend sources as ServiceDetailsScreen)
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> slotGroups = [];
  int selectedDurationIndex = 0;
  int selectedPeriodIndex = 0;
  String? selectedTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      HouseholdApiService.getAvailableDates(_categoryId),
      HouseholdApiService.getServicePackages(_categoryId),
      HouseholdApiService.getAvailableTimeSlots(_categoryId),
    ]);
    if (!mounted) return;
    setState(() {
      final dRes = results[0];
      if (dRes.success && dRes.data != null) {
        for (final m in ((dRes.data['dates'] as List?) ?? const [])
            .whereType<Map>()) {
          if (m['isAvailable'] == false) continue;
          final d = DateTime.tryParse((m['date'] ?? '').toString());
          if (d != null) availableDays.add(DateTime(d.year, d.month, d.day));
        }
        if (availableDays.isNotEmpty) {
          firstDate = availableDays.reduce((a, b) => a.isBefore(b) ? a : b);
        }
      }
      final pRes = results[1];
      if (pRes.success && pRes.data != null) {
        packages = ((pRes.data['packages'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      final tRes = results[2];
      if (tRes.success && tRes.data != null) {
        slotGroups = _parseSlotGroups(tRes.data['timeSlots']);
        _applyDefaultTimeSelection();
      }
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> _parseSlotGroups(dynamic raw) {
    return ((raw as List?) ?? const []).whereType<Map>().map((g) {
      final slots = ((g['slots'] as List?) ?? const [])
          .whereType<Map>()
          .map((s) => <String, dynamic>{
                'time': (s['time'] ?? '').toString(),
                'isAvailable': s['isAvailable'] != false,
              })
          .toList();
      return <String, dynamic>{
        'slotType': (g['slotType'] ?? '').toString(),
        'slots': slots,
      };
    }).toList();
  }

  void _applyDefaultTimeSelection() {
    selectedTime = null;
    for (var i = 0; i < slotGroups.length; i++) {
      final slots =
          (slotGroups[i]['slots'] as List).cast<Map<String, dynamic>>();
      final first = slots.firstWhere((s) => s['isAvailable'] == true,
          orElse: () => const {});
      if (first.isNotEmpty) {
        selectedPeriodIndex = i;
        selectedTime = first['time'] as String;
        return;
      }
    }
    selectedPeriodIndex = 0;
  }

  // ----- Derived -----
  int get _dayCount {
    if (startDate == null) return 0;
    if (endDate == null) return 1;
    return endDate!.difference(startDate!).inDays + 1;
  }

  Map<String, dynamic>? get _selectedPackage =>
      packages.isNotEmpty && selectedDurationIndex < packages.length
          ? packages[selectedDurationIndex]
          : null;

  double _finalPrice(Map pkg) {
    final offer = pkg['appliedOffer'] as Map?;
    final v = offer != null
        ? offer['finalPrice']
        : (pkg['discountedPrice'] ?? pkg['originalPrice'] ?? 0);
    return (v as num?)?.toDouble() ?? 0;
  }

  double _origPrice(Map pkg) =>
      (pkg['originalPrice'] as num?)?.toDouble() ?? _finalPrice(pkg);

  String _money(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  bool get _canConfirm =>
      !isLoading &&
      startDate != null &&
      _selectedPackage != null &&
      selectedTime != null;

  String get _addressLabel {
    final l = controller.addressLabel.value;
    if (l.isNotEmpty) return l;
    try {
      final a = Get.find<BookingController>().pickupAddress.value.trim();
      if (a.isNotEmpty) return a.split(',').first.trim();
    } catch (_) {}
    return 'Select address';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final gradientH = topInset + 96;
    final cardTop = topInset + 80;
    return Scaffold(
      backgroundColor: HexColor('#F5F5F5'),
      bottomNavigationBar: _bottomBar(),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Container(
              height: gradientH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_pink, _purple],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(top: cardTop),
              width: double.infinity,
              constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height),
              decoration: BoxDecoration(
                color: HexColor('#F5F5F5'),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('choose service details',
                      style: GoogleFonts.poppins(
                          fontSize: 18, color: _ink, letterSpacing: -0.4)),
                  const SizedBox(height: 19),
                  _dateCard(),
                  // Duration + start time appear only after a date is picked.
                  if (!isLoading && startDate != null) ...[
                    const SizedBox(height: 19),
                    _durationCard(),
                    const SizedBox(height: 19),
                    _startTimeCard(),
                  ],
                ],
              ),
            ),
            _header(topInset),
          ],
        ),
      ),
    );
  }

  Widget _header(double topInset) {
    return Positioned(
      top: topInset + 4,
      left: 16,
      right: 16,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(_addressLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.4)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white),
              ),
              child: Text('Change',
                  style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DATE CARD ====================

  Widget _dateCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select start',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: _ink, letterSpacing: -0.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateField('Start Date', startDate)),
              SizedBox(
                width: 56,
                child: Center(
                  child: _dayCount >= 2
                      ? Text('$_dayCount Days',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: HexColor('#E51878'),
                              letterSpacing: -0.4))
                      : Container(width: 12, height: 1, color: _chipBorder),
                ),
              ),
              Expanded(child: _dateField('End Date', endDate)),
            ],
          ),
          const SizedBox(height: 16),
          _dottedLine(),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            RangeCalendar(
              firstDate: firstDate,
              availableDays: availableDays.isEmpty ? null : availableDays,
              onChanged: (s, e) => setState(() {
                startDate = s;
                endDate = e;
              }),
            ),
        ],
      ),
    );
  }

  Widget _dateField(String placeholder, DateTime? value) {
    final selected = value != null;
    return Container(
      height: 39,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? _accent : _chipBorder),
      ),
      child: Text(
        selected ? DateFormat('d MMM').format(value) : placeholder,
        style: GoogleFonts.poppins(
          fontSize: 12,
          letterSpacing: -0.4,
          color: selected ? _periodSel : _ink,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );
  }

  // ==================== DURATION ====================

  Widget _durationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select duration',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: _ink, letterSpacing: -0.4)),
          const SizedBox(height: 16),
          packages.isEmpty
              ? _emptyRow('No packages available')
              : SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: packages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final pkg = packages[i];
                      final fin = _finalPrice(pkg);
                      final orig = _origPrice(pkg);
                      return _durationChip(
                        title: (pkg['name'] ?? '').toString(),
                        price: '₹${_money(fin)}',
                        strike: orig > fin ? '₹${_money(orig)}' : null,
                        selected: i == selectedDurationIndex,
                        onTap: () =>
                            setState(() => selectedDurationIndex = i),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _durationChip({
    required String title,
    required String price,
    String? strike,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? _accent : _chipBorder,
              width: selected ? 1.4 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: -0.4)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(price,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (strike != null) ...[
                  const SizedBox(width: 5),
                  Text(strike,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.black)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== START TIME ====================

  Widget _startTimeCard() {
    final currentSlots = slotGroups.isNotEmpty &&
            selectedPeriodIndex < slotGroups.length
        ? (slotGroups[selectedPeriodIndex]['slots'] as List)
            .cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select start time',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: _ink, letterSpacing: -0.4)),
          const SizedBox(height: 16),
          if (slotGroups.isEmpty)
            _emptyRow('No time slots available')
          else ...[
            _threeColumnRow(List.generate(slotGroups.length, (i) {
              return _periodChip(
                label: _periodLabel(slotGroups[i]['slotType'].toString()),
                selected: i == selectedPeriodIndex,
                onTap: () => setState(() => selectedPeriodIndex = i),
              );
            })),
            const SizedBox(height: 16),
            _dottedLine(),
            const SizedBox(height: 16),
            if (currentSlots.isEmpty)
              _emptyRow('No slots in this period')
            else
              Column(
                children: [
                  for (var i = 0; i < currentSlots.length; i += 3) ...[
                    if (i > 0) const SizedBox(height: 11),
                    _threeColumnRow([
                      for (var c = 0; c < 3; c++)
                        if (i + c < currentSlots.length)
                          _timeChip(currentSlots[i + c]),
                    ]),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _periodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? _accent : _chipBorder,
              width: selected ? 1.4 : 1),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                color: selected ? _periodSel : _ink,
                letterSpacing: -0.4)),
      ),
    );
  }

  Widget _timeChip(Map<String, dynamic> slot) {
    final time = slot['time'] as String;
    final enabled = slot['isAvailable'] == true;
    final selected = selectedTime == time;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? () => setState(() => selectedTime = time) : null,
        child: Container(
          height: 39,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? _accent : _chipBorder,
                width: selected ? 1.4 : 1),
          ),
          child: Text(time,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _ink, letterSpacing: -0.4)),
        ),
      ),
    );
  }

  String _periodLabel(String s) {
    final t = s.toLowerCase();
    return t.isEmpty ? s : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  // ==================== BOTTOM BAR ====================

  Widget _bottomBar() {
    final pkg = _selectedPackage;
    final days = _dayCount == 0 ? 1 : _dayCount;
    final total = pkg != null ? _finalPrice(pkg) * days : 0;
    final strike = pkg != null ? _origPrice(pkg) * days : 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 4,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (strike > total)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text('₹${_money(strike)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black.withOpacity(0.6),
                                  decoration: TextDecoration.lineThrough)),
                        ),
                      Text('₹${_money(total)}',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text('View more',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.6),
                          decoration: TextDecoration.underline)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _canConfirm ? _confirm : null,
                child: Container(
                  height: 56,
                  width: 203,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: _canConfirm ? null : HexColor('#E8E8E8'),
                    gradient: _canConfirm
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_pink, _purple],
                          )
                        : null,
                  ),
                  child: Text('Confirm booking',
                      style: GoogleFonts.dmSans(
                          color:
                              _canConfirm ? Colors.white : HexColor('#B5B5B5'),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final pkg = _selectedPackage!;
    controller.setDateRange(startDate!, endDate ?? startDate);
    controller.setDuration((pkg['name'] ?? '').toString());
    controller.setPackage(
      id: (pkg['_id'] ?? '').toString(),
      name: (pkg['name'] ?? '').toString(),
      price: _finalPrice(pkg),
      originalPrice: _origPrice(pkg),
      minutes: (pkg['durationMinutes'] as num?)?.toInt(),
    );
    controller.setTimeSlot(selectedTime!);
    if (widget.categoryId != null) {
      controller.setCategory(widget.categoryId!, '');
    }
    if (widget.serviceType != null) {
      controller.setServiceType(widget.serviceType!);
    }
    pushTo(context, const CleaningReviewBookingScreen());
  }

  // ==================== SHARED ====================

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }

  Widget _threeColumnRow(List<Widget> children) {
    final cells = <Widget>[];
    for (var c = 0; c < 3; c++) {
      if (c > 0) cells.add(const SizedBox(width: 11));
      cells.add(Expanded(
        child: c < children.length ? children[c] : const SizedBox.shrink(),
      ));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells);
  }

  Widget _dottedLine() {
    return LayoutBuilder(
      builder: (context, cns) {
        const dash = 5.0, gap = 4.0;
        final count = (cns.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1, color: _chipBorder),
          ),
        );
      },
    );
  }

  Widget _emptyRow(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      );
}
