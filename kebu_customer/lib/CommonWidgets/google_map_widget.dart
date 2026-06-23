import 'dart:async';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:kebu_customer/Utils/polyline_decoder.dart';

/// A reusable Google Maps widget with the same interface as OsmMapWidget.
/// Supports markers for pickup, drop, driver, and nearby vehicles.
class GoogleMapWidget extends StatefulWidget {
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;

  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final double? driverLat;
  final double? driverLng;

  /// Heading (degrees, 0 = north) the driver vehicle is travelling. Rotates the
  /// car marker so it points the way it's actually moving while tracking.
  final double? driverHeading;

  /// Live-tracking mode: keep the camera following the driver as it approaches
  /// the pickup. On each driver-location update the camera smoothly re-frames
  /// the driver together with the pickup so the customer always sees the gap
  /// closing in real time. Throttled internally to ignore GPS jitter.
  final bool followDriver;

  final bool interactive;
  final List<Map<String, dynamic>>? nearbyVehicles;

  /// Vehicle type name of the assigned driver (e.g. "Bike", "Auto", "Normal"),
  /// used to pick the correct map marker icon during live tracking. Falls back
  /// to the car marker when unknown.
  final String? driverVehicleType;

  final void Function(GoogleMapController)? onMapCreated;
  final bool showMyLocation;
  final bool? liteModeEnabled;
  final double? radiusLat;
  final double? radiusLng;
  final double? radiusMeters;

  /// Show the custom +/- zoom buttons overlay (bottom-right). Disable on
  /// compact preview maps (e.g. the booking entry screen) where the design
  /// has no map controls.
  final bool showZoomButtons;

  /// Google-encoded polyline for the driving route (origin → destination).
  /// When set, drawn as a yellow line on the map. Used by ride-tracking to
  /// show the actual road path instead of a straight-line approximation.
  final String? routePolyline;

  /// Draw the default pickup marker. Disable when the screen overlays its own
  /// center pickup indicator (e.g. the Uber-style "Book a cab" map).
  final bool showPickupMarker;

  /// Called when the camera settles, with the new map center — used by the
  /// "Book a cab" map to re-anchor the pickup to wherever the map is dragged.
  final void Function(LatLng center)? onCameraIdle;

  /// Map padding — shifts the camera focal point so it lands in the visible
  /// area when a bottom sheet covers part of the map.
  final EdgeInsets? padding;

  /// Hue of the default pickup marker. Defaults to green.
  final double pickupMarkerHue;

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
    this.driverHeading,
    this.followDriver = false,
    this.interactive = false,
    this.nearbyVehicles,
    this.driverVehicleType,
    this.onMapCreated,
    this.showMyLocation = true,
    this.liteModeEnabled,
    this.radiusLat,
    this.radiusLng,
    this.radiusMeters,
    this.routePolyline,
    this.showZoomButtons = true,
    this.showPickupMarker = true,
    this.onCameraIdle,
    this.padding,
    this.pickupMarkerHue = BitmapDescriptor.hueGreen,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  final Completer<GoogleMapController> _controller = Completer();

  // Per-vehicle-type marker icons, keyed by local asset path. Static so the
  // decoded bitmaps are shared/cached across every map instance.
  static final Map<String, BitmapDescriptor> _iconCache = {};

