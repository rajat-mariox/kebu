import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_driver/Utils/polyline_decoder.dart';

/// A reusable Google Maps widget with the same interface as OsmMapWidget.
/// Supports markers for pickup, drop, and driver locations.
class GoogleMapWidget extends StatefulWidget {
  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final double? driverLat;
  final double? driverLng;
  final bool interactive;
  final void Function(GoogleMapController)? onMapCreated;
  final bool showMyLocation;

  /// Bottom inset (px) for the map's focal region. Set this to the height of
  /// an overlapping bottom sheet so auto-fit frames pickup/drop in the
  /// *visible* area above the sheet instead of centering them behind it.
  final double bottomPadding;

  /// Google-encoded polyline string for the driving route to render. When
  /// non-null and non-empty, the widget draws a yellow polyline along the
  /// decoded points. Falls back to no overlay when missing.
  final String? routePolyline;

  /// Live-tracking mode: keep the camera following the driver toward the
  /// destination ([focusLat]/[focusLng]) as their location updates, instead
  /// of statically framing pickup→drop. Use for the active-ride screen.
  final bool followDriver;

  /// The destination the driver is currently heading to (pickup or drop,
  /// depending on the ride phase). Used with [followDriver] to keep both the
  /// driver and their target in view.
  final double? focusLat;
  final double? focusLng;

  const GoogleMapWidget({
    super.key,
    this.centerLat,
    this.centerLng,
    this.zoom = 14.0,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.driverLat,
    this.driverLng,
    this.interactive = false,
    this.onMapCreated,
    this.showMyLocation = true,
    this.routePolyline,
    this.bottomPadding = 0,
    this.followDriver = false,
    this.focusLat,
    this.focusLng,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  final Completer<GoogleMapController> _controller = Completer();

  // Exact Figma map-pin icons (pickup + destination). Null until loaded;
  // markers fall back to default coloured pins meanwhile.
  static BitmapDescriptor? _pickupIcon;
  static BitmapDescriptor? _dropIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    if (_pickupIcon != null && _dropIcon != null) return;
    try {
      _pickupIcon =
          await _bitmapFromPng('assets/booking_buzzer/pickup_pin.png', 38);
      _dropIcon =
          await _bitmapFromPng('assets/booking_buzzer/destination_pin.png', 38);
      if (mounted) setState(() {});
    } catch (_) {
      // Leave defaults on failure.
    }
  }

  /// Load a PNG asset as a [BitmapDescriptor] displayed at [width] logical px.
  Future<BitmapDescriptor> _bitmapFromPng(String asset, double width) async {
    final data = await rootBundle.load(asset);
    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: width,
    );
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Live-tracking mode: keep following the driver toward the destination as
    // their GPS updates. Takes priority over the static pickup→drop framing.
    if (widget.followDriver && _isValid(widget.driverLat, widget.driverLng)) {
      final driverChanged = widget.driverLat != oldWidget.driverLat ||
          widget.driverLng != oldWidget.driverLng;
      final focusChanged = widget.focusLat != oldWidget.focusLat ||
          widget.focusLng != oldWidget.focusLng;
      if (driverChanged || focusChanged) _followDriver();
      return;
    }

    // The booking coordinates arrive asynchronously (after the map is first
    // built with empty/zero coords). Once both pickup and drop are known,
    // frame the camera on them so the focus is the trip — not a generic
    // country-level view. This re-fits whenever either endpoint changes.
    final pickupReady = _isValid(widget.pickupLat, widget.pickupLng);
    final dropReady = _isValid(widget.dropLat, widget.dropLng);
    final endpointsChanged = widget.pickupLat != oldWidget.pickupLat ||
        widget.pickupLng != oldWidget.pickupLng ||
        widget.dropLat != oldWidget.dropLat ||
        widget.dropLng != oldWidget.dropLng;

    if (pickupReady && dropReady && endpointsChanged) {
      _fitToTrip();
      return;
    }

    // Only pickup known → center on it.
    if (pickupReady && !dropReady && endpointsChanged) {
      _animateToLocation(LatLng(widget.pickupLat!, widget.pickupLng!), 15);
      return;
    }

    final newLat = widget.centerLat;
    final newLng = widget.centerLng;
    final oldLat = oldWidget.centerLat;
    final oldLng = oldWidget.centerLng;
    if (newLat != null && newLng != null && (newLat != oldLat || newLng != oldLng)) {
      _animateToLocation(LatLng(newLat, newLng), widget.zoom);
    }
  }

  bool _isValid(double? lat, double? lng) =>
      lat != null && lng != null && lat != 0 && lng != 0;

