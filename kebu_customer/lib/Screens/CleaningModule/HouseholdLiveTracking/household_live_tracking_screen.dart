import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/CommonWidgets/google_map_widget.dart';
import 'package:kebu_customer/Services/socket_service.dart';

/// Live map of the service provider travelling to the booking address.
/// Mirrors the cab LiveTrackingScreen but for household service bookings.
class HouseholdLiveTrackingScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? provider;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;

  const HouseholdLiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    this.provider,
  });

  @override
  State<HouseholdLiveTrackingScreen> createState() =>
      _HouseholdLiveTrackingScreenState();
}

class _HouseholdLiveTrackingScreenState
    extends State<HouseholdLiveTrackingScreen> {
  StreamSubscription<Map<String, dynamic>>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;

  double? _providerLat;
  double? _providerLng;
  String _status = 'PROVIDER_ASSIGNED';

  @override
  void initState() {
    super.initState();
    SocketService().connect();

    _locationSub = SocketService().onProviderLocation.listen((data) {
      if (!mounted) return;
      if (data['bookingId']?.toString() != widget.bookingId) return;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() {
        _providerLat = lat;
        _providerLng = lng;
      });
    });

    _statusSub = SocketService().onServiceBookingStatus.listen((data) {
      if (!mounted) return;
      final bookingId = data['bookingId']?.toString();
      if (bookingId != widget.bookingId) return;
      final status = (data['status'] ?? '').toString();
      if (status.isNotEmpty) setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  String get _statusLabel {
    switch (_status) {
      case 'PROVIDER_EN_ROUTE':
        return 'Provider on the way';
      case 'PROVIDER_ARRIVED':
        return 'Provider arrived';
      case 'IN_PROGRESS':
        return 'Service in progress';
      case 'COMPLETED':
        return 'Service completed';
      default:
        return 'Provider assigned';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider ?? const {};
    final providerName = (provider['fullName'] ?? 'Provider').toString();
    final providerPhone = (provider['mobileNumber'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMapWidget(
              centerLat: _providerLat ?? widget.destinationLat,
              centerLng: _providerLng ?? widget.destinationLng,
              pickupLat: widget.destinationLat,
              pickupLng: widget.destinationLng,
              driverLat: _providerLat,
              driverLng: _providerLng,
              zoom: 15,
              interactive: true,
              showMyLocation: false,
            ),
          ),

          Positioned(
            top: 40,
            left: 16,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 40,
                width: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 12),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: HexColor('#531E96').withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HexColor('#531E96'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: HexColor('#F1E8FB'),
                        backgroundImage: (provider['profileImage'] != null &&
                                provider['profileImage']
                                    .toString()
                                    .isNotEmpty)
                            ? NetworkImage(provider['profileImage'])
                            : null,
                        child: (provider['profileImage'] == null ||
                                provider['profileImage']
                                    .toString()
                                    .isEmpty)
                            ? const Icon(Icons.person, color: Colors.black54)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              providerName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (providerPhone.isNotEmpty)
                              Text(
                                providerPhone,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (providerPhone.isNotEmpty)
                        InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: HexColor('#4FBF67'),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call,
                                size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.destinationAddress,
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
          ),
        ],
      ),
    );
  }
}
