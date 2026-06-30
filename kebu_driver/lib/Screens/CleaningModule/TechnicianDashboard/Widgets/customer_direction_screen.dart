import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/AppNavigation/app_navigation.dart';
import 'package:kebu_driver/CommonWidgets/google_map_widget.dart';
import 'package:kebu_driver/Screens/CleaningModule/ServiceDetailsScreen/service_details_screen.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/arrival_otp_sheet.dart';
import 'package:kebu_driver/Screens/CleaningModule/TechnicianDashboard/Widgets/direction_details.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// En-route navigation screen — shown after the partner taps "Start customer
/// direction". The map draws the route from the partner's live location to the
/// customer, and the bottom CTA is "Reached location" which marks the booking
/// PROVIDER_ARRIVED on the backend before moving to OTP verification.
///
/// Fully data-driven from the accept payload (see [DirectionData]).
class CustomerDirectionScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const CustomerDirectionScreen({super.key, this.data = const {}});

  @override
  State<CustomerDirectionScreen> createState() =>
      _CustomerDirectionScreenState();
}

class _CustomerDirectionScreenState extends State<CustomerDirectionScreen> {
  late final DirectionData _d = DirectionData(widget.data);
  LatLng? _providerLatLng;

  // Shortest driving route (partner → customer): the Google-encoded polyline
  // drawn on the map and the real road distance shown on the address card.
  String? _routePolyline;
  String? _roadDistanceText;

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Mark the booking en-route on the backend (best-effort).
    _markStatus("PROVIDER_EN_ROUTE");
  }

  Future<void> _initLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() => _providerLatLng = LatLng(pos.latitude, pos.longitude));
      // Once we know where the partner is, draw the shortest route to the user.
      _fetchRoute();
    } catch (_) {
      // Location unavailable — fall back to just the customer marker.
    }
  }

  /// Fetch the shortest driving route from the partner to the customer and draw
  /// it on the map (the "flow" between me and the user), backfilling the real
  /// road distance for the address card.
  Future<void> _fetchRoute() async {
    final provider = _providerLatLng;
    final customer = _customerLatLng;
    if (provider == null || customer == null) return;
    final res = await DriverApiService.getRoute(
      originLat: provider.latitude,
      originLng: provider.longitude,
      destLat: customer.latitude,
      destLng: customer.longitude,
    );
    if (!mounted || !res.success || res.data is! Map) return;
    final data = Map<String, dynamic>.from(res.data as Map);
    final poly = (data['polyline'] ?? '').toString();
    final km = data['distanceKm'];
    setState(() {
      if (poly.isNotEmpty) _routePolyline = poly;
      if (km is num) {
        _roadDistanceText =
            "${km % 1 == 0 ? km.toInt() : km.toStringAsFixed(1)} Km";
      }
    });
  }

  LatLng? get _customerLatLng {
    final lat = _d.lat, lng = _d.lng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  /// Best-effort status push (used to flag the booking en-route on open).
  Future<void> _markStatus(String status) async {
    final id = _d.bookingId;
    if (id.isEmpty) return;
    await DriverApiService.updateServiceBookingStatus(
        bookingId: id, status: status);
  }

  /// "Reached location" → show the OTP sheet; verifying it marks the booking
  /// PROVIDER_ARRIVED on the backend.
  void _onReachedLocation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ArrivalOtpSheet(
        data: _d,
        onVerified: () {
          // Arrival confirmed (irreversible) → REPLACE the en-route screen with
          // the service-details step so Back doesn't return here. The job is
          // still resumable from the dashboard's "On Going" list.
          pushReplace(context, ServiceDetailsScreen(data: widget.data));
        },
      ),
    );
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

  /// Open Google Maps with directions to the customer (matches the Figma flow).
  Future<void> _openExternalMap() async {
    final dest = _customerLatLng;
    if (dest == null) {
      Fluttertoast.showToast(msg: "Customer location not available");
      return;
    }
    final ok = await launchMapsDirections(dest.latitude, dest.longitude);
    if (!ok) Fluttertoast.showToast(msg: "Could not open maps");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor("#FBFBFB"),
      body: Stack(
        children: [
          Positioned.fill(child: _map()),
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

  Widget _map() {
    final customer = _customerLatLng;
    final provider = _providerLatLng;
    final center = customer ?? provider;

    // Google Maps (MapType.normal). The partner's live location is the trip
    // start (pickup) and the customer is the destination (drop); GoogleMapWidget
    // auto-frames both and draws the shortest-route polyline between them once
    // the partner's GPS resolves and the route is fetched.
    return GoogleMapWidget(
      centerLat: center?.latitude,
      centerLng: center?.longitude,
      pickupLat: provider?.latitude,
      pickupLng: provider?.longitude,
      dropLat: customer?.latitude,
      dropLng: customer?.longitude,
      routePolyline: _routePolyline,
      zoom: 14,
      interactive: true,
    );
  }

  Widget _sheet() {
    return Container(
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
            DirectionDetailsCards(d: _d, distanceOverride: _roadDistanceText),
            const SizedBox(height: 16),
            // Call / Chat / Map
            Row(
              children: [
                Expanded(
                  child: DirectionActionButton(
                      icon: Icons.call, label: "Call", onTap: _callCustomer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DirectionActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: "Chat",
                      onTap: _chatCustomer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DirectionActionButton(
                      icon: Icons.location_on,
                      label: "Map",
                      filled: true,
                      onTap: _openExternalMap),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _reachedButton(),
          ],
        ),
      ),
    );
  }

  Widget _reachedButton() {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: _onReachedLocation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HexColor("#2C54C1"),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Reached location",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
