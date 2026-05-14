import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' show cos, sqrt, asin;

class GeocodingService {
  final String _apiKey;

  GeocodingService(this._apiKey);

  // ─── Geocoding (Address → LatLng) ───────────────────────────
  Future<LatLng?> getCoordinates(String address) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey');

    print('DEBUG [GeocodingService] getCoordinates: "$address"');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG [GeocodingService] Geocode status: ${data['status']}');
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          print('DEBUG [GeocodingService] Resolved: $address → ${latLng.latitude}, ${latLng.longitude}');
          return latLng;
        } else {
          print('DEBUG [GeocodingService] ERROR: ${data['status']} - ${data['error_message'] ?? 'No error_message'}');
        }
      } else {
        print('DEBUG [GeocodingService] HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG [GeocodingService] getCoordinates EXCEPTION: $e');
    }
    return null;
  }

  // ─── Reverse Geocoding (LatLng → Address) ───────────────────
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey');

    print('DEBUG [GeocodingService] getAddressFromCoordinates: ($lat, $lng)');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG [GeocodingService] Reverse Geocode status: ${data['status']}');
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'];
          print('DEBUG [GeocodingService] Address: $address');
          return address;
        } else {
          print('DEBUG [GeocodingService] ERROR: ${data['status']} - ${data['error_message'] ?? 'No error_message'}');
        }
      } else {
        print('DEBUG [GeocodingService] HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG [GeocodingService] getAddressFromCoordinates EXCEPTION: $e');
    }
    return null;
  }

  // ─── Get City Name from Coordinates ─────────────────────────
  Future<String> getCityFromCoordinates(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey');

    print('DEBUG [GeocodingService] getCityFromCoordinates: ($lat, $lng)');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG [GeocodingService] City Geocode status: ${data['status']}');
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final addressComponents = data['results'][0]['address_components'] as List;
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              final city = component['long_name'];
              print('DEBUG [GeocodingService] City: $city');
              return city;
            }
          }
        } else {
          print('DEBUG [GeocodingService] ERROR: ${data['status']} - ${data['error_message'] ?? 'No error_message'}');
        }
      } else {
        print('DEBUG [GeocodingService] HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG [GeocodingService] getCityFromCoordinates EXCEPTION: $e');
    }
    return 'India';
  }

  // ─── Places Autocomplete ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAutocomplete(String input) async {
    if (input.isEmpty) return [];

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_apiKey&components=country:in');

    print('DEBUG [GeocodingService] Places Autocomplete: "$input"');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG [GeocodingService] Autocomplete status: ${data['status']}');
        if (data['status'] == 'OK') {
          final predictions = List<Map<String, dynamic>>.from(data['predictions']);
          print('DEBUG [GeocodingService] Autocomplete results: ${predictions.length} predictions');
          return predictions;
        } else {
          print('DEBUG [GeocodingService] Autocomplete ERROR: ${data['status']} - ${data['error_message'] ?? 'No error_message'}');
        }
      } else {
        print('DEBUG [GeocodingService] HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG [GeocodingService] getAutocomplete EXCEPTION: $e');
    }
    return [];
  }
}
