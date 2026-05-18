import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../services/firestore_service.dart';
import '../services/geocoding_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'driver_main_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:ui' as ui;
import '../utils/map_constants.dart';
import '../services/tracking_service.dart';
import 'package:flutter_animarker/widgets/animarker.dart';

class LiveTrackingPage extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const LiveTrackingPage({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage>
    with SingleTickerProviderStateMixin {
  // ── Map ──────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _completer = Completer<GoogleMapController>();
  LatLng? _driverLatLng;
  BitmapDescriptor laariIcon = BitmapDescriptor.defaultMarker;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  List<LatLng> _fullRoutePoints = [];

  static const _apiKey = MapConstants.googleMapsApiKey;

  // ── Location stream ───────────────────────────────────────────────────
  StreamSubscription<Position>? _locationSub;
  StreamSubscription? _bookingSub;

  // ── State ─────────────────────────────────────────────────────────────
  String _tripStatus = 'accepted'; // accepted → in_transit → completed
  bool _isUpdating = false;
  int _locationUpdateCount = 0;
  String _eta = '--';
  String _distanceRemaining = '--';
  int? _distanceRemainingMeters;
  DateTime? _lastEtaUpdate;
  String? _correctOtp;
  final TextEditingController _otpController = TextEditingController();

  // ── PANEL STATE ───────────────────────────────────────────────────────
  final ValueNotifier<double> _panelHeightNotifier = ValueNotifier<double>(0.3);
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // ── Animation (pulsing marker) ────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Booking data ──────────────────────────────────────────────────────
  late String _pickup;
  late String _drop;
  late String _fare;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();

    _pickup = widget.bookingData['pickupAddress'] ??
        widget.bookingData['route'] ??
        'Unknown pickup';
    _drop = widget.bookingData['dropAddress'] ?? '';
    _fare = widget.bookingData['totalFare']?.toString() ??
        widget.bookingData['price']?.toString() ??
        '0';
    _tripStatus = widget.bookingData['status'] ?? 'accepted';
    _correctOtp = widget.bookingData['otp']?.toString();

    final pLat = widget.bookingData['pickupLat'];
    final pLng = widget.bookingData['pickupLng'];
    final dLat = widget.bookingData['dropLat'];
    final dLng = widget.bookingData['dropLng'];

    if (pLat != null && pLng != null) {
      _pickupLatLng = LatLng((pLat as num).toDouble(), (pLng as num).toDouble());
    }
    if (dLat != null && dLng != null) {
      _dropLatLng = LatLng((dLat as num).toDouble(), (dLng as num).toDouble());
    }

    if (_pickupLatLng == null || _dropLatLng == null) {
      _fetchCoordinates().then((_) => _fitMapToRoute());
    } else {
      // If we already have them, fit immediately after map is created
      Future.delayed(const Duration(milliseconds: 500), () => _fitMapToRoute());
    }

    // Pulse animation for driver marker
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.8, end: 1.2).animate(_pulseController);

    _requestPermissionAndStartTracking();
    _listenToBookingUpdates();
    _setCustomMarker();
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

  Future<void> _fetchCoordinates() async {
    print('DEBUG [DriverApp]: Starting fetchCoordinates for $_pickup to $_drop');
    try {
      final geoService = GeocodingService(_apiKey);
      
      if (_pickupLatLng == null && _pickup.isNotEmpty && _pickup != 'Unknown pickup') {
        _pickupLatLng = await geoService.getCoordinates(_pickup);
        print('DEBUG [DriverApp]: Pickup Resolved: $_pickupLatLng');
      }
      
      if (_dropLatLng == null && _drop.isNotEmpty) {
        _dropLatLng = await geoService.getCoordinates(_drop);
        print('DEBUG [DriverApp]: Drop Resolved: $_dropLatLng');
      }

      LatLng? origin;
      LatLng? dest;

      final status = _tripStatus.toLowerCase();
      if (status == 'accepted' || status == 'loading_started' || status == 'loading_completed') {
        if (_driverLatLng != null && _pickupLatLng != null) {
          origin = _driverLatLng;
          dest = _pickupLatLng;
        } else if (_pickupLatLng != null) {
          origin = _pickupLatLng;
          dest = _pickupLatLng;
        }
      } else if (status == 'in_transit') {
        if (_pickupLatLng != null && _dropLatLng != null) {
          origin = _pickupLatLng;
          dest = _dropLatLng;
        }
      }

      if (origin != null && dest != null) {
        final directions = await geoService.getDirectionsFromLatLng(origin, dest);
        if (directions != null) {
          final polylinePoints = PolylinePoints();
          List<PointLatLng> result = polylinePoints.decodePolyline(directions['polyline']);
          _fullRoutePoints = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
          print('DEBUG [DriverApp]: Route Resolved with ${_fullRoutePoints.length} points for status $status');
        }
      }

      if (mounted) setState(() {}); 
    } catch (e) {
      print('DEBUG [DriverApp] Geocoding ERROR: $e');
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _bookingSub?.cancel();
    _mapController?.dispose();
    _pulseController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Permission & GPS streaming ────────────────────────────────────────
  Future<void> _requestPermissionAndStartTracking() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission permanently denied')));
      }
      return;
    }

    // Start background service for production-grade tracking
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
    service.invoke('setBookingId', {'bookingId': widget.bookingId});

    // Get first fix immediately
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _onNewPosition(pos);
    } catch (_) {}

    // Then stream updates every ~2 seconds
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2, // Very frequent updates for Uber-like smoothness
      ),
    ).listen(_onNewPosition);
  }

  void _fitMapToRoute() {
    if (_mapController == null || _pickupLatLng == null || _dropLatLng == null) {
      print('DEBUG [DriverApp]: Cannot fit bounds yet. Markers missing.');
      return;
    }
    
    print('DEBUG [DriverApp]: Fitting camera to route bounds...');
    LatLngBounds bounds;
    if (_pickupLatLng!.latitude > _dropLatLng!.latitude) {
      bounds = LatLngBounds(southwest: _dropLatLng!, northeast: _pickupLatLng!);
    } else {
      bounds = LatLngBounds(southwest: _pickupLatLng!, northeast: _dropLatLng!);
    }
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _onNewPosition(Position pos) {
    final latLng = LatLng(pos.latitude, pos.longitude);

    setState(() {
      _driverLatLng = latLng;
      _routePoints.add(latLng);

      // Moving driver marker (truck icon)
      _markers
        ..removeWhere((m) => m.markerId.value == 'driver' || m.markerId.value == 'pickup' || m.markerId.value == 'drop')
        ..add(Marker(
          markerId: const MarkerId('driver'),
          position: latLng,
          rotation: pos.heading,
          icon: laariIcon, // FIXED TYPO
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: 'Your Location'),
          zIndex: 2,
        ));

      if (_pickupLatLng != null) {
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ));
      }

      if (_dropLatLng != null) {
        _markers.add(Marker(
          markerId: const MarkerId('drop'),
          position: _dropLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Drop Location'),
        ));
      }

      // Polylines: Path driven + Road-following route to destination
      _polylines.clear();
      
      // 1. Draw the path you have already driven (gray/light line)
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_driven'),
        points: List<LatLng>.from(_routePoints),
        color: Colors.grey,
        width: 4,
      ));

      // 2. Draw the MAIN ROAD ROUTE (The blue Directions line)
      if (_fullRoutePoints.isNotEmpty) {
        print('DEBUG [DriverApp]: Rendering road-following route with ${_fullRoutePoints.length} points');
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_full'),
          points: _fullRoutePoints,
          color: const Color(0xFF185A9D), 
          width: 8, 
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ));
      }

      _locationUpdateCount++;
    });

    // Smoothly follow driver on map (only if close to truck)
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));

    // ONE-TIME Camera fit for the whole route
    if (_locationUpdateCount == 1 && _pickupLatLng != null && _dropLatLng != null) {
      LatLngBounds bounds;
      if (_pickupLatLng!.latitude > _dropLatLng!.latitude) {
        bounds = LatLngBounds(southwest: _dropLatLng!, northeast: _pickupLatLng!);
      } else {
        bounds = LatLngBounds(southwest: _pickupLatLng!, northeast: _dropLatLng!);
      }
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }

    // Update ETA and Distance every 1 minute
    if (_dropLatLng != null && (_lastEtaUpdate == null || DateTime.now().difference(_lastEtaUpdate!).inMinutes >= 1)) {
      _updateEta(latLng);
    }

    // Upload to Firestore
    if (_tripStatus != 'completed') {
      _firestoreService
          .updateBookingLocation(
            widget.bookingId, 
            pos.latitude, 
            pos.longitude, 
            pos.heading,
            eta: _eta,
            distanceRemaining: _distanceRemaining,
            distanceRemainingMeters: _distanceRemainingMeters,
          )
          .catchError((e) => debugPrint('Location update failed: $e'));
    }
  }

  Future<void> _updateEta(LatLng currentPos) async {
    LatLng? target;
    final status = _tripStatus.toLowerCase();
    if (status == 'accepted' || status == 'loading_started' || status == 'loading_completed') {
      target = _pickupLatLng;
    } else if (status == 'in_transit') {
      target = _dropLatLng;
    }
    
    if (target == null) return;
    
    final geoService = GeocodingService(_apiKey);
    final directions = await geoService.getDirectionsFromLatLng(currentPos, target);
    
    if (directions != null && mounted) {
      setState(() {
        _eta = directions['duration'] ?? '--';
        _distanceRemaining = directions['distance'] ?? '--';
        _distanceRemainingMeters = directions['distanceValue'];
        _lastEtaUpdate = DateTime.now();
      });
    }
  }

  // ── Real-time booking status listener ─────────────────────────────────
  void _listenToBookingUpdates() {
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data()!;
      final newStatus = data['status'] ?? _tripStatus;
      
      final oldStatus = _tripStatus;
      setState(() {
        _tripStatus = newStatus;
        if (data['otp'] != null) {
          _correctOtp = data['otp'].toString();
        }
        // Refresh addresses if they were missing
        if (_pickup == 'Unknown pickup' || _pickup.isEmpty) {
          _pickup = data['pickupAddress'] ?? data['route'] ?? 'Unknown pickup';
        }
        if (_drop.isEmpty) {
          _drop = data['dropAddress'] ?? '';
        }
      });

      if (newStatus != oldStatus) {
        _fetchCoordinates();
        if (_driverLatLng != null) {
          _updateEta(_driverLatLng!);
        }
      }
    });
  }

  // ── Trip status actions ───────────────────────────────────────────────
  Future<void> _startLoading() async {
    setState(() => _isUpdating = true);
    try {
      await _firestoreService.updateTripStatus(widget.bookingId, 'loading_started');
      if (mounted) setState(() => _tripStatus = 'loading_started');
      _fetchCoordinates();
      if (_driverLatLng != null) {
        _updateEta(_driverLatLng!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading Started! Status synchronized with customer. 📦'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start loading: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<bool> _verifyOtpAndStartLoading(String otpInput) async {
    final correctOtp = _correctOtp ?? widget.bookingData['otp']?.toString() ?? '1234';
    if (otpInput.trim() != correctOtp.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please verify with customer and try again! ❌'), backgroundColor: Colors.red),
      );
      return false;
    }

    setState(() => _isUpdating = true);
    try {
      await _firestoreService.updateTripStatus(widget.bookingId, 'loading_started');
      if (mounted) setState(() => _tripStatus = 'loading_started');
      _fetchCoordinates();
      if (_driverLatLng != null) {
        _updateEta(_driverLatLng!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified! Loading officially started. 📦'), backgroundColor: Colors.orange),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start loading: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _completeLoading() async {
    setState(() => _isUpdating = true);
    try {
      await _firestoreService.updateTripStatus(widget.bookingId, 'loading_completed');
      if (mounted) setState(() => _tripStatus = 'loading_completed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading Completed! Ready to start the ride. 🚚'), backgroundColor: Colors.purple),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to complete loading: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _startRide() async {
    setState(() => _isUpdating = true);
    try {
      await _firestoreService.updateTripStatus(widget.bookingId, 'in_transit');
      if (mounted) setState(() => _tripStatus = 'in_transit');
      _fetchCoordinates();
      if (_driverLatLng != null) {
        _updateEta(_driverLatLng!);
      }
      
      // Start Realtime Database GPS Tracking
      try {
         await TrackingService().startDriverTracking();
      } catch (e) {
         debugPrint("Failed to start RTDB tracking: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride officially started! Dynamic route to drop address is now active 🚀'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start ride: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _completeTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Complete Trip?'),
        content: const Text(
            'Mark this trip as completed? You will be taken back to the dashboard.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43CEA2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);
    try {
      await _firestoreService.updateTripStatus(widget.bookingId, 'completed');
      
      // Stop background tracking
      _locationSub?.cancel(); 
      FlutterBackgroundService().invoke('stopService');
      TrackingService().stopTracking(); // Stop RTDB tracking

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Trip completed! Great job 🎉'),
        backgroundColor: Color(0xFF43CEA2),
      ));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DriverMainPage()),
        (r) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to complete trip: $e')));
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String get _statusLabel {
    final status = _tripStatus.toLowerCase();
    switch (status) {
      case 'accepted':
        return 'HEADING TO PICKUP 📍';
      case 'loading_started':
        return 'LOADING STARTED 📦';
      case 'loading_completed':
        return 'LOADING COMPLETED 🚚';
      case 'in_transit':
        return 'IN TRANSIT (RIDE STARTED) 🚚';
      case 'completed':
        return 'COMPLETED ✅';
      default:
        return 'HEADING TO PICKUP 📍';
    }
  }

  Color get _statusColor {
    final status = _tripStatus.toLowerCase();
    switch (status) {
      case 'accepted':
        return const Color(0xFF185A9D);
      case 'loading_started':
        return Colors.orange;
      case 'loading_completed':
        return Colors.purple;
      case 'in_transit':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return const Color(0xFF185A9D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      body: Stack(
        children: [
          // ── Map (full screen) ────────────────────────────────────────
          ValueListenableBuilder<double>(
            valueListenable: _panelHeightNotifier,
            builder: (context, heightFactor, child) {
              return Animarker(
                mapId: _completer.future.then<int>((value) => value.mapId),
                curve: Curves.ease,
                duration: const Duration(milliseconds: 2000),
                markers: _markers,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _driverLatLng ?? const LatLng(12.3077, 76.6533),
                    zoom: 16,
                  ),
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * heightFactor),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapType: MapType.normal,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (!_completer.isCompleted) {
                      _completer.complete(controller);
                    }
                    if (_pickupLatLng != null && _dropLatLng != null) {
                      _fitMapToRoute();
                    } else if (_driverLatLng != null) {
                      controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_driverLatLng!, 16));
                    }
                  },
                ),
              );
            }
          ),

          // ── Top bar: back + status ───────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8)
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Color(0xFF185A9D)),
                  ),
                ),
                const SizedBox(width: 12),
                // Status pill
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      children: [
                        // Pulsing dot
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _statusColor,
                            ),
                          ),
                        ),
                        Text(
                          '$_locationUpdateCount GPS pts',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Map Action Buttons ──────────────────────────────────────
          ValueListenableBuilder<double>(
            valueListenable: _panelHeightNotifier,
            builder: (context, heightFactor, child) {
              return Positioned(
                right: 16,
                bottom: MediaQuery.of(context).size.height * heightFactor + 16,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'refresh_btn',
                      backgroundColor: Colors.white,
                      onPressed: () async {
                        try {
                          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                          _onNewPosition(pos);
                          _fetchCoordinates(); // Refresh route points
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location refreshed'), duration: Duration(seconds: 1))
                          );
                        } catch (e) {
                          debugPrint('Manual refresh failed: $e');
                        }
                      },
                      child: const Icon(Icons.refresh_rounded, color: Color(0xFF185A9D)),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.small(
                      heroTag: 'recenter_btn',
                      backgroundColor: Colors.white,
                      onPressed: () {
                        if (_driverLatLng != null) {
                          _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_driverLatLng!, 16));
                        }
                      },
                      child: const Icon(Icons.my_location_rounded, color: Color(0xFF185A9D)),
                    ),
                  ],
                ),
              );
            }
          ),

          // ── Bottom sheet: trip info + action buttons ─────────────────
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              _panelHeightNotifier.value = notification.extent;
              return true;
            },
            child: DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.65,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E272E) : Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                        24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Fare badge and Call button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.1),
                                foregroundColor: Colors.green,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Call Customer'),
                              onPressed: () async {
                                final Uri url = Uri.parse(
                                    'tel:+919876543210'); // Placeholder phone number
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹$_fare',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF185A9D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_eta ($_distanceRemaining)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pickup
                        _routeRow(
                          icon: Icons.radio_button_checked,
                          color: const Color(0xFF43CEA2),
                          label: 'Pickup',
                          address: _pickup,
                        ),
                        if (_drop.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 11),
                            child: Container(
                                height: 24,
                                width: 2,
                                color: Colors.grey.shade300),
                          ),
                          _routeRow(
                            icon: Icons.location_on_rounded,
                            color: Colors.redAccent,
                            label: 'Drop',
                            address: _drop,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Action button flow based on status
                        () {
                          final status = _tripStatus.toLowerCase();
                          if (status == 'accepted') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.vpn_key_rounded, color: Colors.orange, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Enter Customer OTP to Start Loading',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _otpController,
                                              keyboardType: TextInputType.number,
                                              maxLength: 4,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 8,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '0000',
                                                hintStyle: TextStyle(
                                                  fontSize: 22,
                                                  color: Colors.grey.shade400,
                                                  letterSpacing: 8,
                                                ),
                                                counterText: '',
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            height: 52,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange.shade700,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                                elevation: 0,
                                              ),
                                              onPressed: _isUpdating ? null : () async {
                                                if (_otpController.text.length < 4) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Please enter 4 digits OTP'), backgroundColor: Colors.red),
                                                  );
                                                  return;
                                                }
                                                final success = await _verifyOtpAndStartLoading(_otpController.text);
                                                if (success) {
                                                  _otpController.clear();
                                                }
                                              },
                                              child: _isUpdating
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                  )
                                                : const Text(
                                                    'Verify',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          } else if (status == 'loading_started') {
                            return _actionButton(
                              label: 'Complete Loading 🚚',
                              color: Colors.purple.shade600,
                              onTap: _isUpdating ? null : _completeLoading,
                            );
                          } else if (status == 'loading_completed') {
                            return _actionButton(
                              label: 'Start Ride 🚀',
                              color: Colors.blue.shade700,
                              onTap: _isUpdating ? null : _startRide,
                            );
                          } else if (status == 'in_transit') {
                            return _actionButton(
                              label: 'Complete Ride ✅',
                              color: Colors.green.shade600,
                              onTap: _isUpdating ? null : _completeTrip,
                            );
                          } else {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Text('Ride Completed ✅',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 16)),
                              ),
                            );
                          }
                        }(),
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(address,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _isUpdating
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
      ),
    );
  }
}
