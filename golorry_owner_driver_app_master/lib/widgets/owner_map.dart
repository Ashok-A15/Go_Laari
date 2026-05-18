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
  final MapType mapType;
  final bool trafficEnabled;

  const OwnerMap({
    super.key, 
    this.onMapCreated,
    this.showDefaultLocationButton = true,
    this.mapType = MapType.normal,
    this.trafficEnabled = false,
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
        final double heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
        if (location != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(location.latitude, location.longitude),
              rotation: heading,
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
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(120, 120)),
        'assets/lorry_3d.png',
      );
      if (mounted) {
        setState(() {
          laariIcon = icon;
        });
      }
    } catch (e) {
      debugPrint("Error loading custom 3d marker: $e");
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
          rotation: _currentPosition!.heading,
          anchor: const Offset(0.5, 0.5),
          icon: laariIcon, // Show the 3D lorry instead of the blue marker
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          mapType: widget.mapType,
          trafficEnabled: widget.trafficEnabled,
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
