import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kebu_customer/AppNavigation/app_navigation.dart';
import 'package:kebu_customer/CommonWidgets/notification_icon_button.dart';
import 'package:kebu_customer/Screens/SendParcelModule/LoadingPointScreen/loading_point_screen.dart';
import 'package:kebu_customer/Screens/SendParcelModule/OrderDetailsScreen/order_details_screen.dart';
import 'package:table_calendar/table_calendar.dart';

class ConfirmLocationScreen extends StatefulWidget {
  final String vehicleTypeId;
  final String vehicleName;
  // 'INSTANT' or 'SCHEDULED' — chosen on the previous "What would you like to
  // do?" sheet. Scheduling (calendar + time) is only shown for 'SCHEDULED'.
  final String deliveryMode;
  const ConfirmLocationScreen({
    super.key,
    this.vehicleTypeId = '',
    this.vehicleName = '',
    this.deliveryMode = 'INSTANT',
  });

  @override
  State<ConfirmLocationScreen> createState() => _ConfirmLocationScreenState();
}

class _ConfirmLocationScreenState extends State<ConfirmLocationScreen> {
  static const Color _brandRed = Color(0xFFDE1A21);
  static const Color _dark = Color(0xFF1B1D21);

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  int _workers = 0;

  // Loading (pickup) and Unloading (drop) points chosen via the map picker.
  Map<String, dynamic>? _pickup;
  Map<String, dynamic>? _drop;

  // Pick-time options shown as pills.
  final List<String> _times = ['07:00 AM', '11:00 AM', '12:00 AM'];
  int _selectedTime = -1;

  bool get _isScheduled => widget.deliveryMode == 'SCHEDULED';

  /// Combine the chosen day + time pill into an ISO timestamp for the backend.
  String? _buildScheduledAt() {
    if (!_isScheduled || _selectedDay == null || _selectedTime < 0) return null;
    final parsed = _parseTime(_times[_selectedTime]);
    final d = _selectedDay!;
    final dt = DateTime(d.year, d.month, d.day, parsed.$1, parsed.$2);
    return dt.toUtc().toIso8601String();
  }

