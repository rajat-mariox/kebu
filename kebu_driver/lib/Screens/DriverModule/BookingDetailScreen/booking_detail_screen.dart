import 'package:flutter/material.dart';
import 'package:kebu_driver/CommonWidgets/asset_icon.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Read-only ride detail screen, modelled on the Figma "History - Ride
/// Details" frame (131:11437). Shown when:
///   - the driver taps a row in the trip history list, or
///   - the driver taps a "Ride Cancelled" push notification.
///
/// Accepts either a pre-fetched booking map or a bookingId to fetch.
class BookingDetailScreen extends StatefulWidget {
  final String? bookingId;
  final Map<String, dynamic>? booking;

  const BookingDetailScreen({
    super.key,
    this.bookingId,
    this.booking,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      _booking = widget.booking;
    } else if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
      _fetch();
    } else {
      _error = 'Booking not found';
    }
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await DriverApiService.getBookingById(widget.bookingId!);
    if (!mounted) return;
    if (res.success && res.data is Map) {
      Map data = res.data as Map;
      if (data['booking'] is Map) data = data['booking'] as Map;
      setState(() {
        _booking = Map<String, dynamic>.from(data);
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.message.isNotEmpty ? res.message : 'Failed to load booking';
        _loading = false;
      });
    }
  }

  // ─────────────── helpers ───────────────

  String _shortId(String id) {
    if (id.isEmpty) return '#--------';
    final tail = id.length > 8 ? id.substring(id.length - 8) : id;
    return '#${tail.toUpperCase()}';
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      var hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, '
          '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}$amPm';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatDuration(num minutes) {
    if (minutes <= 0) return '-';
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    return '${m}min';
  }

  String _tripTypeLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'ROUND_TRIP':
      case 'ROUND-TRIP':
      case 'ROUND':
        return 'Round Trip';
      case 'FLEXI':
        return 'Flexi';
      case 'ONE_WAY':
      case 'ONEWAY':
      case 'ONE-WAY':
        return 'One Way';
      default:
        return raw.isEmpty ? '-' : raw;
    }
  }

  /// (label, fg, bg) for a status banner.
  (String, Color, Color) _statusStyle(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'COMPLETED':
        return ('Completed', HexColor('#08875D'), HexColor('#E6F6ED'));
      case 'CANCELLED':
        return ('Cancelled', HexColor('#E02D3C'), HexColor('#FCE8EA'));
      case 'IN_PROGRESS':
      case 'PICKED':
        return ('In Progress', HexColor('#2F6FED'), HexColor('#E6EFFD'));
      case 'DRIVER_ARRIVED':
        return ('Driver Arrived', HexColor('#2F6FED'), HexColor('#E6EFFD'));
      case 'ASSIGNED':
        return ('Assigned', HexColor('#2F6FED'), HexColor('#E6EFFD'));
      case 'SEARCHING':
        return ('Searching', HexColor('#13203C'), HexColor('#F0F5FA'));
      default:
        return (status.isEmpty ? '-' : status, HexColor('#132235'),
            HexColor('#F0F5FA'));
    }
  }

  // ─────────────── build ───────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    final b = _booking;
    return Scaffold(
      backgroundColor: HexColor('#F0F5FA'),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(b),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView(_error!)
                      : (b == null
                          ? const SizedBox.shrink()
                          : _content(b)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar(Map<String, dynamic>? b) {
    final id = (b?['_id'] ?? b?['bookingId'] ?? '').toString();
    return Container(
      width: double.infinity,
      color: HexColor('#FFD546'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: AssetIcon('assets/booking_detail/arrow_left.svg',
                width: 28,
                height: 28,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              _shortId(id),
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 25 / 20,
                color: HexColor('#132235'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: HexColor('#364B63'),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.bookingId != null)
              TextButton(
                onPressed: _fetch,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> b) {
    final status = (b['status'] ?? '').toString();
    final tripType = _tripTypeLabel(
        (b['tripType'] ?? b['rideType'] ?? '').toString());
    final pickup = b['pickup'] ?? b['pickupLocation'] ?? const {};
    final drop = b['drop'] ?? b['dropLocation'] ?? const {};
    final pickupAddr = (pickup is Map ? pickup['address'] : '')?.toString() ?? '';
    final dropAddr = (drop is Map ? drop['address'] : '')?.toString() ?? '';

    final startedAt = b['startedAt'] ??
        b['rideStartedAt'] ??
        b['driverArrivedAt'] ??
        b['createdAt'];
    final endedAt = b['endedAt'] ??
        b['completedAt'] ??
        b['cancelledAt'] ??
        b['updatedAt'];

    final distanceKm = (b['distanceKm'] ?? 0).toDouble();
    final durationMin = (b['durationMin'] ?? 0) as num;
    final vehicleTypeRaw = b['vehicleTypeId'];
    final vehicleType = vehicleTypeRaw is Map
        ? (vehicleTypeRaw['name'] ?? '').toString()
        : (b['vehicleTypeName'] ?? b['vehicleType'] ?? '').toString();

    final fare = (b['finalFare'] ?? b['fare'] ?? b['estimatedFare'] ?? 0)
        .toDouble();
    final earned = (b['driverEarning'] ??
            b['driverPayout'] ??
            (status.toUpperCase() == 'COMPLETED' ? fare : 0))
        .toDouble();
    final cancellationReason = (b['cancellationReason'] ??
            b['cancelReason'] ??
            '')
        .toString();
    final cancelledBy = (b['cancelledBy'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status.isNotEmpty) _statusBanner(status, cancelledBy, cancellationReason),
          if (status.isNotEmpty) const SizedBox(height: 12),
          _pickupDestinationCard(
              startedAt: startedAt,
              endedAt: endedAt,
              pickupAddr: pickupAddr,
              dropAddr: dropAddr,
              status: status),
          const SizedBox(height: 16),
          _basicDetailsCard(
            tripId: _shortId((b['_id'] ?? b['bookingId'] ?? '').toString()),
            tripType: tripType,
            distanceKm: distanceKm,
            durationMin: durationMin,
            vehicleType: vehicleType.isNotEmpty ? vehicleType : '-',
          ),
          const SizedBox(height: 16),
          _fareCard(
            fare: fare,
            earned: earned,
            isCompleted: status.toUpperCase() == 'COMPLETED',
            isCancelled: status.toUpperCase() == 'CANCELLED',
          ),
        ],
      ),
    );
  }

  // ─────────────── cards ───────────────

  Widget _statusBanner(String status, String cancelledBy, String reason) {
    final (label, fg, bg) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 20 / 15,
                    color: fg,
                  ),
                ),
                if (status.toUpperCase() == 'CANCELLED' &&
                    (cancelledBy.isNotEmpty || reason.isNotEmpty)) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (cancelledBy.isNotEmpty)
                        'Cancelled by ${cancelledBy.toLowerCase()}',
                      if (reason.isNotEmpty) reason,
                    ].join(' · '),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 18 / 13,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickupDestinationCard({
    required dynamic startedAt,
    required dynamic endedAt,
    required String pickupAddr,
    required String dropAddr,
    required String status,
  }) {
    final isCancelled = status.toUpperCase() == 'CANCELLED';
    return _whiteCard(
      child: Stack(
        children: [
          // Connector line behind both rows
          Positioned(
            top: 54,
            left: 26,
            child: Container(
              width: 2,
              height: 78,
              color: HexColor('#E1E6EF'),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('PICKUP & DESTINATION'),
              const SizedBox(height: 8),
              _stop(
                iconAsset: 'assets/booking_detail/pickup_dot.svg',
                title: isCancelled
                    ? 'Pickup'
                    : 'Started : ${_formatDateTime(startedAt)}',
                subtitle: pickupAddr.isNotEmpty ? pickupAddr : '-',
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 0,
              ),
              _stop(
                iconAsset: 'assets/booking_detail/drop_dot.svg',
                title: isCancelled
                    ? 'Destination'
                    : 'Ended : ${_formatDateTime(endedAt)}',
                subtitle: dropAddr.isNotEmpty ? dropAddr : '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stop({
    required String iconAsset,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Image.asset(iconAsset, width: 18, height: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 20 / 15,
                    color: HexColor('#132235'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 18 / 13,
                    color: HexColor('#132235'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _basicDetailsCard({
    required String tripId,
    required String tripType,
    required double distanceKm,
    required num durationMin,
    required String vehicleType,
  }) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('BASIC DETAILS'),
          const SizedBox(height: 8),
          _detailRow('Trip ID:', tripId,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: tripId));
                Fluttertoast.showToast(msg: 'Copied');
              }),
          _detailRow('Trip Type:', tripType),
          _detailRow(
              'Trip Distance:',
              distanceKm > 0
                  ? '${distanceKm.toStringAsFixed(distanceKm % 1 == 0 ? 0 : 2)} km'
                  : '-'),
          _detailRow('Trip Duration:', _formatDuration(durationMin)),
          _detailRow('Vehicle Type:', vehicleType, isLast: true),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool isLast = false, VoidCallback? onCopy}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 20 / 15,
                color: HexColor('#132235'),
              ),
            ),
          ),
          GestureDetector(
            onTap: onCopy,
            child: Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 20 / 15,
                color: HexColor('#132235'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareCard({
    required double fare,
    required double earned,
    required bool isCompleted,
    required bool isCancelled,
  }) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('ESTIMATED FARE DETAILS'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated Total Fare:',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 20 / 15,
                    color: HexColor('#132235'),
                  ),
                ),
              ),
              Text(
                '₹${fare.toStringAsFixed(0)}',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 20 / 15,
                  color: HexColor('#132235'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: HexColor('#E1E6EF')),
          const SizedBox(height: 12),
          if (isCompleted) ...[
            Text(
              'Earned money from trip:',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: HexColor('#2F6FED'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${earned.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 25 / 20,
                color: HexColor('#2F6FED'),
              ),
            ),
          ] else if (isCancelled) ...[
            Text(
              'Trip was cancelled — no earnings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: HexColor('#E02D3C'),
              ),
            ),
          ] else ...[
            Text(
              'Earnings will appear here when the trip is completed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 18 / 13,
                color: HexColor('#364B63'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────── primitives ───────────────

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HexColor('#E1E6EF')),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 16 / 12,
        color: HexColor('#132234'),
        letterSpacing: 0.4,
      ),
    );
  }
}