  /// Live tracking: keep the driver and their current destination in view,
  /// tightening as the driver approaches. Falls back to centring on the
  /// driver at street zoom when the destination isn't known yet.
  Future<void> _followDriver() async {
    if (!_controller.isCompleted) return;
    if (!_isValid(widget.driverLat, widget.driverLng)) return;
    final controller = await _controller.future;
    final dLat = widget.driverLat!;
    final dLng = widget.driverLng!;

    if (_isValid(widget.focusLat, widget.focusLng)) {
      final fLat = widget.focusLat!;
      final fLng = widget.focusLng!;
      final bounds = LatLngBounds(
        southwest: LatLng(dLat < fLat ? dLat : fLat, dLng < fLng ? dLng : fLng),
        northeast: LatLng(dLat > fLat ? dLat : fLat, dLng > fLng ? dLng : fLng),
      );
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          await controller
              .animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
          return;
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } else {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(dLat, dLng), zoom: 16),
      ));
    }
  }

  /// Frame the camera so pickup and drop (and the driver, when present) are
  /// all visible with comfortable padding.
  Future<void> _fitToTrip() async {
    if (!_controller.isCompleted) return;
    if (!_isValid(widget.pickupLat, widget.pickupLng) ||
        !_isValid(widget.dropLat, widget.dropLng)) {
      return;
    }
    final controller = await _controller.future;
    // Frame pickup→drop only (driver excluded) so the trip stays tightly
    // zoomed even when the driver is far away.
    final bounds = LatLngBounds(
      southwest: LatLng(
        _min(widget.pickupLat!, widget.dropLat!, null),
        _min(widget.pickupLng!, widget.dropLng!, null),
      ),
      northeast: LatLng(
        _max(widget.pickupLat!, widget.dropLat!, null),
        _max(widget.pickupLng!, widget.dropLng!, null),
      ),
    );
    // newLatLngBounds throws "Map size can't be 0" if called before the map
    // surface is laid out. Retry a couple of times so the fit still lands.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await controller
            .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  Future<void> _animateToLocation(LatLng target, double zoom) async {
    if (_controller.isCompleted) {
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      widget.centerLat ?? widget.pickupLat ?? 20.5937,
      widget.centerLng ?? widget.pickupLng ?? 78.9629,
    );

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Driving-route polyline (yellow, matches Figma "Start Trip" map).
    if (widget.routePolyline != null && widget.routePolyline!.isNotEmpty) {
      final points = decodePolyline(widget.routePolyline!);
      if (points.length >= 2) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: HexColor('#FFD546'),
          width: 5,
        ));
      }
    }

    // Pickup marker — Figma "current location" dot (anchored at its centre).
    if (widget.pickupLat != null && widget.pickupLng != null &&
        widget.pickupLat != 0 && widget.pickupLng != 0) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLat!, widget.pickupLng!),
        icon: _pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 1.0),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ));
    }

    // Drop marker — Figma red location pin (anchored at its tip / bottom).
    if (widget.dropLat != null && widget.dropLng != null &&
        widget.dropLat != 0 && widget.dropLng != 0) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(widget.dropLat!, widget.dropLng!),
        icon: _dropIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
        infoWindow: const InfoWindow(title: 'Drop'),
      ));
    }

    // Driver marker
    if (widget.driverLat != null && widget.driverLng != null &&
        widget.driverLat != 0 && widget.driverLng != 0) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(widget.driverLat!, widget.driverLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Driver'),
      ));
    }

    // Only enable the native "my location" blue dot once we actually have a
    // driver coordinate. Setting myLocationEnabled while runtime location
    // permission is denied causes the GoogleMap surface to render blank on
    // some Android versions — leaving only our overlay zoom buttons visible.
    final hasDriverCoord = widget.driverLat != null &&
        widget.driverLng != null &&
        widget.driverLat != 0 &&
        widget.driverLng != 0;

    return Stack(
      children: [
        GoogleMap(
          // Default Google style (same as the customer "Book a Ride" map).
          mapType: MapType.normal,
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: widget.zoom,
          ),
          markers: markers,
          polylines: polylines,
          // Map gestures only when interactive; otherwise the map must not
          // compete with an overlapping draggable sheet for pan/drag.
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          zoomControlsEnabled: false,
          myLocationEnabled: widget.showMyLocation && hasDriverCoord,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) async {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
            widget.onMapCreated?.call(controller);

            await Future.delayed(const Duration(milliseconds: 200));
            // Live-tracking mode follows the driver; otherwise auto-fit
            // pickup→drop when both are already known at creation time.
            if (widget.followDriver &&
                _isValid(widget.driverLat, widget.driverLng)) {
              await _followDriver();
            } else if (_isValid(widget.pickupLat, widget.pickupLng) &&
                _isValid(widget.dropLat, widget.dropLng)) {
              await _fitToTrip();
            }
          },
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Column(
            children: [
              _zoomButton(Icons.add, () => _changeZoom(1)),
              const SizedBox(height: 4),
              _zoomButton(Icons.remove, () => _changeZoom(-1)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changeZoom(double delta) async {
    if (_controller.isCompleted) {
      final controller = await _controller.future;
      final zoom = await controller.getZoomLevel();
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: await controller.getVisibleRegion().then((r) => LatLng(
            (r.northeast.latitude + r.southwest.latitude) / 2,
            (r.northeast.longitude + r.southwest.longitude) / 2,
          )),
          zoom: (zoom + delta).clamp(2, 20),
        ),
      ));
    }
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  double _min(double a, double b, double? c) {
    double result = a < b ? a : b;
    if (c != null && c != 0 && c < result) result = c;
    return result;
  }

  double _max(double a, double b, double? c) {
    double result = a > b ? a : b;
    if (c != null && c != 0 && c > result) result = c;
    return result;
  }
}
