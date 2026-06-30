import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/CommonWidgets/cleaning_app_bar.dart';
import 'package:kebu_driver/Screens/CleaningModule/ReceivePaymentScreen/received_payment_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';
import 'package:kebu_driver/Services/socket_service.dart';
import 'package:kebu_driver/Utils/CustomToast/custome_toast.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// "Receive Payment" — shown after the partner ends the work. Fully data-driven
/// from the complete-service response `payment` object: the amount to collect,
/// the duration of the service and the scan-&-pay QR payload. Matches the Figma
/// "Receive Payment" design.
class ReceivePaymentScreen extends StatefulWidget {
  /// The complete-service response: { booking, payment }.
  final Map<String, dynamic> data;

  const ReceivePaymentScreen({super.key, this.data = const {}});

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  StreamSubscription<Map<String, dynamic>>? _paySub;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Online (QR/UPI) payments are confirmed server-side — flip to the success
    // screen the moment the backend reports THIS booking paid.
    _paySub = SocketService().onServicePaymentReceived.listen((data) {
      final id = data['bookingId']?.toString();
      if (id != null && id == _bookingId) _goToSuccess();
    });
  }

  @override
  void dispose() {
    _paySub?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _payment {
    final p = widget.data['payment'];
    return (p is Map) ? Map<String, dynamic>.from(p) : {};
  }

  Map<String, dynamic> get _booking {
    final b = widget.data['booking'];
    return (b is Map) ? Map<String, dynamic>.from(b) : {};
  }

  String get _amountLabel => (_payment['amountLabel'] ?? '—').toString();
  String get _durationLabel => (_payment['durationLabel'] ?? '').toString();
  String get _qrData => (_payment['qrData'] ?? '').toString();
  num get _extraAmount {
    final v = _payment['extraAmount'];
    return (v is num) ? v : 0;
  }
  String get _bookingId => (_booking['_id'] ?? '').toString();
  bool get _isCash =>
      (_booking['paymentMethod'] ?? '').toString().toUpperCase() == 'CASH';

  void _goToSuccess() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ReceivedPaymentScreen()),
    );
  }

  /// Cash collected → mark the booking PAID, then show the "Received payment"
  /// success screen. (The customer gets the "Thank you" popup on their app.)
  Future<void> _collectCash() async {
    if (_bookingId.isEmpty) {
      showCustomToast(context, 'Booking not found');
      return;
    }
    final res = await DriverApiService.markServicePaymentReceived(_bookingId);
    if (!mounted) return;
    if (res.success) {
      _goToSuccess();
    } else {
      showCustomToast(
          context, res.message.isNotEmpty ? res.message : 'Could not confirm payment');
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkBlue = HexColor("#132235");

    return Scaffold(
      backgroundColor: Colors.white,
      // Cash bookings get a slide-to-collect confirm bar; online bookings rely
      // on the customer scanning the QR above.
      bottomNavigationBar: _isCash
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _SlideToAction(
                label: "Slide to collect cash",
                onComplete: _collectCash,
              ),
            )
          : null,
      body: Stack(
        children: [
          cleaningAppBar(
            height: 160,
            context: context,
            child: Container(
              padding: const EdgeInsets.only(top: 60, left: 15, right: 15),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text("Receive Payment",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 110),
            child: Column(
              children: [
                // Amount banner (green)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: HexColor("#08875D"),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text("Amount to be Collected",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_amountLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          const Icon(Icons.info_outline,
                              color: Colors.white, size: 20),
                        ],
                      ),
                      if (_extraAmount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Includes extra ₹$_extraAmount",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),

                // Duration card
                if (_durationLabel.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(7, 16, 7, 0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: HexColor("#F0F5FF"),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: HexColor("#2F6FED").withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text("DURATION OF USE",
                            style: TextStyle(
                                color: HexColor("#2F6FED"), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(_durationLabel,
                            style: TextStyle(
                                color: HexColor("#2F6FED"),
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                Text("QR Code",
                    style: TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 20)),
                const SizedBox(height: 8),
                Text("Scan & Pay",
                    style: TextStyle(color: HexColor("#364B63"), fontSize: 15)),
                const SizedBox(height: 20),

                _qrData.isEmpty
                    ? const SizedBox(
                        height: 200,
                        child: Center(
                            child: Text("Payment QR unavailable",
                                style: TextStyle(color: Colors.grey))),
                      )
                    : QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide-to-confirm bar. Drag the thumb past ~85% to fire [onComplete]; shows a
/// spinner on the thumb while the action runs.
class _SlideToAction extends StatefulWidget {
  final String label;
  final Future<void> Function() onComplete;

  const _SlideToAction({required this.label, required this.onComplete});

  @override
  State<_SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<_SlideToAction> {
  double _dx = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final green = HexColor("#08875D");
    const thumb = 56.0;
    return LayoutBuilder(
      builder: (context, c) {
        final maxDx = (c.maxWidth - thumb).clamp(0.0, double.infinity);
        return Container(
          height: thumb,
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: thumb),
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: _dx),
                  child: GestureDetector(
                    onHorizontalDragUpdate: _busy
                        ? null
                        : (d) => setState(
                            () => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx)),
                    onHorizontalDragEnd: _busy
                        ? null
                        : (_) async {
                            if (_dx >= maxDx * 0.85) {
                              setState(() {
                                _dx = maxDx;
                                _busy = true;
                              });
                              await widget.onComplete();
                              if (mounted) {
                                setState(() {
                                  _busy = false;
                                  _dx = 0;
                                });
                              }
                            } else {
                              setState(() => _dx = 0);
                            }
                          },
                    child: Container(
                      height: thumb,
                      width: thumb,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _busy
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(green),
                              ),
                            )
                          : Icon(Icons.keyboard_double_arrow_right,
                              color: green, size: 26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
