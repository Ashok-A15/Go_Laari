import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class TrackingService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<Position>? _positionSubscription;

  /// Start live location tracking and upload to Firebase Realtime Database
  Future<void> startDriverTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // 2. Check and request permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    // 3. Get Current User ID
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 4. Start Listening to position stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updateFirebaseLocation(uid, position);
      },
      onError: (error) {
        print("GPS Stream Error: $error");
      },
    );
  }

  /// Update Latitude, Longitude, and Heading in Realtime Database
  void _updateFirebaseLocation(String uid, Position position) {
    DatabaseReference ref = _database.ref("drivers/$uid");

    ref.update({
      "lat": position.latitude,
      "lng": position.longitude,
      "heading": position.heading,
      "updatedAt": ServerValue.timestamp,
    }).catchError((e) {
      print("Firebase Update Error: $e");
    });
  }

  /// Stop tracking and cleanup
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
