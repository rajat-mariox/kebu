import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kebu_driver/Screens/ParcelModule/Controller/parcel_booking_controller.dart';
import 'package:kebu_driver/Screens/ParcelModule/ParcelDeliverySummaryScreen/parcel_delivery_summary_screen.dart';
import 'package:kebu_driver/Services/driver_api_service.dart';

/// Bottom-sheet state of the parcel map.
/// [request] → Reject/Accept (Figma 157:11253).
/// [enroutePickup] → "You are Enroute Pick Up Location" + Arrive (Figma 157:11382).
/// [startDelivery] → sender/package/recipient card + Start Delivery (Figma 157:11513).
/// [enrouteDrop] → ETA + Call Recipient + Start Drop off process (Figma 157:11664).
enum ParcelMapStage { request, enroutePickup, startDelivery, enrouteDrop }

/// Parcel "Request Map Details" — Figma node 157:11253, and its post-accept
/// "Enroute Pickup" state — Figma node 157:11382 (same screen).
/// Shows the partner where they are (Me), where to pick the parcel up, and
/// where to drop it, with the driving route between them.
class ParcelRequestMapScreen extends StatefulWidget {
  final String deliveryId;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropLat;
  final double dropLng;
  final String dropAddress;
  final bool canAct;

  const ParcelRequestMapScreen({
    super.key,
    required this.deliveryId,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropLat,
    required this.dropLng,
    required this.dropAddress,
    this.canAct = false,
  });

  @override
  State<ParcelRequestMapScreen> createState() => _ParcelRequestMapScreenState();
}

class _ParcelRequestMapScreenState extends State<ParcelRequestMapScreen> {
  static final Color _primary = HexColor("#F32054");

