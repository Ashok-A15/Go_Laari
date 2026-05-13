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

    print('DEBUG: Requesting Directions API: $url');

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('DEBUG Error: HTTP ${response.statusCode} - ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      
      // 1. Print FULL response for debugging
      print('DEBUG RAW JSON: ${json.encode(data)}');

      if (data['status'] != 'OK') {
        print('DEBUG Error: API Status ${data['status']} - ${data['error_message'] ?? 'No message'}');
        return null;
      }

      if ((data['routes'] as List).isEmpty) {
        print('DEBUG Error: Routes array is empty');
        return null;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];

      final distanceKm = leg['distance']['value'] / 1000.0;
      final durationMin = leg['duration']['value'] / 60.0;
      
      // 2. Verify overview_polyline exists
      if (route['overview_polyline'] == null || route['overview_polyline']['points'] == null) {
        print('DEBUG Error: overview_polyline.points is MISSING in response');
        return null;
      }

      final encodedPolyline = route['overview_polyline']['points'];
      print('DEBUG: Encoded Polyline String: $encodedPolyline');

      // 4. Decode polyline correctly
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
      
      print('DEBUG: Total decoded polyline points count: ${result.length}');

      if (result.isEmpty) {
        print('DEBUG Warning: Decoded points list is EMPTY');
        return null;
      }

      // 5. Convert ALL decoded points into List<LatLng>
      List<LatLng> points = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
      print('DEBUG: polylineCoordinates.length: ${points.length}');
      
      if (points.length <= 2) {
        print('DEBUG Warning: Only ${points.length} points found. This will look like a straight line!');
      }

      return DirectionsResult(
        polylinePoints: points,
        distanceKm: distanceKm,
        durationMin: durationMin,
        overviewPolyline: encodedPolyline,
      );
    } catch (e) {
      print('DEBUG Exception in DirectionsService: $e');
      return null;
    }
  }
}
