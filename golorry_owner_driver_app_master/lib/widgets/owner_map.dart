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

  const OwnerMap({
    super.key, 
    this.onMapCreated,
    this.showDefaultLocationButton = true,
    this.mapType = MapType.normal,
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
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      const double size = 80.0; // Much smaller size as requested
      
      // Paint for the truck body (Red)
      final Paint bodyPaint = Paint()
        ..color = const Color(0xFFE53935) 
        ..style = PaintingStyle.fill;

      // Paint for the cabin (White)
      final Paint cabinPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // Paint for details (Windows - Dark Grey)
      final Paint detailPaint = Paint()
        ..color = const Color(0xFF37474F).withOpacity(0.8)
        ..style = PaintingStyle.fill;

      // Shadow
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      // Draw shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.25 + 2, size * 0.1 + 2, size * 0.5, size * 0.8),
          const Radius.circular(4),
        ),
        shadowPaint,
      );

      // Draw Main Body (Back of the truck - Grey)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.25, size * 0.35, size * 0.5, size * 0.55),
          const Radius.circular(2),
        ),
        bodyPaint,
      );

      // Draw Cabin (Front of the truck - White)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.25, size * 0.1, size * 0.5, size * 0.25),
          const Radius.circular(6),
        ),
        cabinPaint,
      );

      // Windshield (Dark)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.3, size * 0.12, size * 0.4, size * 0.08),
          const Radius.circular(1),
        ),
        detailPaint,
      );

      // Highlights for 3D look
      final Paint highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(size * 0.25, size * 0.1, size * 0.1, size * 0.8),
        highlightPaint,
      );

      final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (mounted && data != null) {
        setState(() {
          laariIcon = BitmapDescriptor.bytes(data.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint("Error generating custom marker: $e");
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
          mapType: widget.mapType,
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
