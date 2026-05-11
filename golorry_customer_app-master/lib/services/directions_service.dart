import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final double durationMin;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMin,
  });
}

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  final String apiKey;

  DirectionsService(this.apiKey);

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Directions API Error: HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        print('Directions API Error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        return null;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      final distanceKm = leg['distance']['value'] / 1000.0;
      final durationMin = leg['duration']['value'] / 60.0;

      // Use the official polyline_points package for decoding
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(route['overview_polyline']['points']);
      
      List<LatLng> points = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

      return DirectionsResult(
        polylinePoints: points,
        distanceKm: distanceKm,
        durationMin: durationMin,
      );
    } catch (e) {
      print('Directions Service Exception: $e');
      return null;
    }
  }
}
