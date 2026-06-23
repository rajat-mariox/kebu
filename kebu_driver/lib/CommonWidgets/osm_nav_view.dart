import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Free, token-less live-navigation map built on OpenStreetMap tiles via
/// `flutter_map` (no Google/Mapbox billing). Draws the driving route, marks
/// the driver and destination, and keeps the camera tracking the driver
/// toward the destination as their GPS updates.
class OsmNavView extends StatefulWidget {
  final double? driverLat;
  final double? driverLng;

  /// The destination the driver is currently heading to (pickup or drop).
  final double? destLat;
  final double? destLng;

  /// Optional pickup/drop markers to also show on the map.
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;

  /// Google-encoded polyline of the active route (driver→destination).
  final String? routePolyline;

  /// Bottom inset (px) reserved for an overlapping sheet, so the framed
  /// markers stay in the visible area above it.
  final double bottomPadding;

  const OsmNavView({
    super.key,
    this.driverLat,
    this.driverLng,
    this.destLat,
    this.destLng,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.routePolyline,
    this.bottomPadding = 0,
  });

  @override
  State<OsmNavView> createState() => _OsmNavViewState();
}

class _OsmNavViewState extends State<OsmNavView> {
  final MapController _ctrl = MapController();
  bool _ready = false;

  bool _valid(double? a, double? b) =>
      a != null && b != null && a != 0 && b != 0;

  @override
  void didUpdateWidget(covariant OsmNavView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.driverLat != oldWidget.driverLat ||
        widget.driverLng != oldWidget.driverLng ||
        widget.destLat != oldWidget.destLat ||
        widget.destLng != oldWidget.destLng;
    if (changed) _track();
  }

  /// Keep the driver and the destination both framed, tightening as the
  /// driver approaches. Falls back to centring on whichever point is known.
  void _track() {
    if (!_ready) return;
    final driver = _valid(widget.driverLat, widget.driverLng)
        ? LatLng(widget.driverLat!, widget.driverLng!)
        : null;
    final dest = _valid(widget.destLat, widget.destLng)
        ? LatLng(widget.destLat!, widget.destLng!)
        : null;

    try {
      if (driver != null && dest != null) {
        _ctrl.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([driver, dest]),
            // Extra bottom padding clears the action sheet.
            padding: EdgeInsets.fromLTRB(50, 90, 50, widget.bottomPadding + 40),
          ),
        );
      } else if (driver != null) {
        _ctrl.move(driver, 16);
      } else if (dest != null) {
        _ctrl.move(dest, 14);
      }
    } catch (_) {
      // Camera ops can throw if called before layout — ignored; the next
      // GPS tick will retry.
    }
  }

  /// Decode a Google-encoded polyline into latlong2 points for flutter_map.
  List<LatLng> _decode(String encoded) {
    final points = <LatLng>[];
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

  @override
  Widget build(BuildContext context) {
    final center = _valid(widget.driverLat, widget.driverLng)
        ? LatLng(widget.driverLat!, widget.driverLng!)
        : _valid(widget.destLat, widget.destLng)
            ? LatLng(widget.destLat!, widget.destLng!)
            : const LatLng(17.385, 78.4867); // Hyderabad fallback

    final routePts = (widget.routePolyline != null &&
            widget.routePolyline!.isNotEmpty)
        ? _decode(widget.routePolyline!)
        : <LatLng>[];

    final markers = <Marker>[];
    if (_valid(widget.pickupLat, widget.pickupLng)) {
      markers.add(_pinMarker(
        LatLng(widget.pickupLat!, widget.pickupLng!),
        'assets/booking_buzzer/pickup_pin.png',
      ));
    }
    if (_valid(widget.dropLat, widget.dropLng)) {
      markers.add(_pinMarker(
        LatLng(widget.dropLat!, widget.dropLng!),
        'assets/booking_buzzer/destination_pin.png',
      ));
    }
    if (_valid(widget.driverLat, widget.driverLng)) {
      markers.add(Marker(
        point: LatLng(widget.driverLat!, widget.driverLng!),
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2F6FED),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
            ],
          ),
        ),
      ));
    }

    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        // Non-interactive: the camera auto-follows and the screen has a
        // draggable sheet, so map gestures shouldn't compete.
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.none),
        onMapReady: () {
          _ready = true;
          _track();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kebu.kebu_driver',
        ),
        if (routePts.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePts,
                color: const Color(0xFF2F6FED),
                strokeWidth: 6,
              ),
            ],
          ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }

  Marker _pinMarker(LatLng point, String asset) {
    return Marker(
      point: point,
      width: 36,
      height: 48,
      // Anchor the pin's tip (its bottom-centre) on the coordinate.
      alignment: Alignment.bottomCenter,
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