  /// Map a backend vehicle-type name to the local marker asset. Bikes/scooters
  /// and autos/rickshaws get their own icon; everything else uses the car.
  /// All are upright side-view icons so they stand on the map like pins
  /// instead of lying flat.
  static String _assetForType(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('bike') || t.contains('scooter') || t.contains('moto')) {
      return 'assets/bike.png';
    }
    if (t.contains('auto') ||
        t.contains('ricksha') ||
        t.contains('ricsha') ||
        t.contains('rickshaw') ||
        t.contains('tuk')) {
      return 'assets/ricsha.png';
    }
    return 'assets/economy_car.png';
  }

  static double _widthForAsset(String asset) =>
      asset == 'assets/bike.png' ? 34 : 44;

  BitmapDescriptor? _iconFor(String? type) => _iconCache[_assetForType(type)];

  /// Decode any not-yet-cached marker assets, then repaint so the markers swap
  /// from the default pin to the real vehicle icon. No-ops once all are loaded.
  Future<void> _ensureIcons(Set<String> assets) async {
    var changed = false;
    for (final asset in assets) {
      if (_iconCache.containsKey(asset)) continue;
      try {
        final data = await rootBundle.load(asset);
        _iconCache[asset] = BitmapDescriptor.bytes(
          data.buffer.asUint8List(),
          width: _widthForAsset(asset),
        );
        changed = true;
      } catch (_) {
        // Leave this type on the default marker if its asset is missing.
      }
    }
    if (changed && mounted) setState(() {});
  }

  // Last camera center / zoom — tracked so onCameraIdle can report where the
  // map is and so re-centres preserve the user's current zoom level.
  LatLng? _lastCenter;
  double? _lastZoom;

  // Last driver position the follow-camera animated to, so we can ignore
  // sub-threshold GPS jitter and avoid the camera twitching on every ping.
  LatLng? _lastFollowTarget;

  @override
  void initState() {
    super.initState();
    // Preload the car marker; per-type icons load on demand from build().
    _ensureIcons({'assets/economy_car.png'});
  }

  @override
  void didUpdateWidget(covariant GoogleMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Live-tracking takes over the camera: follow the driver as it moves so
    // the focus stays on the approaching vehicle in real time.
    if (widget.followDriver &&
        widget.driverLat != null &&
        widget.driverLng != null &&
        widget.driverLat != 0 &&
        widget.driverLng != 0) {
      final moved = widget.driverLat != oldWidget.driverLat ||
          widget.driverLng != oldWidget.driverLng;
      if (moved) _followDriver();
      return;
    }

    final newLat = widget.centerLat ?? widget.pickupLat;
    final newLng = widget.centerLng ?? widget.pickupLng;
    final oldLat = oldWidget.centerLat ?? oldWidget.pickupLat;
    final oldLng = oldWidget.centerLng ?? oldWidget.pickupLng;
    if (newLat != null && newLng != null && (newLat != oldLat || newLng != oldLng)) {
      // Preserve the zoom the user has set instead of snapping back to the
      // initial zoom on every re-centre.
      _animateToLocation(LatLng(newLat, newLng), _lastZoom ?? widget.zoom);
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

  /// Smoothly re-frames the camera on the moving driver. When the pickup is
  /// known, fits both the driver and the pickup in view so the camera
  /// naturally zooms in as the vehicle gets closer; otherwise just centres on
  /// the driver. Ignores moves under ~20 m so GPS jitter doesn't jiggle the map.
  Future<void> _followDriver() async {
    if (!_controller.isCompleted) return;
    final dLat = widget.driverLat!, dLng = widget.driverLng!;

    final last = _lastFollowTarget;
    if (last != null) {
      final movedMeters = Geolocator.distanceBetween(
        last.latitude, last.longitude, dLat, dLng,
      );
      if (movedMeters < 20) return;
    }
    _lastFollowTarget = LatLng(dLat, dLng);

    final controller = await _controller.future;
    final pLat = widget.pickupLat, pLng = widget.pickupLng;

    if (pLat != null && pLng != null && pLat != 0 && pLng != 0) {
      final bounds = LatLngBounds(
        southwest: LatLng(dLat < pLat ? dLat : pLat, dLng < pLng ? dLng : pLng),
        northeast: LatLng(dLat > pLat ? dLat : pLat, dLng > pLng ? dLng : pLng),
      );
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
    } else {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(dLat, dLng), zoom: _lastZoom ?? 16),
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
    final circles = <Circle>{};
    final polylines = <Polyline>{};

    // Make sure the marker icons for every vehicle type currently on the map
    // (assigned driver + all nearby vehicles) are decoded and cached.
    final neededAssets = <String>{
      'assets/economy_car.png',
      _assetForType(widget.driverVehicleType),
      if (widget.nearbyVehicles != null)
        for (final v in widget.nearbyVehicles!)
          _assetForType(v['vehicleType']?.toString()),
    };
    _ensureIcons(neededAssets);

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

    // Pickup marker
    if (widget.showPickupMarker &&
        widget.pickupLat != null && widget.pickupLng != null &&
        widget.pickupLat != 0 && widget.pickupLng != 0) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLat!, widget.pickupLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(widget.pickupMarkerHue),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ));
    }

    // Drop marker
    if (widget.dropLat != null && widget.dropLng != null &&
        widget.dropLat != 0 && widget.dropLng != 0) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: LatLng(widget.dropLat!, widget.dropLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop'),
      ));
    }

    // Driver marker — rendered as small vehicle icon (falls back to default
    // marker until the cached bitmap is ready on first paint).
    if (widget.driverLat != null && widget.driverLng != null &&
        widget.driverLat != 0 && widget.driverLng != 0) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(widget.driverLat!, widget.driverLng!),
        icon: _iconFor(widget.driverVehicleType) ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        // Upright billboard pinned at its base so the vehicle stands on the
        // map instead of lying flat.
        anchor: const Offset(0.5, 1.0),
        infoWindow: const InfoWindow(title: 'Driver'),
      ));
    }

    // Nearby vehicle markers — top-down Figma car, rotated by heading.
    if (widget.nearbyVehicles != null) {
      for (int i = 0; i < widget.nearbyVehicles!.length; i++) {
        final vehicle = widget.nearbyVehicles![i];
        final vLat = (vehicle['latitude'] ?? 0).toDouble();
        final vLng = (vehicle['longitude'] ?? 0).toDouble();
        if (vLat != 0 && vLng != 0) {
          // Key the marker by the driver id (stable across rebuilds) so the
          // map diffs add/remove/move cleanly and markers don't flicker when
          // the nearby list changes. Fall back to index only if id is absent.
          final driverId = vehicle['id']?.toString();
          final markerKey =
              (driverId != null && driverId.isNotEmpty) ? 'vehicle_$driverId' : 'vehicle_$i';
          final asset = _assetForType(vehicle['vehicleType']?.toString());
          markers.add(Marker(
            markerId: MarkerId(markerKey),
            position: LatLng(vLat, vLng),
            icon: _iconCache[asset] ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            // Upright billboard pinned at its base (see driver marker note).
            anchor: const Offset(0.5, 1.0),
          ));
        }
      }
    }

    if (widget.radiusLat != null &&
        widget.radiusLng != null &&
        widget.radiusMeters != null &&
        widget.radiusMeters! > 0) {
      circles.add(
        Circle(
          circleId: const CircleId('pickup_radius'),
          center: LatLng(widget.radiusLat!, widget.radiusLng!),
          radius: widget.radiusMeters!,
          strokeWidth: 2,
          strokeColor: Colors.red.withValues(alpha: 0.8),
          fillColor: Colors.red.withValues(alpha: 0.12),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          liteModeEnabled: widget.liteModeEnabled ?? !widget.interactive,
          padding: widget.padding ?? EdgeInsets.zero,
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: widget.zoom,
          ),
          markers: markers,
          circles: circles,
          polylines: polylines,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          // Let the map win pan/zoom gestures even inside a scrolling parent
          // (e.g. the booking screen's SingleChildScrollView).
          gestureRecognizers: widget.interactive
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer()),
                }
              : const <Factory<OneSequenceGestureRecognizer>>{},
          zoomControlsEnabled: false,
          minMaxZoomPreference: const MinMaxZoomPreference(
            GoogleMapWidget.minZoom,
            GoogleMapWidget.maxZoom,
          ),
          myLocationEnabled: widget.showMyLocation,
          myLocationButtonEnabled: false,
          onCameraMove: (pos) {
            _lastCenter = pos.target;
            _lastZoom = pos.zoom;
          },
          onCameraIdle: widget.onCameraIdle != null
              ? () {
                  final c = _lastCenter;
                  if (c != null) widget.onCameraIdle!(c);
                }
              : null,
          onMapCreated: (controller) async {
            if (!_controller.isCompleted) {
              _controller.complete(controller);
            }
            widget.onMapCreated?.call(controller);

            // Auto-fit bounds if both pickup and drop exist
            if (widget.pickupLat != null && widget.pickupLat != 0 &&
                widget.dropLat != null && widget.dropLat != 0) {
              final bounds = LatLngBounds(
                southwest: LatLng(
                  _min(widget.pickupLat!, widget.dropLat!, widget.driverLat),
                  _min(widget.pickupLng!, widget.dropLng!, widget.driverLng),
                ),
                northeast: LatLng(
                  _max(widget.pickupLat!, widget.dropLat!, widget.driverLat),
                  _max(widget.pickupLng!, widget.dropLng!, widget.driverLng),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 200));
              controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
            }
          },
        ),
        if (widget.showZoomButtons)
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
          zoom: (zoom + delta).clamp(GoogleMapWidget.minZoom, GoogleMapWidget.maxZoom),
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
