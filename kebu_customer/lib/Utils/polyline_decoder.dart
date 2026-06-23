import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decode a Google encoded polyline string into a list of LatLng points.
/// Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
List<LatLng> decodePolyline(String encoded) {
  final result = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int b;
    int shift = 0;
    int change = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      change |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (change & 1) != 0 ? ~(change >> 1) : (change >> 1);
    lat += dlat;

    shift = 0;
    change = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      change |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (change & 1) != 0 ? ~(change >> 1) : (change >> 1);
    lng += dlng;

    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}
