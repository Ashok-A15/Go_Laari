import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  final String _apiKey;

  GeocodingService(this._apiKey);

  Future<LatLng?> getCoordinates(String address) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDirections(String origin, String destination) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}&key=$_apiKey');
    return _fetchDirections(url);
  }

  Future<Map<String, dynamic>?> getDirectionsFromLatLng(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey');
    return _fetchDirections(url);
  }

  Future<Map<String, dynamic>?> _fetchDirections(Uri url) async {
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          return {
            'distance': leg['distance']['text'],
            'distanceValue': leg['distance']['value'],
            'duration': leg['duration']['text'],
            'durationValue': leg['duration']['value'],
            'polyline': route['overview_polyline']['points'],
          };
        } else {
          print('Directions API Status: ${data['status']} - ${data['error_message'] ?? ''}');
        }
      }
    } catch (e) {
      print('Directions API error: $e');
    }
    return null;
  }
}
