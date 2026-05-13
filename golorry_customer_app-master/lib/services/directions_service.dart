import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final double durationMin;
  final String overviewPolyline;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMin,
    required this.overviewPolyline,
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
        '&mode=driving&departure_time=now&key=$apiKey';

    print('DEBUG [DirectionsService]: Requesting URL: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('DEBUG [DirectionsService] Error: HTTP ${response.statusCode} - ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      
      // 1. Print FULL response status and routes count
      print('DEBUG [DirectionsService] Status: ${data['status']}');
      if (data['routes'] != null) {
        print('DEBUG [DirectionsService] Routes Array Count: ${(data['routes'] as List).length}');
      }

      if (data['status'] != 'OK') {
        print('DEBUG [DirectionsService] Error Message: ${data['error_message'] ?? 'No message'}');
        return null;
      }

      if ((data['routes'] as List).isEmpty) {
        print('DEBUG [DirectionsService] Error: Routes array is empty');
        return null;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      final distanceKm = leg['distance']['value'] / 1000.0;
      final durationMin = leg['duration']['value'] / 60.0;
      
      // 2. Verify overview_polyline exists
      if (route['overview_polyline'] == null || route['overview_polyline']['points'] == null) {
        print('DEBUG [DirectionsService] Error: overview_polyline.points is MISSING');
        return null;
      }

      final encodedPolyline = route['overview_polyline']['points'];
      print('DEBUG [DirectionsService] Overview Polyline (Points String): $encodedPolyline');

      // 3. Decode polyline
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
      
      print('DEBUG [DirectionsService] Total decoded points: ${result.length}');

      if (result.isEmpty) {
        print('DEBUG [DirectionsService] Warning: Decoded points list is EMPTY');
        return null;
      }

      // 4. Log first 10 coordinates as requested
      final int logCount = result.length > 10 ? 10 : result.length;
      print('DEBUG [DirectionsService] First $logCount decoded coordinates:');
      for (int i = 0; i < logCount; i++) {
        print('  Point $i: ${result[i].latitude}, ${result[i].longitude}');
      }

      // 5. Convert ALL decoded points into List<LatLng>
      List<LatLng> points = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
      
      if (points.length <= 2) {
        print('DEBUG [DirectionsService] Warning: Only ${points.length} points found. This might render as a straight line if the distance is large.');
      }

      return DirectionsResult(
        polylinePoints: points,
        distanceKm: distanceKm,
        durationMin: durationMin,
        overviewPolyline: encodedPolyline,
      );
    } catch (e, stack) {
      print('DEBUG [DirectionsService] Exception: $e');
      print('DEBUG [DirectionsService] Stack: $stack');
      return null;
    }
  }
}
