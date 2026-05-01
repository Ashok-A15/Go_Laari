import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class OwnerMap extends StatefulWidget {
  final Function(GoogleMapController)? onMapCreated;
  final bool showDefaultLocationButton;

  const OwnerMap({
    super.key, 
    this.onMapCreated,
    this.showDefaultLocationButton = true,
  });

  @override
  State<OwnerMap> createState() => OwnerMapState();
}

class OwnerMapState extends State<OwnerMap> {
  late GoogleMapController _controller;
  bool _isControllerInitialized = false;
  BitmapDescriptor laariIcon = BitmapDescriptor.defaultMarker;
  Position? _currentPosition;
  final Set<Marker> _driverMarkers = {};
  StreamSubscription? _driversSubscription;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _setCustomMarker().then((_) => _startTrackingDrivers());
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTrackingDrivers() async {
    final ownerId = await _firestoreService.getEffectiveOwnerId();
    if (ownerId == null) return;

    _driversSubscription = _firestoreService.getDriversStream(ownerId).listen((snapshot) {
      final Set<Marker> newMarkers = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final GeoPoint? location = data['currentLocation'] as GeoPoint?;
        if (location != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(location.latitude, location.longitude),
              icon: laariIcon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: data['name'] ?? "Driver"),
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _driverMarkers.clear();
          _driverMarkers.addAll(newMarkers);
        });
      }
    });
  }

  Future<void> _setCustomMarker() async {
    try {
      final ByteData data = await rootBundle.load('assets/laari.png');
      final Uint8List bytes = data.buffer.asUint8List();

      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 120,
        targetHeight: 120,
      );

      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? resizedData =
          await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);

      final Uint8List resizedBytes = resizedData!.buffer.asUint8List();

      if (mounted) {
        setState(() {
          laariIcon = BitmapDescriptor.fromBytes(resizedBytes);
        });
      }
    } catch (e) {
      debugPrint("Error loading custom marker: $e");
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> animateToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      
      if (_isControllerInitialized) {
        _controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = Set.from(_driverMarkers);

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("current"),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(12.3077, 76.6533),
            zoom: 13,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          onMapCreated: (GoogleMapController controller) {
            _controller = controller;
            _isControllerInitialized = true;
            if (widget.onMapCreated != null) {
              widget.onMapCreated!(controller);
            }
          },
        ),
        if (widget.showDefaultLocationButton)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: "owner_map_loc_btn",
              onPressed: animateToCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF185A9D)),
            ),
          ),
      ],
    );
  }
}
