import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_animarker/widgets/animarker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:golorry_customer_app/utils/map_constants.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final String? driverId;
  final Set<Marker>? markers;
  final Set<Polyline>? polylines;
  final void Function(GoogleMapController)? onMapCreated;
  final bool? isLiveTracking;
  final LatLng? driverLocation;
  final double? driverHeading;

  const MapScreen({
    super.key,
    this.initialPosition,
    this.driverId,
    this.markers,
    this.polylines,
    this.onMapCreated,
    this.isLiveTracking,
    this.driverLocation,
    this.driverHeading,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Use unified Google Maps API Key from constants
  final String googleApiKey = MapConstants.googleMapsApiKey;

  // Controllers
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // State variables
  LatLng? _currentP;
  LatLng _driverP = const LatLng(28.6139, 77.2090); // Default/Initial Driver position
  double _driverHeading = 0.0;
  
  Map<MarkerId, Marker> _markers = {};
  Map<PolylineId, Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];

  // Marker IDs
  final MarkerId _driverMarkerId = const MarkerId("driver");
  final MarkerId _currentLocationMarkerId = const MarkerId("currentLocation");

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<DatabaseEvent>? _driverStreamSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialize with passed values if available
    if (widget.initialPosition != null) {
      _currentP = widget.initialPosition;
    }
    if (widget.driverLocation != null) {
      _driverP = widget.driverLocation!;
    }
    if (widget.driverHeading != null) {
      _driverHeading = widget.driverHeading!;
    }
    
    _initializeMap();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _driverStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    bool hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    // Get initial position if not provided
    if (_currentP == null) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentP = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    } else {
      _updateMarkers();
    }

    // Start Realtime Tracking
    _startLiveTracking();
    
    // Fetch initial route
    _getPolylinePoints();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  void _startLiveTracking() {
    // 1. Listen to CUSTOMER location (for blue dot)
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentP = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    });

    // 2. Listen to DRIVER location from Firebase Realtime Database
    if (widget.driverId != null) {
      _driverStreamSubscription = _database.ref("drivers/${widget.driverId}").onValue.listen((event) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          double lat = (data['lat'] as num).toDouble();
          double lng = (data['lng'] as num).toDouble();
          double heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

          setState(() {
            _driverP = LatLng(lat, lng);
            _driverHeading = heading;
            _updateMarkers();
          });
          
          _getPolylinePoints();
        }
      }, onError: (error) {
        print("Firebase Listen Error: $error");
      });
    }
  }

  void _updateMarkers() {
    // Current User Marker
    if (_currentP != null) {
      _markers[_currentLocationMarkerId] = Marker(
        markerId: _currentLocationMarkerId,
        position: _currentP!,
        infoWindow: const InfoWindow(title: "My Location"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }

    // Driver/Truck Marker
    _markers[_driverMarkerId] = Marker(
      markerId: _driverMarkerId,
      position: _driverP,
      rotation: _driverHeading, // Point marker in the direction of travel
      infoWindow: const InfoWindow(title: "Driver/Truck"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );
  }

  Future<void> _getPolylinePoints() async {
    if (_currentP == null) return;

    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleApiKey,
      request: PolylineRequest(
        origin: PointLatLng(_driverP.latitude, _driverP.longitude),
        destination: PointLatLng(_currentP!.latitude, _currentP!.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      _polylineCoordinates.clear();
      for (var point in result.points) {
        _polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
      _generatePolyLineFromPoints(_polylineCoordinates);
    }
  }

  void _generatePolyLineFromPoints(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.black,
      points: polylineCoordinates,
      width: 5,
    );
    setState(() {
      _polylines[id] = polyline;
    });
  }

  void _cameraToPosition(LatLng pos) async {
    final GoogleMapController controller = await _controller.future;
    CameraPosition newCameraPosition = CameraPosition(
      target: pos,
      zoom: 13,
    );
    controller.animateCamera(CameraUpdate.newCameraPosition(newCameraPosition));
  }

  @override
  Widget build(BuildContext context) {
    // Merge markers: start with passed markers, then overwrite with local live markers
    Map<MarkerId, Marker> mergedMarkers = {};
    if (widget.markers != null) {
      for (var marker in widget.markers!) {
        mergedMarkers[marker.markerId] = marker;
      }
    }
    
    // Live markers from Firebase/Local state take precedence
    mergedMarkers.addAll(_markers);
    
    Set<Marker> allMarkers = mergedMarkers.values.toSet();

    Set<Polyline> allPolylines = {..._polylines.values};
    if (widget.polylines != null) {
      allPolylines.addAll(widget.polylines!);
    }

    return Scaffold(
      appBar: widget.driverId != null ? AppBar(
        title: const Text(
          "Live Truck Tracking",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ) : null,
      body: _currentP == null
          ? const Center(child: CircularProgressIndicator())
          : Animarker(
              mapId: _controller.future.then<int>((value) => value.mapId),
              curve: Curves.ease,
              duration: const Duration(milliseconds: 2000),
              markers: allMarkers,
              child: GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                  if (widget.onMapCreated != null) {
                    widget.onMapCreated!(controller);
                  }
                  _cameraToPosition(_currentP!);
                },
                initialCameraPosition: CameraPosition(
                  target: _currentP!,
                  zoom: 13,
                ),
                markers: allMarkers,
                polylines: allPolylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapType: MapType.normal,
              ),
            ),
    );
  }
}
