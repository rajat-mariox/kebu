import 'package:kebu_driver/Utils/ApiClient/api_client.dart';

class MapsApiService {
  /// GET /maps/places/search
  static Future<ApiResponse> searchPlaces(String query, {double? lat, double? lng}) async {
    final params = <String, String>{'query': query};
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    return await ApiClient.get('/maps/places/search', queryParams: params);
  }

  /// GET /maps/places/:placeId
  static Future<ApiResponse> getPlaceDetails(String placeId) async {
    return await ApiClient.get('/maps/places/$placeId');
  }

  /// GET /maps/geocode/reverse
  static Future<ApiResponse> reverseGeocode({required double lat, required double lng}) async {
    return await ApiClient.get('/maps/geocode/reverse', queryParams: {
      'lat': lat.toString(),
      'lng': lng.toString(),
    });
  }

  /// GET /maps/distance
  static Future<ApiResponse> getDistanceAndDuration({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    return await ApiClient.get('/maps/distance', queryParams: {
      'originLat': originLat.toString(),
      'originLng': originLng.toString(),
      'destLat': destLat.toString(),
      'destLng': destLng.toString(),
    });
  }

  /// POST /maps/directions
  static Future<ApiResponse> getDirections({
    required Map<String, dynamic> origin,
    required Map<String, dynamic> destination,
    List<Map<String, dynamic>>? waypoints,
  }) async {
    final body = <String, dynamic>{
      'origin': origin,
      'destination': destination,
    };
    if (waypoints != null) body['waypoints'] = waypoints;
    return await ApiClient.post('/maps/directions', body: body);
  }
}
