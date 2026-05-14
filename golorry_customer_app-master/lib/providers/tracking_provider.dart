import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:golorry_customer_app/services/directions_service.dart';
import 'package:golorry_customer_app/services/firebase_tracking_constants.dart';
import 'package:geolocator/geolocator.dart';

class TrackingProvider extends ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _trackingSubscription;

  // State Variables
  LatLng? _driverLocation;
  double _driverHeading = 0;
  Set<Polyline> _polylines = {};
  String _eta = '--';
  String _distanceRemaining = '--';
  
  // Throttle API calls
  DateTime? _lastFetchTime;
  LatLng? _lastFetchLocation;

  // Getters
  LatLng? get driverLocation => _driverLocation;
  double get driverHeading => _driverHeading;
  Set<Polyline> get polylines => _polylines;
  String get eta => _eta;
  String get distanceRemaining => _distanceRemaining;

  void startTracking(String bookingId, LatLng destination) {
    print('DEBUG [TrackingProvider]: Starting real-road tracking for $bookingId');
    
    _trackingSubscription?.cancel();
    _trackingSubscription = _dbRef
        .child(FirebaseTrackingConstants.trackingRoot)
        .child(bookingId)
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final newLocation = LatLng(
          (data[FirebaseTrackingConstants.lat] as num).toDouble(),
          (data[FirebaseTrackingConstants.lng] as num).toDouble(),
        );
        
        _driverLocation = newLocation;
        _driverHeading = (data[FirebaseTrackingConstants.heading] as num?)?.toDouble() ?? 0.0;
        
        _updateRouteIfNecessary(destination);
        notifyListeners();
      }
    });
  }

  Future<void> _updateRouteIfNecessary(LatLng destination) async {
    if (_driverLocation == null) return;

    final now = DateTime.now();
    bool shouldFetch = _polylines.isEmpty;

    if (!shouldFetch && _lastFetchTime != null && _lastFetchLocation != null) {
      final double timeDiffSec = now.difference(_lastFetchTime!).inSeconds.toDouble();
      final double distDiffMeters = Geolocator.distanceBetween(
        _driverLocation!.latitude, _driverLocation!.longitude,
        _lastFetchLocation!.latitude, _lastFetchLocation!.longitude,
      );

      // Refresh every 30 seconds OR if driver moved > 200m
      if (timeDiffSec > 30 || distDiffMeters > 200) {
        shouldFetch = true;
      }
    } else {
      shouldFetch = true;
    }

    if (shouldFetch) {
      print('DEBUG [TrackingProvider]: Fetching fresh road-following route...');
      final result = await DirectionsService().getDirections(
        origin: _driverLocation!,
        destination: destination,
      );

      if (result != null && result.polylinePoints.isNotEmpty) {
        print('DEBUG [TrackingProvider]: Received ${result.polylinePoints.length} points from DirectionsService');
        
        _lastFetchTime = now;
        _lastFetchLocation = _driverLocation;
        _eta = result.duration;
        _distanceRemaining = result.distance;

        // Ensure we are using ONLY the decoded route points
        final List<LatLng> decodedLatLngs = List<LatLng>.from(result.polylinePoints);

        _polylines = {
          Polyline(
            polylineId: const PolylineId('road_route'), // Unified unique ID
            points: decodedLatLngs,
            color: const Color(0xFF185A9D),
            width: 7,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            geodesic: true,
          ),
        };
        print('DEBUG [TrackingProvider]: _polylines set updated with ID: road_route, Points: ${decodedLatLngs.length}');
        print('DEBUG [TrackingProvider]: notifyListeners() called.');
      } else {
        print('DEBUG [TrackingProvider] WARNING: DirectionsService returned NULL or 0 points.');
      }
    }
  }

  void stopTracking() {
    _trackingSubscription?.cancel();
    _driverLocation = null;
    _polylines.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    super.dispose();
  }
}
