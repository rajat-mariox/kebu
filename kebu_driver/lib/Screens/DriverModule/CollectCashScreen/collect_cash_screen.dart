import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:kebu_driver/CommonWidgets/swipe_button.dart';
import 'package:kebu_driver/Screens/DriverModule/CollectCashScreen/fare_breakdown_sheet.dart';
import 'package:kebu_driver/Screens/DriverModule/Controller/driver_booking_controller.dart';

/// Figma "Summary / Collect Cash" screen (node 131:10601).
///
/// Shown to the driver right after `completeRide()` succeeds. Lets the
/// driver collect either cash (and confirm via the swipe button) or have
/// the customer pay via the displayed QR. After confirming, advances to
/// the trip summary screen.
class CollectCashScreen extends StatelessWidget {
  const CollectCashScreen({super.key});

  static final _yellow = HexColor('#FFD546');
  static final _green = HexColor('#08875D');
  static final _gray1 = HexColor('#132235');
  static final _gray2 = HexColor('#364B63');
  static final _border = HexColor('#E1E6EF');
  static final _blueBg = HexColor('#F0F5FF');
  static final _blue = HexColor('#2F6FED');
  static final _error = HexColor('#E02D3C');
  static final _bgGray = HexColor('#F0F5FA');

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null) return '—';
    final stop = end ?? DateTime.now();
    final mins = stop.difference(start).inMinutes;
    if (mins < 1) return '< 1 Min';
    final hours = mins ~/ 60;
    final remaining = mins % 60;
    if (hours == 0) return '$remaining Mins';
    if (remaining == 0) return '$hours Hr';
    return '$hours Hr $remaining Mins';
  }

  /// Build a UPI deep-link payload so apps that scan the QR (PhonePe, GPay,
  /// Paytm) auto-fill the amount. We don't have a configured payee VPA on
  /// the driver record yet, so we fall back to a placeholder that still
  /// renders a readable QR — the driver can replace later when wired up.
  String _buildUpiPayload(double amount, String bookingId) {
    final amt = amount.toStringAsFixed(2);
    final tn = Uri.encodeComponent('Kebu Ride $bookingId');
    // pa = payee VPA, pn = payee name, am = amount, tn = transaction note
    return 'upi://pay?pa=kebu@upi&pn=Kebu&am=$amt&cu=INR&tn=$tn';
  }

  Future<void> _callCustomer(DriverBookingController bc) async {
    final phone = bc.customerPhone.value.trim();
    if (phone.isEmpty) {
      Fluttertoast.showToast(msg: 'Customer phone not available');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: 'Could not start dialer');
    }
  }

  /// "Collected Fare" terminal action. This is where a cash ride is actually
  /// finalised: completing the booking marks it COMPLETED on the backend
  /// (which detaches the customer), then we record the cash as PAID, reset
  /// and let the active-ride listener pop back Home (via the idle state).
  Future<void> _onCollectedCash(
      BuildContext context, DriverBookingController bc) async {
    // 1. Complete the ride → customer detaches.
    await bc.completeRide();
    if (!context.mounted) return;
    if (bc.rideState.value != DriverRideState.completed) {
      Fluttertoast.showToast(
        msg: 'Could not complete the ride. Please try again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    // 2. Record the cash payment.
    final paid = await bc.markCashCollected();
    if (!context.mounted) return;
    Fluttertoast.showToast(
      msg: paid
          ? 'Payment recorded'
          : 'Ride completed, but the payment could not be recorded.',
    );
    // 3. Reset → rideState flips to idle → the ActiveRideScreen listener pops
    // the whole ride flow back to Home.
    bc.resetBooking();
  }

  @override
  Widget build(BuildContext context) {
    final bc = Get.find<DriverBookingController>();

    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _appBar(context),
            Expanded(
              child: Obx(() {
                final fare = bc.estimatedFare.value;
                final bookingId = bc.bookingId.value;
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _amountBanner(context, fare),
                      const SizedBox(height: 16),
                      _durationCard(_formatDuration(
                          bc.rideStartedAt.value, bc.rideEndedAt.value)),
                      const SizedBox(height: 32),
                      _qrSection(fare, bookingId),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }),
            ),
            _bottomBar(context, bc),
          ],
        ),
      ),
    );
  }

  // ─────────────── app bar ───────────────

  Widget _appBar(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: AssetIcon('assets/active_ride/arrow_left.svg',
                  width: 28, height: 28),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              'Summary',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 25 / 20,
                color: _gray1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── amount banner ───────────────

  Widget _amountBanner(BuildContext context, double amount) {
    return Container(
      width: double.infinity,
      color: _green,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            'Amount to be Collected',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 18 / 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 34 / 28,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => FareBreakdownSheet.show(context, amount),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child:
                      Icon(Icons.info_outline, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────── duration card ───────────────

  Widget _durationCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blueBg,
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'DURATION OF USE',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              color: _yellow,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 22 / 17,
              color: _yellow,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── QR section ───────────────

  Widget _qrSection(double amount, String bookingId) {
    return Column(
      children: [
        Text(
          'QR Code',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 25 / 20,
            color: _gray1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan & Pay',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 20 / 15,
            color: _gray2,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.transparent,
          child: QrImageView(
            data: _buildUpiPayload(amount, bookingId),
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            // ignore: deprecated_member_use
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  // ─────────────── bottom bar (Contact / Raise Ticket + Collected Cash) ───────────────

  Widget _bottomBar(BuildContext context, DriverBookingController bc) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _supportTile(
                  icon: 'assets/active_ride/call_calling.svg',
                  label: 'Contact',
                  color: _yellow,
                  onTap: () => _callCustomer(bc),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _supportTile(
                  icon: 'assets/active_ride/ticket.svg',
                  label: 'Raise Ticket',
                  color: _error,
                  onTap: () =>
                      Fluttertoast.showToast(msg: 'Raise ticket coming soon'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() => SwipeButton(
                label: 'Collected Fare',
                loading: bc.isLoading.value,
                onConfirmed: () => _onCollectedCash(context, bc),
              )),
        ],
      ),
    );
  }

  Widget _supportTile({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AssetIcon(icon, width: 20, height: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
