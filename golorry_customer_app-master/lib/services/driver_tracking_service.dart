import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class DriverTrackingService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription<Position>? _positionStream;

  /// Starts streaming high-frequency GPS updates to Firebase RTDB.
  /// Used by the Driver App.
  Future<void> startLocationUpdates(String bookingId) async {
    // 1. Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    // 2. Set up location settings for production (Battery vs Frequency)
    const locationSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
      pauseLocationUpdatesAutomatically: true,
      showBackgroundLocationIndicator: true,
    );

    const androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
      forceLocationManager: true,
      intervalDuration: Duration(seconds: 2),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationText: "GoLorry is tracking your location for the delivery",
        notificationTitle: "In Transit",
        enableWakeLock: true,
      ),
    );

    // 3. Listen to position stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: Geolocator.isAndroid ? androidSettings : locationSettings,
    ).listen((Position position) {
      _updateFirebase(bookingId, position);
    });
  }

  void _updateFirebase(String bookingId, Position position) {
    _dbRef.child('tracking').child(bookingId).update({
      'lat': position.latitude,
      'lng': position.longitude,
      'heading': position.heading,
      'speed': position.speed,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}
