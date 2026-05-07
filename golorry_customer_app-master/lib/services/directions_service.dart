import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  final String apiKey;

  DirectionsService(this.apiKey);

  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url =
        '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);

    if (data['status'] != 'OK') return null;

    final route = data['routes'][0];
    final leg = route['legs'][0];

    final distanceKm = leg['distance']['value'] / 1000.0;
    final durationMin = leg['duration']['value'] / 60.0;

    final encodedPolyline = route['overview_polyline']['points'];
    final polylinePoints = _decodePolyline(encodedPolyline);

    return DirectionsResult(
      polylinePoints: polylinePoints,
      distanceKm: distanceKm,
      durationMin: durationMin,
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
