import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/google_map_widget.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/customer_direction_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';
import 'package:kebu_driver/Services/socket_service.dart';

/// Shown right after a household partner accepts a service.
///
/// Fully backend-driven: every field comes from the `accept` response payload
/// (`{ booking, customer, bookingNumber, categoryName }`) via [DirectionData].
/// A map pins the customer's location; "Start customer direction" moves the
/// partner to the en-route navigation screen. Matches the Figma design.
class StartCustomerDirection extends StatefulWidget {
  /// The accept-service response: { booking, customer, bookingNumber, categoryName }.
  final Map<String, dynamic> data;

  const StartCustomerDirection({super.key, this.data = const {}});

  @override
  State<StartCustomerDirection> createState() => _StartCustomerDirectionState();
}

class _StartCustomerDirectionState extends State<StartCustomerDirection> {
  late final DirectionData _d = DirectionData(widget.data);
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  // Measured height of the bottom sheet, fed to the map as bottom padding so the
  // customer's booking marker is framed in the visible area *above* the sheet
  // (not centred behind it).
  final GlobalKey _sheetKey = GlobalKey();
  double _sheetHeight = 360;

  String get _bookingId => (_d.booking['_id'] ?? '').toString();

  /// Read the laid-out sheet height after a frame and lift the map focal region
  /// by that much. Runs once the real size is known (and on size changes).
  void _measureSheet() {
    final ctx = _sheetKey.currentContext;
    final h = ctx?.size?.height ?? 0;
    if (h > 0 && (h - _sheetHeight).abs() > 1 && mounted) {
      setState(() => _sheetHeight = h);
    }
  }

  @override
  void initState() {
    super.initState();
    SocketService().connect();
    // If the customer cancels, drop this screen immediately.
    _statusSub = SocketService().onServiceBookingStatus.listen((data) {
      if (!mounted) return;
      if (data['bookingId']?.toString() != _bookingId) return;
      if ((data['status'] ?? '').toString() == 'CANCELLED') {
        Fluttertoast.showToast(msg: "Booking cancelled by customer");
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _callCustomer() async {
    if (_d.phone.isEmpty) {
      Fluttertoast.showToast(msg: "Customer phone not available");
      return;
    }
    final ok = await launchPhoneDialer(_d.countryCode, _d.phone);
    if (!ok) Fluttertoast.showToast(msg: "Could not open dialer");
  }

  void _chatCustomer() {
    Fluttertoast.showToast(msg: "Chat will be available soon");
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheet());
    return Scaffold(
      backgroundColor: HexColor("#FBFBFB"),
      body: Stack(
        children: [
          Positioned.fill(
            // The map shows exactly where the customer placed the booking: their
            // saved address coordinates are centred and pinned. bottomPadding =
            // the sheet height keeps that pin in the visible area above the sheet.
            child: GoogleMapWidget(
              centerLat: _d.lat,
              centerLng: _d.lng,
              pickupLat: _d.lat,
              pickupLng: _d.lng,
              zoom: 16,
              interactive: true,
              bottomPadding: _sheetHeight,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: HexColor("#E1E6EF")),
                  ),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _sheet()),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Container(
      key: _sheetKey,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DirectionDetailsCards(d: _d),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DirectionActionButton(
                      icon: Icons.call, label: "Call", onTap: _callCustomer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DirectionActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: "Chat",
                      onTap: _chatCustomer),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _startDirectionButton(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _startDirectionButton() {
    // Figma: a centred 236px-wide pill, not full width.
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            // Advancing to en-route — replace so Back returns to the dashboard
            // (resumable from "On Going") rather than this start screen.
            pushReplace(context, CustomerDirectionScreen(data: widget.data)),
        child: Container(
          width: 236,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HexColor("#2C54C1"),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Start customer direction",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
