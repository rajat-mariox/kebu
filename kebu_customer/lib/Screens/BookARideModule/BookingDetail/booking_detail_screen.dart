import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:kebu_customer/Services/booking_api_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? initialBooking;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? booking;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialBooking != null) {
      booking = widget.initialBooking;
      isLoading = false;
    }
    _load();
  }

  Future<void> _load() async {
    final response = await BookingApiService.getBookingDetails(widget.bookingId);
    if (!mounted) return;
    if (response.success && response.data != null) {
      final data = response.data;
      final fetched =
          data['booking'] is Map ? Map<String, dynamic>.from(data['booking']) : Map<String, dynamic>.from(data);
      setState(() {
        booking = fetched;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
        if (booking == null) {
          errorMessage = response.message ?? 'Unable to load booking';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor('#F6F7FB'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'Booking Details',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading && booking == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (booking == null) {
      return Center(
        child: Text(
          errorMessage ?? 'Booking not found',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    final b = booking!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _statusBanner(b),
          const SizedBox(height: 14),
          _driverSection(b),
          const SizedBox(height: 14),
          _tripSection(b),
          const SizedBox(height: 14),
          _passengerSection(b),
          const SizedBox(height: 14),
          _priceBreakdownCard(b),
          const SizedBox(height: 14),
          _invoiceCard(b),
        ],
      ),
    );
  }

  // ============ STATUS ============
  Widget _statusBanner(Map<String, dynamic> b) {
    final status = b['status']?.toString() ?? '';
    final color = _statusColor(status);
    final created = _formatDateTime(b['createdAt']?.toString());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(status), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _prettyStatus(status),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${created['date']} • ${created['time']}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '#${_shortId(b['_id']?.toString() ?? widget.bookingId)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============ DRIVER ============
  Widget _driverSection(Map<String, dynamic> b) {
    final driver = b['driverId'] is Map
        ? Map<String, dynamic>.from(b['driverId'] as Map)
        : <String, dynamic>{};
    if (driver.isEmpty) return const SizedBox.shrink();

    final name = (driver['fullName']?.toString().trim().isNotEmpty ?? false)
        ? driver['fullName'].toString()
        : 'Driver';
    final photo = driver['profileImage']?.toString() ?? '';
    final rating = _parseRating(b['rating'] ?? driver['rating']);
    final ratingText = rating != null ? rating.toStringAsFixed(1) : '—';
    final phone = driver['mobileNumber']?.toString() ?? '';

    final vehicleType = b['vehicleTypeId'] is Map
        ? Map<String, dynamic>.from(b['vehicleTypeId'] as Map)
        : <String, dynamic>{};
    final vehicleName = vehicleType['name']?.toString() ?? 'Ride';
    final vehicleImage = vehicleType['image']?.toString() ?? '';

    return _card(
      title: 'Driver & Vehicle',
      child: Row(
        children: [
          _personAvatar(photo, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (vehicleImage.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          vehicleImage,
                          width: 32,
                          height: 20,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        vehicleName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: HexColor('#0A84FF'),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  ratingText,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 16, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ TRIP ============
  Widget _tripSection(Map<String, dynamic> b) {
    final pickup = b['pickup']?['address']?.toString() ?? '-';
    final drop = b['drop']?['address']?.toString() ?? '-';
    final distance = b['distanceKm'];
    final duration = b['durationMin'];

    return _card(
      title: 'Trip',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pickup,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Image.asset('assets/dotted_line.png', height: 18),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  drop,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ],
          ),
          if (distance != null || duration != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: HexColor('#ECECEC')),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tripStat(Icons.directions_car, '${distance ?? 0} km',
                    'Distance'),
                _tripStat(Icons.timer_outlined, '${duration ?? 0} min',
                    'Duration'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tripStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade700, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  // ============ PASSENGER ============
  Widget _passengerSection(Map<String, dynamic> b) {
    final user = b['userId'] is Map
        ? Map<String, dynamic>.from(b['userId'] as Map)
        : <String, dynamic>{};
    final rider = b['riderId'] is Map
        ? Map<String, dynamic>.from(b['riderId'] as Map)
        : <String, dynamic>{};
    final riderName = (b['riderName']?.toString().trim().isNotEmpty ?? false)
        ? b['riderName'].toString()
        : (rider['fullName']?.toString() ?? '');
    final riderPhone = (b['riderPhone']?.toString().trim().isNotEmpty ?? false)
        ? b['riderPhone'].toString()
        : (rider['mobileNumber']?.toString() ?? '');
    final isForSelf = riderName.isEmpty && riderPhone.isEmpty;
    final name = isForSelf
        ? (user['fullName']?.toString().trim().isNotEmpty ?? false
            ? user['fullName'].toString()
            : 'Self')
        : riderName;
    final phone = isForSelf
        ? (user['mobileNumber']?.toString() ?? '')
        : riderPhone;
    final photo = isForSelf
        ? (user['profileImage']?.toString() ?? '')
        : (rider['profileImage']?.toString() ?? '');

    return _card(
      title: 'Passenger',
      child: Row(
        children: [
          _personAvatar(photo, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isForSelf ? '$name (Self)' : name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ PRICE BREAKDOWN ============
  Widget _priceBreakdownCard(Map<String, dynamic> b) {
    final baseFare = _toDouble(b['fare']);
    final surge = _toDouble(b['surgeFare']);
    final discount = _toDouble(b['discount']);
    final promoDiscount = _toDouble(b['promoDiscount']);
    final tip = _toDouble(b['tip']);
    final finalFare = _toDouble(b['finalFare']);
    final subscriptionDiscount = _toDouble(b['subscriptionDiscount']);
    final subscriptionPlanName = b['subscriptionPlanName']?.toString() ?? '';
    final paymentMethod = b['paymentMethod']?.toString() ?? 'CASH';
    final paymentStatus = b['paymentStatus']?.toString() ?? 'PENDING';
    final promoCode = b['promoCode']?.toString() ?? '';
    final otherDiscount = (discount - subscriptionDiscount).clamp(0, double.infinity);

    return _card(
      title: 'Price Breakdown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _priceRow('Base Fare', baseFare),
          if (surge > 0) _priceRow('Surge', surge),
          if (tip > 0) _priceRow('Tip', tip),
          if (otherDiscount > 0)
            _priceRow('Discount', -otherDiscount.toDouble(), isDiscount: true),
          if (promoDiscount > 0)
            _priceRow(
              promoCode.isNotEmpty ? 'Promo ($promoCode)' : 'Promo Discount',
              -promoDiscount,
              isDiscount: true,
            ),
          if (subscriptionDiscount > 0)
            _priceRow(
              subscriptionPlanName.isNotEmpty
                  ? 'Kebu Pass ($subscriptionPlanName)'
                  : 'Kebu Pass discount',
              -subscriptionDiscount,
              isDiscount: true,
            ),
          const SizedBox(height: 8),
          Container(height: 1, color: HexColor('#ECECEC')),
          const SizedBox(height: 8),
          _priceRow('Total Paid', finalFare, bold: true),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.payments_outlined,
                  size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                '$paymentMethod • ${_prettyPaymentStatus(paymentStatus)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double value,
      {bool isDiscount = false, bool bold = false}) {
    final color = isDiscount ? Colors.green.shade700 : Colors.black87;
    final weight = bold ? FontWeight.w700 : FontWeight.w500;
    final sign = isDiscount ? '-' : '';
    final amount = value.abs().toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: weight,
                color: bold ? Colors.black : Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            '$sign₹$amount',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: weight,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============ INVOICE ============
  Widget _invoiceCard(Map<String, dynamic> b) {
    final id = b['_id']?.toString() ?? widget.bookingId;
    final created = _formatDateTime(b['createdAt']?.toString());
    final completed = _formatDateTime(
        b['completedAt']?.toString() ?? b['createdAt']?.toString());
    final paymentMethod = b['paymentMethod']?.toString() ?? 'CASH';
    final paymentStatus = b['paymentStatus']?.toString() ?? 'PENDING';
    final finalFare = _toDouble(b['finalFare']);
    final user = b['userId'] is Map
        ? Map<String, dynamic>.from(b['userId'] as Map)
        : <String, dynamic>{};

    final baseFare = _toDouble(b['fare']);
    final surge = _toDouble(b['surgeFare']);
    final discount = _toDouble(b['discount']);
    final promoDiscount = _toDouble(b['promoDiscount']);
    final tip = _toDouble(b['tip']);
    final subscriptionDiscount = _toDouble(b['subscriptionDiscount']);
    final subscriptionPlanName = b['subscriptionPlanName']?.toString() ?? '';

    final subtotal = baseFare + surge + tip;
    final totalDiscount = discount + promoDiscount;

    return _card(
      title: 'Invoice',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: paymentStatus.toUpperCase() == 'PAID'
              ? Colors.green.withOpacity(0.12)
              : Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _prettyPaymentStatus(paymentStatus),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: paymentStatus.toUpperCase() == 'PAID'
                ? Colors.green.shade700
                : Colors.orange.shade800,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _invoiceRow('Invoice No', 'INV-${_shortId(id).toUpperCase()}'),
          _invoiceRow('Booking ID', id),
          _invoiceRow('Booked On', '${created['date']} ${created['time']}'),
          if (b['completedAt'] != null)
            _invoiceRow('Completed On',
                '${completed['date']} ${completed['time']}'),
          _invoiceRow(
              'Billed To',
              (user['fullName']?.toString().isNotEmpty ?? false)
                  ? user['fullName'].toString()
                  : '-'),
          if (user['mobileNumber'] != null &&
              user['mobileNumber'].toString().isNotEmpty)
            _invoiceRow('Contact', user['mobileNumber'].toString()),
          _invoiceRow('Payment Method', paymentMethod),
          const SizedBox(height: 10),
          Container(height: 1, color: HexColor('#ECECEC')),
          const SizedBox(height: 10),
          _invoiceLine('Subtotal', subtotal),
          if (totalDiscount > 0)
            _invoiceLine('Discounts', -totalDiscount, isDiscount: true),
          if (subscriptionDiscount > 0)
            _invoiceLine(
              subscriptionPlanName.isNotEmpty
                  ? 'Kebu Pass ($subscriptionPlanName)'
                  : 'Kebu Pass savings',
              -subscriptionDiscount,
              isDiscount: true,
            ),
          const SizedBox(height: 6),
          Container(height: 1, color: HexColor('#ECECEC')),
          const SizedBox(height: 6),
          _invoiceLine('Grand Total', finalFare, bold: true),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceLine(String label, double value,
      {bool bold = false, bool isDiscount = false}) {
    final color = isDiscount ? Colors.green.shade700 : Colors.black87;
    final weight = bold ? FontWeight.w700 : FontWeight.w500;
    final sign = isDiscount ? '-' : '';
    final amount = value.abs().toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: weight,
                color: bold ? Colors.black : Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            '$sign₹$amount',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: weight,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============ HELPERS ============
  Widget _card(
      {required String title, required Widget child, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _personAvatar(String url, {double size = 42}) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person,
          size: size * 0.6, color: Colors.grey.shade500),
    );
    final trimmed = url.trim();
    if (trimmed.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  double? _parseRating(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Map<String, String> _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return {'date': '-', 'time': '-'};
    try {
      final date = DateTime.parse(value).toLocal();
      return {
        'date': DateFormat('dd MMM yyyy').format(date),
        'time': DateFormat('hh:mm a').format(date),
      };
    } catch (_) {
      return {'date': value, 'time': '-'};
    }
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(id.length - 8);
  }

  String _prettyStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'PICKED':
        return 'Picked up';
      case 'DRIVER_ARRIVED':
        return 'Driver Arrived';
      case 'ASSIGNED':
        return 'Driver Assigned';
      case 'SEARCHING':
        return 'Searching';
      case 'NO_DRIVERS':
        return 'No drivers';
      default:
        return raw.isEmpty ? 'Booking' : raw;
    }
  }

  String _prettyPaymentStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'PAID':
        return 'Paid';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'IN_PROGRESS':
      case 'PICKED':
        return Colors.blue;
      case 'DRIVER_ARRIVED':
      case 'ASSIGNED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      case 'IN_PROGRESS':
      case 'PICKED':
        return Icons.directions_car;
      case 'DRIVER_ARRIVED':
      case 'ASSIGNED':
        return Icons.local_taxi;
      default:
        return Icons.receipt_long;
    }
  }
}
