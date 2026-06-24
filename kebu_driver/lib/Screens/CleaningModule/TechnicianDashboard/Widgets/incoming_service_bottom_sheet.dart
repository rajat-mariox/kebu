import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/start_customer_direction.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';

class IncomingServiceBottomSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final int countdownSeconds;

  const IncomingServiceBottomSheet({
    super.key,
    required this.booking,
    this.countdownSeconds = 180,
  });

  @override
  State<IncomingServiceBottomSheet> createState() => _IncomingServiceBottomSheetState();
}

class _IncomingServiceBottomSheetState extends State<IncomingServiceBottomSheet> {
  Timer? _timer;
  late int _remaining;
  bool _submitting = false;
  StreamSubscription<Map<String, dynamic>>? _takenSub;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _startRinging();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        _stopRinging();
        Navigator.of(context).maybePop();
      } else {
        setState(() => _remaining -= 1);
      }
    });

    // Auto-dismiss if another provider grabs this booking
    _takenSub = SocketService().onServiceBookingTaken.listen((data) {
      final takenId = data['bookingId']?.toString();
      if (takenId == widget.booking['_id']?.toString() && mounted) {
        _stopRinging();
        Fluttertoast.showToast(msg: "Job taken by another provider");
        Navigator.of(context).maybePop();
      }
    });
  }

  void _startRinging() {
    HapticFeedback.heavyImpact();
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.electronic,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (_) {}
  }

  void _stopRinging() {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopRinging();
    _timer?.cancel();
    _takenSub?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_submitting) return;
    final bookingId = widget.booking['_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) return;

    setState(() => _submitting = true);
    final res = await DriverApiService.acceptServiceBooking(bookingId);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.success) {
      _stopRinging();
      Navigator.of(context).pop();
      // The accept response carries the booking + customer contact + booking
      // number + category name; pass it straight to the direction screen.
      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{'booking': widget.booking};
      pushTo(context, StartCustomerDirection(data: data));
    } else {
      Fluttertoast.showToast(msg: res.message.isNotEmpty ? res.message : "Could not accept");
    }
  }

  num? get _amountValue {
    final v = widget.booking['finalCost'] ??
        widget.booking['estimatedCost'] ??
        widget.booking['actualCost'];
    return (v is num) ? v : null;
  }

  String get _amount {
    final v = _amountValue;
    return v == null ? "—" : "₹ $v";
  }

  String get _paymentMethod {
    return (widget.booking['paymentMethod'] ?? 'CASH').toString();
  }

  String get _serviceType {
    return (widget.booking['serviceType'] ??
            widget.booking['description'] ??
            'Household Service')
        .toString();
  }

  /// Category name when the booking payload includes a populated category,
  /// otherwise falls back to the service type.
  String get _category {
    final cat = widget.booking['categoryId'] ?? widget.booking['category'];
    if (cat is Map && (cat['name'] ?? '').toString().isNotEmpty) {
      return cat['name'].toString();
    }
    final c = (widget.booking['categoryName'] ?? '').toString();
    return c.isNotEmpty ? c : _serviceType;
  }

  String get _description {
    return (widget.booking['description'] ?? '').toString();
  }

  int? get _durationMinutes {
    final d = widget.booking['estimatedDuration'];
    if (d is num) return d.toInt();
    return null;
  }

  Map<String, dynamic>? get _address {
    final a = widget.booking['address'];
    if (a is Map) return Map<String, dynamic>.from(a);
    return null;
  }

  String get _fullAddress {
    final a = _address;
    if (a == null) return 'Address not provided';
    return (a['fullAddress'] ?? a['address'] ?? '—').toString();
  }

  String get _landmark {
    final a = _address;
    if (a == null) return '';
    return (a['landmark'] ?? '').toString();
  }

  /// "X Km away" when the booking payload carries a distance, else empty.
  String get _distanceText {
    final d = widget.booking['distance'] ??
        widget.booking['distanceKm'] ??
        widget.booking['distanceInKm'];
    if (d is num) {
      final km = d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
      return "$km Km away";
    }
    final t = (widget.booking['distanceText'] ?? '').toString();
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _durationMinutes;
    return Container(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 50),
            decoration: BoxDecoration(
              color: HexColor("#FBFBFB"),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Total amount section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "Total Amount",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _amount,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "Payment method : $_paymentMethod",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              minutes != null ? "Est time : $minutes Mins" : "Est time : 0 Mins",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF275FC8),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Service details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              const TextSpan(text: "Service details - "),
                              TextSpan(
                                text: _category,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _description.isNotEmpty ? _description : _serviceType,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Address timeline (landmark → full address) with distance
                  _buildAddressTimeline(),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HexColor("#2C54C1"),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _submitting ? null : _accept,
                          child: _submitting
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  "Accept Service",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: HexColor("#2C54C1")),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            _stopRinging();
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Ignore",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2F5AE3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2F5AE3), width: 3),
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: Text(
              _formatCountdown(_remaining),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(int s) {
    final m = (s ~/ 60).toString().padLeft(1, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return "$m : $ss";
  }

  /// Two-stop address timeline matching the Figma: the landmark (with the
  /// distance on the right) connected by a dotted line to the full address.
  /// Falls back to a single stop when there's no landmark.
  Widget _buildAddressTimeline() {
    final landmark = _landmark;
    final fullAddress = _fullAddress;
    final hasTwo = landmark.isNotEmpty && landmark != fullAddress;

    if (!hasTwo) {
      return _addressRow(
        dotFilled: true,
        text: fullAddress,
        distance: _distanceText,
        showConnectorBelow: false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _addressRow(
          dotFilled: true,
          text: landmark,
          distance: _distanceText,
          showConnectorBelow: true,
        ),
        _addressRow(
          dotFilled: false,
          text: fullAddress,
          distance: '',
          showConnectorBelow: false,
        ),
      ],
    );
  }

  Widget _addressRow({
    required bool dotFilled,
    required String text,
    required String distance,
    required bool showConnectorBelow,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 14,
                width: 14,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotFilled ? HexColor("#275FC8") : Colors.white,
                  border: Border.all(color: HexColor("#275FC8"), width: 3),
                ),
              ),
              if (showConnectorBelow)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: HexColor("#275FC8").withOpacity(0.4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnectorBelow ? 16 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        height: 1.35,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  if (distance.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 1),
                      child: Text(
                        distance,
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
