import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:golorry_customer_app/utils/map_constants.dart';

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final int distanceValue;
  final int durationValue;

  DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
  });
}

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final String apiKey = MapConstants.googleMapsApiKey;
    final url = '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving&key=$apiKey';

    print('DEBUG [DirectionsService]: Requesting URL: $url');

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('DEBUG [DirectionsService] ERROR: HTTP ${response.statusCode} - ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      
      // 1. Log COMPLETE Response for verification
      print('DEBUG [DirectionsService] FULL RESPONSE: $data');
      print('DEBUG [DirectionsService] STATUS: ${data['status']}');
      
      if (data['status'] != 'OK') {
        print('DEBUG [DirectionsService] API ERROR: ${data['error_message'] ?? 'No error message provided'}');
        return null;
      }

      final routes = data['routes'] as List;
      print('DEBUG [DirectionsService] ROUTES COUNT: ${routes.length}');

      if (routes.isEmpty) {
        print('DEBUG [DirectionsService] ERROR: No routes found in response');
        return null;
      }

      final route = routes[0];
      final leg = route['legs'][0];
      
      // 2. Log Overview Polyline
      final encodedPolyline = route['overview_polyline']['points'];
      print('DEBUG [DirectionsService] OVERVIEW_POLYLINE.POINTS: $encodedPolyline');

      // Professional Decoding
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
      
      // 3. Log Decoded Points Count
      print('DEBUG [DirectionsService] TOTAL DECODED POINTS: ${decodedPoints.length}');

      if (decodedPoints.isEmpty) {
        print('DEBUG [DirectionsService] WARNING: Decoded points list is EMPTY');
        return null;
      }

      // 4. Log First 10 Coordinates
      final int logCount = decodedPoints.length > 10 ? 10 : decodedPoints.length;
      print('DEBUG [DirectionsService] FIRST $logCount COORDINATES:');
      for (int i = 0; i < logCount; i++) {
        print('  - Point $i: ${decodedPoints[i].latitude}, ${decodedPoints[i].longitude}');
      }
      
      List<LatLng> points = decodedPoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      print('DEBUG [DirectionsService]: FINAL List<LatLng> LENGTH: ${points.length}');

      return DirectionsResult(
        polylinePoints: points,
        distance: leg['distance']['text'],
        duration: leg['duration']['text'],
        distanceValue: leg['distance']['value'],
        durationValue: leg['duration']['value'],
      );
    } catch (e) {
      print('DEBUG [DirectionsService] CRITICAL ERROR: $e');
      // Fallback: Return a straight line so the app doesn't break
      return DirectionsResult(
        polylinePoints: [origin, destination],
        distance: 'Calculating...',
        duration: 'Calculating...',
        distanceValue: 0,
        durationValue: 0,
      );
    }
  }
}