  final Completer<GoogleMapController> _mapController = Completer();
  late final ParcelBookingController _c =
      Get.isRegistered<ParcelBookingController>()
          ? Get.find<ParcelBookingController>()
          : Get.put(ParcelBookingController());

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _me;
  bool _acting = false;
  Map<String, dynamic>? _detail;
  int? _etaMin;
  late ParcelMapStage _stage =
      widget.canAct ? ParcelMapStage.request : ParcelMapStage.enroutePickup;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _loadDetail();
    await _loadMe();
    _buildMarkers();
    await _buildRoute();
    if (mounted) setState(() {});
    _fitBounds();
  }

  Future<void> _loadDetail() async {
    final res = await DriverApiService.getDeliveryDetail(widget.deliveryId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() =>
          _detail = Map<String, dynamic>.from(res.data['delivery'] as Map));
    }
  }

  Future<void> _loadMe() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      _me = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {}
  }

  void _buildMarkers() {
    _markers
      ..add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLat, widget.pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
            title: 'Pick Up',
            snippet: widget.pickupAddress.isEmpty ? null : widget.pickupAddress),
      ))
      ..add(Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(widget.dropLat, widget.dropLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
            title: 'Drop Off',
            snippet: widget.dropAddress.isEmpty ? null : widget.dropAddress),
      ));
    if (_me != null) {
      _markers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(_me!.latitude, _me!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Me'),
      ));
    }
  }

  Future<void> _buildRoute() async {
    // Driving route: Me → Pickup (if we know where Me is) and Pickup → Drop.
    if (_me != null) {
      final leg1 = await _routePoints(
          _me!.latitude, _me!.longitude, widget.pickupLat, widget.pickupLng);
      if (leg1.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('me_pickup'),
          color: _primary.withValues(alpha: 0.6),
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          points: leg1,
        ));
      }
    }
    final leg2 = await _routePoints(
        widget.pickupLat, widget.pickupLng, widget.dropLat, widget.dropLng);
    _polylines.add(Polyline(
      polylineId: const PolylineId('pickup_drop'),
      color: _primary,
      width: 6,
      points: leg2.isNotEmpty
          ? leg2
          : [
              LatLng(widget.pickupLat, widget.pickupLng),
              LatLng(widget.dropLat, widget.dropLng),
            ],
    ));
  }

  /// Ask the backend for the road route and decode the polyline. Falls back to
  /// a straight segment if the route call fails.
  Future<List<LatLng>> _routePoints(
      double oLat, double oLng, double dLat, double dLng) async {
    try {
      final res = await DriverApiService.getRoute(
        originLat: oLat,
        originLng: oLng,
        destLat: dLat,
        destLng: dLng,
      );
      if (res.success && res.data != null) {
        final encoded = (res.data['polyline'] ?? '').toString();
        if (encoded.isNotEmpty) return _decodePolyline(encoded);
      }
    } catch (_) {}
    return [LatLng(oLat, oLng), LatLng(dLat, dLng)];
  }

  Future<void> _fitBounds() async {
    final pts = <LatLng>[
      LatLng(widget.pickupLat, widget.pickupLng),
      LatLng(widget.dropLat, widget.dropLng),
      if (_me != null) LatLng(_me!.latitude, _me!.longitude),
    ];
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    try {
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {}
  }

  Future<void> _accept() async {
    if (_acting) return;
    setState(() => _acting = true);
    final ok = await _c.accept(widget.deliveryId);
    if (!mounted) return;
    if (ok) {
      // Same screen transitions into the "Enroute Pickup" state.
      setState(() {
        _acting = false;
        _stage = ParcelMapStage.enroutePickup;
      });
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _reject() async {
    if (_acting) return;
    setState(() => _acting = true);
    await _c.reject(widget.deliveryId);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // Arrived at the pickup location → reveal the parcel/recipient details and
  // the Start Delivery action. No status change yet (the model has no
  // "arrived" state); pickup is confirmed when the partner starts delivery.
  void _arrive() {
    setState(() => _stage = ParcelMapStage.startDelivery);
  }

  Future<void> _startDelivery() async {
    if (_acting) return;
    setState(() => _acting = true);
    final res = await DriverApiService.updateDeliveryStatus(
        widget.deliveryId, 'PICKED_UP');
    if (!mounted) return;
    setState(() {
      _acting = false;
      if (res.success) _stage = ParcelMapStage.enrouteDrop;
    });
    if (res.success) {
      _computeEta();
    } else {
      Get.snackbar('Error',
          res.message.isEmpty ? 'Could not start delivery' : res.message);
    }
  }

  Future<void> _startDropOff() async {
    if (_acting) return;
    setState(() => _acting = true);
    final res = await DriverApiService.updateDeliveryStatus(
        widget.deliveryId, 'IN_TRANSIT');
    if (!mounted) return;
    setState(() => _acting = false);
    if (res.success) {
      // Proceed to the payment "Summary" screen to collect the fee.
      Get.to(() =>
          ParcelDeliverySummaryScreen(deliveryId: widget.deliveryId));
    } else {
      Get.snackbar('Error',
          res.message.isEmpty ? 'Could not start drop off' : res.message);
    }
  }

  Future<void> _callRecipient() async {
    final contact = _detail?['recipientContact']?.toString() ?? '';
    if (contact.isEmpty) {
      Get.snackbar('Call', 'No recipient contact available.');
      return;
    }
    final uri = Uri.parse('tel:$contact');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// ETA from the driver's current position to the drop-off, in minutes.
  Future<void> _computeEta() async {
    if (_me == null) return;
    try {
      final res = await DriverApiService.getRoute(
        originLat: _me!.latitude,
        originLng: _me!.longitude,
        destLat: widget.dropLat,
        destLng: widget.dropLng,
      );
      if (!mounted) return;
      if (res.success && res.data != null && res.data['durationMin'] != null) {
        setState(() => _etaMin = (res.data['durationMin'] as num).round());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.pickupLat, widget.pickupLng),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
              _fitBounds();
            },
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x22000000), blurRadius: 8),
                  ],
                ),
                child: Icon(Icons.arrow_back, color: _primary, size: 22),
              ),
            ),
          ),

          // Bottom sheet — Reject/Accept while deciding, then the Enroute
          // Pickup card with the Arrive button after accepting.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _bottomSheet() {
    switch (_stage) {
      case ParcelMapStage.request:
        return widget.canAct ? _requestSheet() : const SizedBox.shrink();
      case ParcelMapStage.enroutePickup:
        return _enrouteSheet();
      case ParcelMapStage.startDelivery:
        return _startDeliverySheet();
      case ParcelMapStage.enrouteDrop:
        return _enrouteDropSheet();
    }
  }

  Widget _requestSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        boxShadow: [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 30, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _button("Reject", filled: false, onTap: _reject)),
          const SizedBox(width: 16),
          Expanded(child: _button("Accept", filled: true, onTap: _accept)),
        ],
      ),
    );
  }

  Widget _enrouteSheet() {
    return Container(
      margin: EdgeInsets.fromLTRB(
          17, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
              color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0x80CBCDCC),
              borderRadius: BorderRadius.circular(94),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "You are Enroute Pick Up Location",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 14, color: HexColor("#091425")),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _acting ? null : _arrive,
            child: Container(
              width: double.infinity,
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: _acting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text("Arrive",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// Customer/sender summary row (avatar + name + deliveries + rating),
  /// shared by the Start Delivery and Start Drop-off cards.
  Widget _senderRow() {
    final sender = (_detail?['sender'] as Map?) ?? {};
    final name = sender['name']?.toString() ?? '';
    final image = sender['image']?.toString() ?? '';
    final initials = sender['initials']?.toString() ?? '';
    final deliveries = sender['deliveriesCount'] ?? 0;
    final rating = (sender['rating'] ?? 0).toDouble();

    return Row(
      children: [
        if (image.isNotEmpty)
          CircleAvatar(radius: 28, backgroundImage: NetworkImage(image))
        else
          CircleAvatar(
            radius: 28,
            backgroundColor: HexColor("#FDE7EC"),
            child: Text(initials,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: _primary,
                    fontWeight: FontWeight.w500)),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? "Customer" : name,
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: HexColor("#111111"))),
              const SizedBox(height: 4),
              Text("$deliveries Deliveries",
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: HexColor("#4F4F4F"))),
              const SizedBox(height: 4),
              Row(
                children: [
                  RatingBarIndicator(
                    rating: rating,
                    itemCount: 5,
                    itemSize: 14,
                    unratedColor: HexColor("#E0E0E0"),
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star, color: Color(0xFFFFC107)),
                  ),
                  const SizedBox(width: 6),
                  Text(rating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: HexColor("#4F4F4F"))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetContainer({required Widget child}) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          17, 0, 18, 16 + MediaQuery.of(context).padding.bottom),
      padding: const EdgeInsets.fromLTRB(17, 20, 17, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
              color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _pinkButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: _acting ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(3),
        ),
        child: _acting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
      ),
    );
  }

  Widget _startDeliverySheet() {
    final pkg = _detail?['whatYouAreSending']?.toString() ?? '';
    final recipient = _detail?['recipientName']?.toString() ?? '';
    final contact = _detail?['recipientContact']?.toString() ?? '';

    return _sheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _senderRow(),
          const SizedBox(height: 16),
          Text(pkg.isEmpty ? "—" : pkg,
              style:
                  GoogleFonts.poppins(fontSize: 15, color: HexColor("#00122E"))),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: recipient.isEmpty ? "Recipient: —" : "Recipient: $recipient",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: HexColor("#545454")),
              children: [
                if (contact.isNotEmpty)
                  TextSpan(
                    text: "   $contact",
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: HexColor("#0945DE")),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _acting ? null : _startDelivery,
            child: Container(
              width: double.infinity,
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: _acting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text("Start Delivery",
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// Enroute to drop-off — ETA, sender, Call Recipient and the Start Drop off
  /// process button (Figma 157:11664). "Start Drop off" moves the delivery to
  /// IN_TRANSIT and returns to the home stack.
  Widget _enrouteDropSheet() {
    final etaText = _etaMin != null
        ? "$_etaMin minutes to delivery"
        : "On the way to delivery";

    return _sheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etaText,
              style: GoogleFonts.poppins(
                  fontSize: 16, height: 18 / 16, color: Colors.black)),
          const SizedBox(height: 16),
          _senderRow(),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _callRecipient,
              child: Text("Call Recipient",
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _primary,
                      decoration: TextDecoration.underline,
                      decorationColor: _primary)),
            ),
          ),
          const SizedBox(height: 16),
          _pinkButton("Start Drop off process", _startDropOff),
        ],
      ),
    );
  }

  Widget _button(String label,
      {required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _acting ? null : onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _primary : _primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: (_acting && filled)
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: filled ? Colors.white : _primary)),
      ),
    );
  }

  /// Decodes a Google-encoded polyline string into a list of [LatLng].
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
