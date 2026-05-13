import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:golorry_customer_app/services/directions_service.dart';
import 'package:golorry_customer_app/services/firebase_tracking_constants.dart';
import 'package:geolocator/geolocator.dart';

enum TrackingStatus { idle, searching, onTheWay, arrived, completed, cancelled }

class TrackingProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _trackingSubscription;

  // State Variables
  LatLng? _driverLocation;
  double _driverHeading = 0;
  Set<Polyline> _polylines = {};
  String _eta = '--';
  String _distanceRemaining = '-- km';
  TrackingStatus _status = TrackingStatus.idle;
  
  // Throttle API calls
  DateTime? _lastFetchTime;
  LatLng? _lastFetchLocation;

  // Getters
  LatLng? get driverLocation => _driverLocation;
  double get driverHeading => _driverHeading;
  Set<Polyline> get polylines => _polylines;
  String get eta => _eta;
  String get distanceRemaining => _distanceRemaining;
  TrackingStatus get status => _status;

  void startTracking(String bookingId, String apiKey, LatLng destination) {
    _status = TrackingStatus.onTheWay;
    print('DEBUG Provider: Listening to booking $bookingId');
    notifyListeners();

    _trackingSubscription = _dbRef
        .child(FirebaseTrackingConstants.trackingRoot)
        .child(bookingId)
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _driverLocation = LatLng(
          (data[FirebaseTrackingConstants.lat] as num).toDouble(),
          (data[FirebaseTrackingConstants.lng] as num).toDouble(),
        );
        _driverHeading = (data[FirebaseTrackingConstants.heading] as num?)?.toDouble() ?? 0.0;
        
        print('DEBUG Provider: New Driver Location: $_driverLocation');

        // Update ETA/Route if needed
        _updateRouteAndEta(apiKey, destination);
        
        notifyListeners();
      } else {
        print('DEBUG Provider Warning: No data at tracking node $bookingId');
      }
    });
  }

  Future<void> _updateRouteAndEta(String apiKey, LatLng destination) async {
    if (_driverLocation == null) {
      print('DEBUG [TrackingProvider]: Driver location is NULL, skipping route update.');
      return;
    }

    final now = DateTime.now();
    bool shouldFetch = _polylines.isEmpty;
    
    if (!shouldFetch && _lastFetchTime != null && _lastFetchLocation != null) {
      final double timeDiffSec = now.difference(_lastFetchTime!).inSeconds.toDouble();
      final double distDiffMeters = Geolocator.distanceBetween(
        _driverLocation!.latitude, _driverLocation!.longitude,
        _lastFetchLocation!.latitude, _lastFetchLocation!.longitude,
      );
      
      print('DEBUG [TrackingProvider]: Time since last fetch: ${timeDiffSec}s, Distance: ${distDiffMeters.toStringAsFixed(1)}m');

      // Throttle: 30s AND 200m
      if (timeDiffSec > 30 && distDiffMeters > 200) {
        shouldFetch = true;
      }
    } else {
      shouldFetch = true;
    }

    if (shouldFetch) {
      print('DEBUG [TrackingProvider]: Fetching road-following directions from $_driverLocation to $destination');
      final directions = await DirectionsService(apiKey).getDirections(
        origin: _driverLocation!,
        destination: destination,
      );

      if (directions != null && directions.polylinePoints.isNotEmpty) {
        print('DEBUG [TrackingProvider]: Received ${directions.polylinePoints.length} points from Directions API');
        
        _lastFetchTime = now;
        _lastFetchLocation = _driverLocation;
        _eta = '${directions.durationMin.toStringAsFixed(0)} min';
        _distanceRemaining = '${directions.distanceKm.toStringAsFixed(1)} km';
        
        // Ensure we are using the decoded points
        final List<LatLng> decodedPoints = List<LatLng>.from(directions.polylinePoints);
        
        _polylines = {
          Polyline(
            polylineId: const PolylineId('real_road_route'),
            points: decodedPoints,
            color: const Color(0xFF00915E),
            width: 8, // Slightly thicker for better visibility
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
          ),
        };
        
        print('DEBUG [TrackingProvider]: Polylines set updated. notifyListeners() called.');
        notifyListeners();
      } else {
        print('DEBUG [TrackingProvider] Error: Directions fetch failed or returned empty points.');
        // DO NOT add a straight line fallback here to keep the UI clean as per user request.
      }
    }
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    super.dispose();
  }
}
