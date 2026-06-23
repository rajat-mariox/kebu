import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A reusable OpenStreetMap widget that displays free tile maps.
/// Supports markers for pickup, drop, and driver locations.
class OsmMapWidget extends StatelessWidget {
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
  final MapController? mapController;

  const OsmMapWidget({
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
    this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    // Default center: India (Hyderabad)
    final center = LatLng(
      centerLat ?? pickupLat ?? 17.385,
      centerLng ?? pickupLng ?? 78.4867,
    );

    final markers = <Marker>[];

    // Pickup marker
    if (pickupLat != null && pickupLng != null && pickupLat != 0 && pickupLng != 0) {
      markers.add(Marker(
        point: LatLng(pickupLat!, pickupLng!),
        width: 40,
        height: 40,
        child: const Icon(Icons.circle, color: Colors.green, size: 18),
      ));
    }

    // Drop marker
    if (dropLat != null && dropLng != null && dropLat != 0 && dropLng != 0) {
      markers.add(Marker(
        point: LatLng(dropLat!, dropLng!),
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 28),
      ));
    }

    // Driver marker
    if (driverLat != null && driverLng != null && driverLat != 0 && driverLng != 0) {
      markers.add(Marker(
        point: LatLng(driverLat!, driverLng!),
        width: 40,
        height: 40,
        child: const Icon(Icons.local_taxi, color: Colors.amber, size: 28),
      ));
    }

    // If we have both pickup and drop, auto-fit bounds
    LatLngBounds? bounds;
    if (pickupLat != null && pickupLat != 0 && dropLat != null && dropLat != 0) {
      final points = <LatLng>[
        LatLng(pickupLat!, pickupLng!),
        LatLng(dropLat!, dropLng!),
      ];
      if (driverLat != null && driverLat != 0) {
        points.add(LatLng(driverLat!, driverLng!));
      }
      bounds = LatLngBounds.fromPoints(points);
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: bounds != null
            ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50))
            : null,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kebu.kebu_driver',
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}
