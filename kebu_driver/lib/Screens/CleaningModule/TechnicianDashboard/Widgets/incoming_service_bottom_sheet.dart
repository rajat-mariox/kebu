import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/start_customer_direction.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';

class IncomingServiceBottomSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final int countdownSeconds;

  const IncomingServiceBottomSheet({
    super.key,
    required this.booking,
    this.countdownSeconds = 30,
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
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (_) => const StartCustomerDirection(),
      );
    } else {
      Fluttertoast.showToast(msg: res.message.isNotEmpty ? res.message : "Could not accept");
    }
  }

  String get _amount {
    final v = widget.booking['estimatedCost'] ?? widget.booking['actualCost'] ?? widget.booking['finalCost'];
    if (v == null) return "—";
    return "₹ $v";
  }

  String get _paymentMethod {
    return (widget.booking['paymentMethod'] ?? 'CASH').toString();
  }

  String get _serviceType {
    return (widget.booking['serviceType'] ?? widget.booking['description'] ?? 'Household Service').toString();
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 17),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 10),
                            const Text(
                              "Total Amount",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _amount,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const SizedBox(width: 10),
                            Text(
                              "Payment Method : $_paymentMethod",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              minutes != null ? "Est Time : $minutes Mins" : "Est Time : —",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2F5AE3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Service: $_serviceType",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        if (_description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _description,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Address
                  buildAddress(_fullAddress, '', true, context),

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

  Widget buildAddress(String address, String distance, bool selected, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 18,
          width: 18,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border.all(color: HexColor("#275FC8"), width: 5),
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w400),
                ),
              ),
              if (distance.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    distance,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