  (int, int) _parseTime(String label) {
    // "07:00 AM" -> (7, 0); "12:00 AM" -> (0, 0)
    final parts = label.split(' ');
    final hm = parts[0].split(':');
    var hour = int.parse(hm[0]);
    final minute = int.parse(hm[1]);
    final isPm = parts[1].toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    return (hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandRed,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF52059), Color(0xFFD91916)],
            stops: [0.0, 0.19],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(26, 24, 26, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _title(),
                              const SizedBox(height: 10),
                              _subtitle(),
                              const SizedBox(height: 22),
                              _locationBox(),
                              if (_isScheduled) ...[
                                const SizedBox(height: 26),
                                _calendar(),
                                const SizedBox(height: 22),
                                _pickTime(),
                              ],
                              const SizedBox(height: 22),
                              const Divider(
                                  height: 1, color: Color(0x1A040415)),
                              const SizedBox(height: 18),
                              _workersRow(),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      _proceedButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
          ),
          Expanded(
            child: Text(
              "Confirm Location",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const NotificationIconButton(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Title + subtitle
  // ---------------------------------------------------------------------------
  Widget _title() {
    return Text(
      "Location",
      style: GoogleFonts.dmSans(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: _dark,
        letterSpacing: -1.6,
      ),
    );
  }

  Widget _subtitle() {
    return Text.rich(
      TextSpan(
        text: "Please choose your destination location accurately. "
            "For any info call ",
        style: GoogleFonts.dmSans(
          color: const Color(0xFF878787),
          fontSize: 16,
          height: 26 / 16,
          letterSpacing: -0.36,
        ),
        children: [
          TextSpan(
            text: "+91 8178 496 252",
            style: GoogleFonts.dmSans(
              color: const Color(0xFFF62059),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.36,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / Unloading point box
  // ---------------------------------------------------------------------------
  Widget _locationBox() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E6EA)),
      ),
      child: Column(
        children: [
          _pointTile(
            icon: _loadingPointIcon(),
            label: "Loading Point",
            address: _pickup?['address'] as String?,
            onTap: () => _pickPoint("Loading Point", isPickup: true),
          ),
          const Divider(
              height: 1, thickness: 1, indent: 26, endIndent: 26,
              color: Color(0x1A040415)),
          _pointTile(
            icon: SvgPicture.asset(
              "assets/figma_unloading_point.svg",
              width: 24,
              height: 24,
            ),
            label: "Unloading Point",
            address: _drop?['address'] as String?,
            onTap: () => _pickPoint("Unloading Point", isPickup: false),
          ),
        ],
      ),
    );
  }

  // Opens the map picker and stores the returned {lat,lng,address}.
  Future<void> _pickPoint(String title, {required bool isPickup}) async {
    final result = await pushTo(context, LoadingPointScreen(title: title));
    if (result is Map && result['lat'] != 0) {
      setState(() {
        final point = {
          'lat': result['lat'],
          'lng': result['lng'],
          'address': result['address'],
        };
        if (isPickup) {
          _pickup = point;
        } else {
          _drop = point;
        }
      });
    }
  }

  // Black bullseye / target used for the Loading Point.
  Widget _loadingPointIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: _dark, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: 8.7,
        height: 8.7,
        decoration: const BoxDecoration(
            color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }

  Widget _pointTile({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    String? address,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: Center(child: icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _dark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF878787),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15, color: _dark),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar
  // ---------------------------------------------------------------------------
  Widget _calendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const dowLabels = {
      1: 'Mo', 2: 'Tu', 3: 'We', 4: 'Th', 5: 'Fr', 6: 'Sa', 7: 'Su'
    };
    return Column(
      children: [
        // Red pill month header
        Container(
          decoration: BoxDecoration(
            color: _brandRed,
            borderRadius: BorderRadius.circular(90),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _calArrow(Icons.arrow_back, () {
                setState(() => _focusedDay =
                    DateTime(_focusedDay.year, _focusedDay.month - 1, 1));
              }),
              Text(
                "${_monthName(_focusedDay.month)}, ${_focusedDay.year}",
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFFCFCFD),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _calArrow(Icons.arrow_forward, () {
                setState(() => _focusedDay =
                    DateTime(_focusedDay.year, _focusedDay.month + 1, 1));
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerVisible: false,
          rowHeight: 44,
          daysOfWeekHeight: 28,
          enabledDayPredicate: (day) => !day.isBefore(today),
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
          calendarStyle: CalendarStyle(
            isTodayHighlighted: false,
            outsideDaysVisible: false,
            defaultTextStyle: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
            weekendTextStyle: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
            disabledTextStyle: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _dark.withOpacity(0.3)),
            selectedDecoration:
                const BoxDecoration(color: _brandRed, shape: BoxShape.circle),
            selectedTextStyle: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            dowTextFormatter: (date, locale) => dowLabels[date.weekday]!,
            weekdayStyle: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF6628)),
            weekendStyle: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF6628)),
          ),
        ),
      ],
    );
  }

  Widget _calArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pick time
  // ---------------------------------------------------------------------------
  Widget _pickTime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pick time",
          style: GoogleFonts.dmSans(
            fontSize: 16,
            height: 26 / 16,
            color: const Color(0xFF040415).withOpacity(0.4),
            letterSpacing: -0.36,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (int i = 0; i < _times.length; i++) ...[
                _timeChip(i),
                if (i != _times.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeChip(int index) {
    final selected = _selectedTime == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = index),
      child: Container(
        width: 128,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(90),
          border: Border.all(
            color: selected ? _brandRed : const Color(0xFFE6E8EC),
            width: 2,
          ),
        ),
        child: Text(
          _times[index],
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: selected ? _brandRed : const Color(0xFF23262F),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Workers
  // ---------------------------------------------------------------------------
  Widget _workersRow() {
    return Row(
      children: [
        Container(
          width: 53,
          height: 53,
          decoration: const BoxDecoration(
            color: Color(0xFFFCE9EC),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Image.asset("assets/electrical_worker.png",
              width: 30, height: 30, fit: BoxFit.contain),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Workers",
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _dark,
                  letterSpacing: -0.36,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Regular cost is \$5/hr. Total cost will be calculated later",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFFD9D9D9),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _counterButton(Icons.remove, () {
          if (_workers > 0) setState(() => _workers--);
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "$_workers",
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _dark,
            ),
          ),
        ),
        _counterButton(Icons.add, () => setState(() => _workers++)),
      ],
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF8F92A1).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1B1D21)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Proceed
  // ---------------------------------------------------------------------------
  Widget _proceedButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandRed,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _onProceed,
          child: Text(
            "Proceed",
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }

  void _onProceed() {
    if (_pickup == null || _drop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please choose both loading and unloading points"),
        ),
      );
      return;
    }
    pushTo(
      context,
      OrderDetailsScreen(
        vehicleTypeId: widget.vehicleTypeId,
        deliveryMode: widget.deliveryMode,
        workers: _workers,
        scheduledAt: _buildScheduledAt(),
        pickupLat: (_pickup!['lat'] as num).toDouble(),
        pickupLng: (_pickup!['lng'] as num).toDouble(),
        pickupAddress: _pickup!['address'] as String,
        dropLat: (_drop!['lat'] as num).toDouble(),
        dropLng: (_drop!['lng'] as num).toDouble(),
        dropAddress: _drop!['address'] as String,
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
