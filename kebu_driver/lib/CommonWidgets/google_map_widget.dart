import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  /// Driver's real direction of travel (degrees, 0–360 clockwise from north),
  /// from the GPS fix. When valid (>= 0) in [navigationMode], the camera and
  /// the heading arrow rotate to match the road the driver is actually on, so
  /// upcoming turns read correctly. Falls back to the straight-line bearing to
  /// the destination when unknown (-1, e.g. stationary).
  final double driverHeading;

  /// Turn-by-turn navigation camera: instead of framing driver+destination in
  /// a flat top-down box, keep a close, tilted (3D) view centred on the driver
  /// and rotated so "up" points toward the destination — the real-navigation
  /// look. Requires [followDriver]. Falls back to the bounds framing when the
  /// driver/destination coords aren't available yet.
  final bool navigationMode;

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
    this.navigationMode = false,
    this.driverHeading = -1,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  final Completer<GoogleMapController> _controller = Completer();

  // Memoised polyline decode. Decoding the Google-encoded string into LatLng
  // points is CPU-heavy and the source rarely changes, yet build() can run on
  // every GPS tick (the map sits inside an Obx). Cache by source string so we
  // only decode when the route actually changes.
  String? _decodedPolylineSource;
  List<LatLng> _decodedPolyline = const [];

  // Exact Figma map-pin icons. Null until loaded; markers fall back to default
  // coloured pins meanwhile.
  //   • _pickupIcon  — customer pickup: red pin with a person avatar
  //   • _driverIcon  — the driver's own location: blue concentric target pin
  //   • _dropIcon    — destination: red location pin
  //   • _navArrowIcon — turn-by-turn heading arrow (used in navigationMode)
  static BitmapDescriptor? _pickupIcon;
  static BitmapDescriptor? _dropIcon;
  static BitmapDescriptor? _driverIcon;
  static BitmapDescriptor? _navArrowIcon;

  // The native Google Map surface takes a beat to initialise on Android (a
  // grey flash before the first tiles paint). We mask that with a light
  // placeholder until onMapCreated fires, so the screen never shows a blank
  // map. Flips to true once and stays true.
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    if (_pickupIcon != null &&
        _dropIcon != null &&
        _driverIcon != null &&
        _navArrowIcon != null) {
      return;
    }
    try {
      _pickupIcon = await _bitmapFromPng(
          'assets/booking_buzzer/pickup_person_marker.png', 40);
      _dropIcon =
          await _bitmapFromPng('assets/booking_buzzer/destination_pin.png', 38);
      _driverIcon = await _bitmapFromPng(
          'assets/booking_buzzer/driver_location_marker.png', 40);
      _navArrowIcon =
          await _bitmapFromPng('assets/booking_buzzer/nav_arrow.png', 44);
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
      // Re-aim the camera when the driver turns, so "up" tracks the road even
      // when they're moving slowly (small position deltas, big heading change).
      final headingChanged = widget.driverHeading != oldWidget.driverHeading;
      if (driverChanged || focusChanged || headingChanged) _followDriver();
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

  /// Live tracking: keep the camera centred on the driver so they always see
  /// the road ahead and upcoming turns. In navigation mode it's a close,
  /// tilted, heading-aligned turn-by-turn view; otherwise (e.g. en route to
  /// pickup) a flat, north-up, street-level follow.
  Future<void> _followDriver() async {
    if (!_controller.isCompleted) return;
    if (!_isValid(widget.driverLat, widget.driverLng)) return;
    final controller = await _controller.future;
    final dLat = widget.driverLat!;
    final dLng = widget.driverLng!;

    final cam = CameraPosition(
      target: LatLng(dLat, dLng),
      zoom: widget.navigationMode ? 17.5 : 16.5,
      tilt: widget.navigationMode ? 60 : 0,
      bearing: widget.navigationMode ? _navHeading() : 0,
    );
    // animateCamera throws "Map size can't be 0" if the surface isn't laid out
    // yet (common right after the screen opens). Retry a few times so the
    // follow reliably engages instead of leaving the camera where it started.
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        await controller.animateCamera(CameraUpdate.newCameraPosition(cam));
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
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

  /// The camera the map opens on. When both pickup and drop are already known
  /// at first build, frame their midpoint at a zoom that fits the span so both
  /// markers are visible from the first frame (no pan-in after load). Falls
  /// back to centre/pickup otherwise. [_fitToTrip] later refines this precisely
  /// once the controller is available and the surface is laid out.
  CameraPosition _initialCamera() {
    final pValid = _isValid(widget.pickupLat, widget.pickupLng);
    final dValid = _isValid(widget.dropLat, widget.dropLng);
    if (pValid && dValid) {
      return CameraPosition(
        target: LatLng(
          (widget.pickupLat! + widget.dropLat!) / 2,
          (widget.pickupLng! + widget.dropLng!) / 2,
        ),
        zoom: _zoomForBounds(widget.pickupLat!, widget.pickupLng!,
            widget.dropLat!, widget.dropLng!),
      );
    }
    return CameraPosition(
      target: LatLng(
        widget.centerLat ?? widget.pickupLat ?? 20.5937,
        widget.centerLng ?? widget.pickupLng ?? 78.9629,
      ),
      zoom: widget.zoom,
    );
  }

  /// Approximate the Google Maps zoom level that frames the lat/lng box
  /// between two points, with a little padding so the markers aren't flush to
  /// the edges. Precise framing is done by [_fitToTrip]; this only needs to be
  /// close so the initial tiles load over the right region.
  double _zoomForBounds(
      double lat1, double lng1, double lat2, double lng2) {
    final maxDiff = math.max((lat1 - lat2).abs(), (lng1 - lng2).abs());
    if (maxDiff <= 0) return 15;
    // The world spans 360° at zoom 0 and halves each level: zoom ≈ log2(360/span).
    // Subtract ~1.2 levels of padding and clamp to sane bounds.
    final zoom = (math.log(360 / maxDiff) / math.ln2) - 1.2;
    return zoom.clamp(3.0, 16.0);
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
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Driving-route / tracking polyline — navigation blue (#2F6FED).
    if (widget.routePolyline != null && widget.routePolyline!.isNotEmpty) {
      if (widget.routePolyline != _decodedPolylineSource) {
        _decodedPolylineSource = widget.routePolyline;
        _decodedPolyline = decodePolyline(widget.routePolyline!);
      }
      final points = _decodedPolyline;
      if (points.length >= 2) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF2F6FED),
          width: 6,
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

    // Driver marker. In navigation mode (start-trip / on-route nav view) it's
    // a flat heading arrow that rotates toward the destination — the turn-by-
    // turn look. Otherwise it's the blue concentric "current location" pin.
    if (widget.driverLat != null && widget.driverLng != null &&
        widget.driverLat != 0 && widget.driverLng != 0) {
      // Show the heading arrow during navigation whenever we can derive a
      // direction — the driver's real GPS heading, or (stationary) the bearing
      // toward the destination via [_navHeading].
      final useNavArrow = widget.navigationMode &&
          _navArrowIcon != null &&
          (widget.driverHeading >= 0 ||
              _isValid(widget.focusLat, widget.focusLng));
      final heading = useNavArrow ? _navHeading() : 0.0;
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(widget.driverLat!, widget.driverLng!),
        icon: useNavArrow
            ? _navArrowIcon!
            : (_driverIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure)),
        // Arrow sits flat on the map and rotates with heading; the pin stays
        // upright anchored at its tip.
        anchor: useNavArrow ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
        rotation: heading,
        flat: useNavArrow,
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
          // Frame pickup→drop from the very first frame when both are known,
          // so the trip (and both markers) is in view immediately instead of
          // opening on the pickup and panning out after the map loads.
          initialCameraPosition: _initialCamera(),
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

            // Surface is up — drop the loading placeholder.
            if (mounted && !_mapReady) setState(() => _mapReady = true);

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
        // Loading placeholder over the map until the native surface is ready,
        // so the user never sees the raw grey platform-view flash.
        if (!_mapReady)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: const Color(0xFFEAEFF5),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2C54C1)),
                  ),
                ),
              ),
            ),
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

  /// The bearing the navigation camera (and heading arrow) should point at.
  /// Prefers the driver's real GPS direction of travel so the road ahead is
  /// "up" and turns read correctly; falls back to the straight-line bearing to
  /// the destination when the device heading is unknown (stationary), and to
  /// north (0) when there's no destination either.
  double _navHeading() {
    if (widget.driverHeading >= 0) return widget.driverHeading;
    if (_isValid(widget.driverLat, widget.driverLng) &&
        _isValid(widget.focusLat, widget.focusLng)) {
      return _bearing(widget.driverLat!, widget.driverLng!,
          widget.focusLat!, widget.focusLng!);
    }
    return 0;
  }

  /// Initial bearing (degrees, 0–360) from one lat/lng to another, used to
  /// orient the navigation camera so the driver's heading points "up".
  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
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
