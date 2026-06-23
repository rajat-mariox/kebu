import 'dart:convert';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  static const String _apiKey = 'AIzaSyCJ5nVBHi7tNCRUgnkzqaYJCZqw9b3tDvc';

  static Future<List<PlacePrediction>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&components=country:in'
      '&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    if (data['status'] != 'OK') return [];

    return (data['predictions'] as List)
        .map((p) => PlacePrediction.fromJson(p))
        .toList();
  }

  static Future<PlaceDetail?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=formatted_address,address_components,geometry'
      '&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    if (data['status'] != 'OK') return null;

    final detail = PlaceDetail.fromJson(data['result']);

    // If postal code is missing, try reverse geocode using lat/lng
    if (detail.zipCode.isEmpty && detail.lat != 0.0 && detail.lng != 0.0) {
      final zip = await _getPostalCodeFromLatLng(detail.lat, detail.lng);
      if (zip.isNotEmpty) {
        return PlaceDetail(
          formattedAddress: detail.formattedAddress,
          city: detail.city,
          state: detail.state,
          country: detail.country,
          zipCode: zip,
          lat: detail.lat,
          lng: detail.lng,
        );
      }
    }

    return detail;
  }

  static Future<String> _getPostalCodeFromLatLng(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng'
      '&result_type=postal_code'
      '&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return '';

    final data = json.decode(response.body);
    if (data['status'] != 'OK') return '';

    final results = data['results'] as List;
    if (results.isEmpty) return '';

    final components = results[0]['address_components'] as List? ?? [];
    for (final c in components) {
      final types = (c['types'] as List).cast<String>();
      if (types.contains('postal_code')) {
        return c['long_name'] ?? '';
      }
    }
    return '';
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structured['main_text'] ?? '',
      secondaryText: structured['secondary_text'] ?? '',
    );
  }
}

class PlaceDetail {
  final String formattedAddress;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final double lat;
  final double lng;

  PlaceDetail({
    required this.formattedAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    required this.lat,
    required this.lng,
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final components = json['address_components'] as List? ?? [];
    final geometry = json['geometry']?['location'] ?? {};

    String city = '';
    String state = '';
    String country = '';
    String zipCode = '';

    for (final c in components) {
      final types = (c['types'] as List).cast<String>();
      if (types.contains('locality')) {
        city = c['long_name'] ?? '';
      } else if (types.contains('administrative_area_level_1')) {
        state = c['long_name'] ?? '';
      } else if (types.contains('country')) {
        country = c['long_name'] ?? '';
      } else if (types.contains('postal_code')) {
        zipCode = c['long_name'] ?? '';
      }
    }

    return PlaceDetail(
      formattedAddress: json['formatted_address'] ?? '',
      city: city,
      state: state,
      country: country,
      zipCode: zipCode,
      lat: (geometry['lat'] ?? 0.0).toDouble(),
      lng: (geometry['lng'] ?? 0.0).toDouble(),
    );
  }
}
