import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:golorry_customer_app/utils/map_constants.dart';

class TestRouteScreen extends StatefulWidget {
  const TestRouteScreen({super.key});

  @override
  State<TestRouteScreen> createState() => _TestRouteScreenState();
}

class _TestRouteScreenState extends State<TestRouteScreen> {
  // ── HARDCODED DATA ──────────────────────────────────────────
  final String _apiKey = MapConstants.googleMapsApiKey;
  
  // Mysore Coordinates provided by USER
  final LatLng _origin = const LatLng(12.2958, 76.6394);
  final LatLng _destination = const LatLng(12.3106, 76.6552);

  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  bool _isLoading = false;

  Future<void> _fetchAndDrawRoute() async {
    setState(() => _isLoading = true);
    print('DEBUG [TestRoute]: Starting API Request...');

    final String url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_origin.latitude},${_origin.longitude}'
        '&destination=${_destination.latitude},${_destination.longitude}'
        '&mode=driving&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      print('DEBUG [TestRoute]: Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG [TestRoute]: API Status: ${data['status']}');

        if (data['status'] == 'OK') {
          final String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          print('DEBUG [TestRoute]: Encoded Polyline received.');

          // Decode Polyline
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
          
          print('DEBUG [TestRoute]: Total Decoded Points: ${decodedPoints.length}');
          
          // Print first 10 points
          for (int i = 0; i < (decodedPoints.length > 10 ? 10 : decodedPoints.length); i++) {
            print('  - Point $i: ${decodedPoints[i].latitude}, ${decodedPoints[i].longitude}');
          }

          final List<LatLng> polylineCoordinates = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('test_road_route'),
                points: polylineCoordinates,
                color: Colors.blueAccent,
                width: 8,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            );
          });

          // Fit Camera to Bounds
          _fitBounds(polylineCoordinates);
        } else {
          print('DEBUG [TestRoute] API ERROR: ${data['error_message'] ?? 'Check API Console'}');
        }
      }
    } catch (e) {
      print('DEBUG [TestRoute] CRITICAL ERROR: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Directions Isolation Test', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _origin, zoom: 14),
            onMapCreated: (controller) => _mapController = controller,
            polylines: _polylines,
            markers: {
              Marker(markerId: const MarkerId('origin'), position: _origin, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan)),
              Marker(markerId: const MarkerId('dest'), position: _destination),
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fetchAndDrawRoute,
        label: const Text('TEST ROUTE', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.directions),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
