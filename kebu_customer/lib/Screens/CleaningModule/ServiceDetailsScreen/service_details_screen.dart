import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/Screens/BookARideModule/Controller/booking_controller.dart';
import 'package:kebu_customer/Screens/CleaningModule/CleaningReviewBookingScreen/cleaning_review_booking_screen.dart';
import 'package:kebu_customer/Screens/CleaningModule/Controller/household_booking_controller.dart';
import 'package:kebu_customer/Services/household_api_service.dart';
import 'package:kebu_customer/Services/maps_api_service.dart';
import 'package:kebu_customer/Services/user_api_service.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final String? categoryId;
  final String? serviceId;
  final String? serviceType;
  final String? serviceName;
  final String bookingType;
  const ServiceDetailsScreen({
    super.key,
    this.categoryId,
    this.serviceId,
    this.serviceType,
    this.serviceName,
    this.bookingType = 'SINGLE',
  });

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  // ===== Design tokens (Figma node 757:33594) =====
  static final Color _accent = HexColor('#D50069');
  static final Color _cardBorder = HexColor('#BDBDBD');
  static final Color _chipBorder = HexColor('#A9A9A9');
  static final Color _ink = HexColor('#161938');
  static final Color _pink = HexColor('#E61978');
  static final Color _purple = HexColor('#461E98');
  static final Color _periodSel = HexColor('#412190');

  String get _categoryId => widget.categoryId ?? 'default';

  // ----- Backend-driven state -----
  bool isLoading = true;
  bool isSlotsLoading = false;

  /// [{date: DateTime, isAvailable: bool}]
  List<Map<String, dynamic>> availableDates = [];

  /// Raw package maps from /categories/:id/packages
  List<Map<String, dynamic>> packages = [];

  /// [{slotType: 'MORNING', slots: [{time, isAvailable}]}]
  List<Map<String, dynamic>> slotGroups = [];

  // Saved addresses (header + "Change" picker)
  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedAddress;
  bool isDetectingLocation = false;

  int selectedDateIndex = 0;
  int selectedDurationIndex = 0;
  int selectedPeriodIndex = 0;
  String? selectedTime;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final results = await Future.wait([
      HouseholdApiService.getAvailableDates(_categoryId),
      HouseholdApiService.getServicePackages(_categoryId,
          serviceId: widget.serviceId),
      HouseholdApiService.getAvailableTimeSlots(_categoryId),
      UserApiService.getAddresses(),
    ]);
    if (!mounted) return;
    setState(() {
      // Dates
      final dRes = results[0];
      if (dRes.success && dRes.data != null) {
        final raw = (dRes.data['dates'] as List?) ?? const [];
        availableDates = raw.whereType<Map>().map((m) {
          final parsed = DateTime.tryParse((m['date'] ?? '').toString());
          return <String, dynamic>{
            'date': parsed,
            'isAvailable': m['isAvailable'] != false,
          };
        }).where((m) => m['date'] != null).toList();
        final firstAvail =
            availableDates.indexWhere((d) => d['isAvailable'] == true);
        if (firstAvail >= 0) selectedDateIndex = firstAvail;
      }

      // Packages (durations + pricing)
      final pRes = results[1];
      if (pRes.success && pRes.data != null) {
        packages = ((pRes.data['packages'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      // Time slots
      final tRes = results[2];
      if (tRes.success && tRes.data != null) {
        slotGroups = _parseSlotGroups(tRes.data['timeSlots']);
        _applyDefaultTimeSelection();
      }

      // Addresses — GET /user/address returns { page, limit, total, data },
      // so the list lives under `data` (older callers used `addresses`).
      final aRes = results[3];
      if (aRes.success && aRes.data != null) {
        final list =
            (aRes.data['data'] ?? aRes.data['addresses'] ?? const []) as List?;
        savedAddresses = (list ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (savedAddresses.isNotEmpty) {
          selectedAddress = savedAddresses.firstWhere(
            (a) => a['isDefault'] == true || a['isSelected'] == true,
            orElse: () => savedAddresses.first,
          );
        }
      }

      isLoading = false;
    });

    // No saved address on file — resolve the current location for the header.
    if (selectedAddress == null) _resolveLocation();
  }

  /// Prefer the location the app already fetched at startup (held by the
  /// permanent BookingController) so the header is populated instantly with no
  /// GPS delay. Only fall back to a fresh fix if that isn't ready yet.
  void _resolveLocation() {
    try {
      final bc = Get.find<BookingController>();
      final lat = bc.pickupLat.value;
      final lng = bc.pickupLng.value;
      if (lat != 0 && lng != 0) {
        final addr = bc.pickupAddress.value.trim();
        setState(() {
          selectedAddress = {
            'addressType': 'Current',
            'area': addr.isNotEmpty ? addr.split(',').first.trim() : '',
            'city': '',
            'address': addr,
            'latitude': lat,
            'longitude': lng,
          };
          isDetectingLocation = false;
        });
        // Clean up the label in the background (no GPS wait).
        if (addr.isEmpty) _refineAreaFrom(lat, lng);
        return;
      }
    } catch (_) {
      // BookingController not registered — fall through to GPS detection.
    }
    _detectCurrentLocation();
  }

  /// Reverse-geocode coordinates and update just the area label.
  Future<void> _refineAreaFrom(double lat, double lng) async {
    final res = await MapsApiService.reverseGeocode(lat: lat, lng: lng);
    if (!mounted || !(res.success && res.data != null)) return;
    final d = res.data;
    final area = (d['area'] ?? d['city'] ?? '').toString();
    if (area.isEmpty || selectedAddress == null) return;
    setState(() {
      selectedAddress = {
        ...selectedAddress!,
        'area': area,
        'city': (d['city'] ?? '').toString(),
      };
    });
  }

  Future<void> _detectCurrentLocation() async {
    if (mounted) setState(() => isDetectingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => isDetectingLocation = false);
        return;
      }

      // 1) Fast path — show the last known fix immediately (usually instant).
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        await _applyPosition(last, stopSpinner: false);
      }

      // 2) Refine with a fresh fix (medium accuracy + short timeout = fast).
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        await _applyPosition(fresh, stopSpinner: true);
      } catch (_) {
        // Fresh fix timed out — keep whatever the last-known gave us.
        if (mounted) setState(() => isDetectingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => isDetectingLocation = false);
    }
  }

  /// Reverse-geocode [pos] and populate the header address.
  Future<void> _applyPosition(Position pos, {required bool stopSpinner}) async {
    final res = await MapsApiService.reverseGeocode(
        lat: pos.latitude, lng: pos.longitude);
    if (!mounted) return;
    final d = (res.success && res.data != null) ? res.data : null;
    final area = (d?['area'] ?? '').toString();
    final city = (d?['city'] ?? '').toString();
    final full = (d?['address'] ?? d?['display_name'] ?? '').toString();
    final label = area.isNotEmpty
        ? area
        : city.isNotEmpty
            ? city
            : full.isNotEmpty
                ? full.split(',').first.trim()
                : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    setState(() {
      selectedAddress = {
        'addressType': 'Current',
        'area': label,
        'city': city,
        'address': full.isNotEmpty ? full : label,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      };
      if (stopSpinner) isDetectingLocation = false;
    });
  }

  /// Slot availability depends on the chosen date, so re-fetch slots whenever
  /// the date changes.
  Future<void> _reloadSlotsForSelectedDate() async {
    final date = _selectedDate;
    if (date == null) return;
    setState(() => isSlotsLoading = true);
    final iso = DateFormat('yyyy-MM-dd').format(date);
    final res =
        await HouseholdApiService.getAvailableTimeSlots(_categoryId, date: iso);
    if (!mounted) return;
    setState(() {
      if (res.success && res.data != null) {
        slotGroups = _parseSlotGroups(res.data['timeSlots']);
        _applyDefaultTimeSelection();
      }
      isSlotsLoading = false;
    });
  }

  List<Map<String, dynamic>> _parseSlotGroups(dynamic raw) {
    final list = (raw as List?) ?? const [];
    return list.whereType<Map>().map((g) {
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

  /// Pick the first period that has an available slot and select that slot.
  void _applyDefaultTimeSelection() {
    selectedTime = null;
    if (slotGroups.isEmpty) {
      selectedPeriodIndex = 0;
      return;
    }
    for (var i = 0; i < slotGroups.length; i++) {
      final slots = (slotGroups[i]['slots'] as List).cast<Map<String, dynamic>>();
      final firstAvail = slots.firstWhere(
        (s) => s['isAvailable'] == true,
        orElse: () => const {},
      );
      if (firstAvail.isNotEmpty) {
        selectedPeriodIndex = i;
        selectedTime = firstAvail['time'] as String;
        return;
      }
    }
    selectedPeriodIndex = 0;
  }

  // ----- Derived getters -----
  DateTime? get _selectedDate => availableDates.isNotEmpty &&
          selectedDateIndex < availableDates.length
      ? availableDates[selectedDateIndex]['date'] as DateTime?
      : null;

  Map<String, dynamic>? get _selectedPackage =>
      packages.isNotEmpty && selectedDurationIndex < packages.length
          ? packages[selectedDurationIndex]
          : null;

  /// Display + strike price for a package, honouring any applied offer.
  ({String price, String? strike}) _packagePricing(Map<String, dynamic> pkg) {
    final original = pkg['originalPrice'];
    final discounted = pkg['discountedPrice'];
    final offer = pkg['appliedOffer'] as Map?;
    final display = offer != null ? offer['finalPrice'] : (discounted ?? original);
    final strikeVal = (original != null && original != display)
        ? original
        : (discounted != null && discounted != display ? discounted : null);
    return (
      price: '₹${_fmt(display)}',
      strike: strikeVal != null ? '₹${_fmt(strikeVal)}' : null,
    );
  }

  String _fmt(dynamic n) {
    if (n is num) {
      return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
    }
    return (n ?? 0).toString();
  }

  String _periodLabel(String slotType) {
    final t = slotType.toLowerCase();
    if (t.isEmpty) return slotType;
    return '${t[0].toUpperCase()}${t.substring(1)}';
  }

  String get _addressTitle {
    final a = selectedAddress;
    if (a == null) {
      return isDetectingLocation ? 'Detecting location…' : 'Select address';
    }
    final type = (a['addressType'] ?? 'Home').toString();
    final area = (a['area'] ?? a['city'] ?? a['address'] ?? '').toString();
    if (area.isEmpty) {
      return type.toLowerCase() == 'current' ? 'Current location' : type;
    }
    final label = type.toLowerCase() == 'current' ? 'Current' : type;
    return '$label | $area';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final gradientH = topInset + 96;
    final cardTop = topInset + 78;
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _bottomBar(),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // Gradient header background
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
            // White sheet
            Container(
              margin: EdgeInsets.only(top: cardTop),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('choose service details',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: _ink,
                              letterSpacing: -0.4)),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _dateCard(),
                    _durationCard(),
                    _startTimeCard(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            // Header row (back, title, change) over the gradient
            Positioned(
              top: topInset + 6,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _addressTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openAddressPicker,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
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
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SELECT DATE ====================

  Widget _dateCard() {
    final w = MediaQuery.of(context).size.width;
    final chipW = (w - 32 - 30 - 56) / 5; // margins, padding, 4 gaps of 14
    return _card(
      title: 'Select Date',
      child: availableDates.isEmpty
          ? _emptyRow('No dates available')
          : SizedBox(
              height: 61,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableDates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final d = availableDates[i]['date'] as DateTime;
                  final available = availableDates[i]['isAvailable'] == true;
                  final isToday = DateUtils.isSameDay(d, DateTime.now());
                  final label = isToday ? 'Today' : DateFormat('EEE').format(d);
                  return _dayChip(
                    width: chipW,
                    top: label,
                    bottom: d.day.toString(),
                    selected: i == selectedDateIndex,
                    enabled: available,
                    onTap: () {
                      setState(() => selectedDateIndex = i);
                      _reloadSlotsForSelectedDate();
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _dayChip({
    required double width,
    required String top,
    required String bottom,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: width,
          alignment: Alignment.center,
          decoration: _chipDecoration(selected),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(top, style: GoogleFonts.poppins(fontSize: 12, color: _ink)),
              const SizedBox(height: 2),
              Text(bottom,
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: _ink, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SELECT DURATION ====================

  Widget _durationCard() {
    return _card(
      title: 'Select Duration',
      child: packages.isEmpty
          ? _emptyRow('No packages available')
          : SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: packages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final pkg = packages[i];
                  final pricing = _packagePricing(pkg);
                  return _durationChip(
                    title: (pkg['name'] ?? '').toString(),
                    price: pricing.price,
                    strike: pricing.strike,
                    selected: i == selectedDurationIndex,
                    onTap: () => setState(() => selectedDurationIndex = i),
                  );
                },
              ),
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
        decoration: _chipDecoration(selected, radius: 14),
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

  // ==================== SELECT START TIME ====================

  Widget _startTimeCard() {
    final currentSlots = slotGroups.isNotEmpty &&
            selectedPeriodIndex < slotGroups.length
        ? (slotGroups[selectedPeriodIndex]['slots'] as List)
            .cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    return _card(
      title: 'Select Start Time',
      child: slotGroups.isEmpty
          ? _emptyRow('No time slots available')
          : Column(
              children: [
                _threeColumnRow(
                  List.generate(slotGroups.length, (i) {
                    return _periodChip(
                      label:
                          _periodLabel(slotGroups[i]['slotType'].toString()),
                      selected: i == selectedPeriodIndex,
                      onTap: () => setState(() => selectedPeriodIndex = i),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                _dottedDivider(),
                const SizedBox(height: 16),
                if (isSlotsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (currentSlots.isEmpty)
                  _emptyRow('No slots in this period')
                else
                  _timeGrid(currentSlots),
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
        decoration: _chipDecoration(selected),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                color: selected ? _periodSel : _ink,
                letterSpacing: -0.4)),
      ),
    );
  }

  Widget _timeChip({
    required String time,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 39,
          alignment: Alignment.center,
          decoration: _chipDecoration(selected),
          child: Text(time,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _ink, letterSpacing: -0.4)),
        ),
      ),
    );
  }

  /// Lay out time slots in a fixed 3-column grid (matches Figma). Using
  /// Expanded columns instead of a width-computed Wrap guarantees exactly
  /// three aligned columns on every device — no rounding-induced 2-col wrap.
  Widget _timeGrid(List<Map<String, dynamic>> slots) {
    return Column(
      children: [
        for (var i = 0; i < slots.length; i += 3) ...[
          if (i > 0) const SizedBox(height: 11),
          _threeColumnRow([
            for (var c = 0; c < 3; c++)
              if (i + c < slots.length)
                _timeChip(
                  time: slots[i + c]['time'] as String,
                  selected: selectedTime == slots[i + c]['time'],
                  enabled: slots[i + c]['isAvailable'] == true,
                  onTap: () =>
                      setState(() => selectedTime = slots[i + c]['time'] as String),
                ),
          ]),
        ],
      ],
    );
  }

  /// A row of up to three children laid out as equal columns with 11px gaps,
  /// padding the last row with empty cells so chips keep a consistent width.
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

  // ==================== BOTTOM BAR ====================

  Widget _bottomBar() {
    final pkg = _selectedPackage;
    final pricing = pkg != null ? _packagePricing(pkg) : null;
    final canConfirm = !isLoading &&
        _selectedDate != null &&
        pkg != null &&
        selectedTime != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 4,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (pricing != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (pricing.strike != null) ...[
                    Text(pricing.strike!,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.6),
                            decoration: TextDecoration.lineThrough)),
                    const SizedBox(width: 10),
                  ],
                  Text(pricing.price,
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              )
            else
              const SizedBox.shrink(),
            GestureDetector(
              onTap: canConfirm ? _confirmBooking : null,
              child: Opacity(
                opacity: canConfirm ? 1 : 0.5,
                child: Container(
                  height: 56,
                  width: 203,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_pink, _purple],
                    ),
                  ),
                  child: Text('Confirm booking',
                      style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Numeric payable price for a package (offer → discounted → original).
  double _numericPrice(Map<String, dynamic> pkg) {
    final offer = pkg['appliedOffer'] as Map?;
    final v = offer != null
        ? offer['finalPrice']
        : (pkg['discountedPrice'] ?? pkg['originalPrice'] ?? 0);
    return (v as num?)?.toDouble() ?? 0;
  }

  void _confirmBooking() {
    final controller = Get.find<HouseholdBookingController>();
    final pkg = _selectedPackage!;
    controller.setDuration((pkg['name'] ?? '').toString());
    controller.setPackage(
      id: (pkg['_id'] ?? '').toString(),
      name: (pkg['name'] ?? '').toString(),
      price: _numericPrice(pkg),
      originalPrice: (pkg['originalPrice'] as num?)?.toDouble(),
      minutes: (pkg['durationMinutes'] as num?)?.toInt(),
    );
    controller.setAddressLabel(_addressTitle);
    controller.setTimeSlot(selectedTime!);
    final date = _selectedDate;
    if (date != null) controller.setDate(date);
    if (widget.categoryId != null) {
      controller.setCategory(widget.categoryId!, '');
    }
    if (widget.serviceType != null) {
      controller.setServiceType(widget.serviceType!, widget.serviceName);
    } else if ((widget.serviceName ?? '').isNotEmpty) {
      controller.serviceName.value = widget.serviceName!;
    }
    final a = selectedAddress;
    if (a != null) {
      controller.setAddress(
        (a['address'] ?? a['area'] ?? '').toString(),
        (a['latitude'] ?? 0).toDouble(),
        (a['longitude'] ?? 0).toDouble(),
      );
    }
    pushTo(context, const CleaningReviewBookingScreen());
  }

  // ==================== ADDRESS PICKER ====================

  void _openAddressPicker() {
    if (savedAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved addresses found')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Select address',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...savedAddresses.map((a) {
              final type = (a['addressType'] ?? 'Home').toString();
              final full = (a['address'] ??
                      [a['houseNo'], a['area'], a['city']]
                          .where((e) => (e ?? '').toString().isNotEmpty)
                          .join(', '))
                  .toString();
              final isSel = identical(a, selectedAddress);
              return ListTile(
                leading: Icon(
                  type.toLowerCase() == 'work'
                      ? Icons.work_outline
                      : Icons.home_outlined,
                  color: _accent,
                ),
                title: Text(type,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(full,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.black54)),
                trailing:
                    isSel ? Icon(Icons.check_circle, color: _accent) : null,
                onTap: () {
                  setState(() => selectedAddress = a);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== SHARED ====================

  BoxDecoration _chipDecoration(bool selected, {double radius = 10}) {
    return BoxDecoration(
      color: selected ? Colors.white.withOpacity(0.5) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: selected ? _accent : _chipBorder, width: selected ? 1.4 : 1),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 19),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: _ink, letterSpacing: -0.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _dottedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
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

  Widget _emptyRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
    );
  }
}
