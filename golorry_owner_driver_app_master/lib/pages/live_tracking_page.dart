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
  LatLng? _driverLatLng;
  BitmapDescriptor laariIcon = BitmapDescriptor.defaultMarker;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  List<LatLng> _fullRoutePoints = [];

  static const _apiKey = 'AIzaSyByiIPu7kHZroCo8L6bgOVIk2t2riBdM4A';

  // ── Location stream ───────────────────────────────────────────────────
  StreamSubscription<Position>? _locationSub;
  StreamSubscription? _bookingSub;

  // ── State ─────────────────────────────────────────────────────────────
  String _tripStatus = 'accepted'; // accepted → in_transit → completed
  bool _isUpdating = false;
  int _locationUpdateCount = 0;
  String _eta = '--';
  String _distanceRemaining = '--';
  DateTime? _lastEtaUpdate;

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
      _fetchCoordinates();
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
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      const double size = 80.0;
      
      final Paint bodyPaint = Paint()
        ..color = const Color(0xFFE53935) 
        ..style = PaintingStyle.fill;

      final Paint cabinPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final Paint detailPaint = Paint()
        ..color = const Color(0xFF37474F).withOpacity(0.8)
        ..style = PaintingStyle.fill;

      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.25 + 2, size * 0.1 + 2, size * 0.5, size * 0.8),
          const Radius.circular(4),
        ),
        shadowPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.25, size * 0.35, size * 0.5, size * 0.55),
          const Radius.circular(2),
        ),
        bodyPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.25, size * 0.1, size * 0.5, size * 0.25),
          const Radius.circular(6),
        ),
        cabinPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size * 0.3, size * 0.12, size * 0.4, size * 0.08),
          const Radius.circular(1),
        ),
        detailPaint,
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

  Future<void> _fetchCoordinates() async {
    try {
      if (_pickupLatLng == null && _pickup.isNotEmpty && _pickup != 'Unknown pickup') {
        final locations = await geo.locationFromAddress(_pickup);
        if (locations.isNotEmpty) {
          _pickupLatLng = LatLng(locations.first.latitude, locations.first.longitude);
        }
      }
      if (_dropLatLng == null && _drop.isNotEmpty) {
        final locations = await geo.locationFromAddress(_drop);
        if (locations.isNotEmpty) {
          _dropLatLng = LatLng(locations.first.latitude, locations.first.longitude);
        }
      }

      if (_pickup.isNotEmpty && _drop.isNotEmpty) {
        final geoService = GeocodingService(_apiKey);
        final directions = await geoService.getDirections(_pickup, _drop);
        if (directions != null) {
          final polylinePoints = PolylinePoints();
          List<PointLatLng> result = polylinePoints.decodePolyline(directions['polyline']);
          _fullRoutePoints = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
        }
      }

      if (mounted) {
        // Trigger a fake position update to refresh markers and polylines if we have a position
        if (_driverLatLng != null) {
           _onNewPosition(Position(
             latitude: _driverLatLng!.latitude, 
             longitude: _driverLatLng!.longitude, 
             timestamp: DateTime.now(), 
             accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0
           ));
        } else {
           setState(() {}); // just in case
        }
      }
    } catch (e) {
      debugPrint('Geocoding fallback failed: $e');
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _bookingSub?.cancel();
    _mapController?.dispose();
    _pulseController.dispose();
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

    // Then stream updates every ~4 seconds
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // metres — updates when driver moves ≥5m
      ),
    ).listen(_onNewPosition);
  }

  void _onNewPosition(Position pos) {
    final latLng = LatLng(pos.latitude, pos.longitude);

    setState(() {
      _driverLatLng = latLng;
      _routePoints.add(latLng);

      // Moving driver marker (truck icon colour)
      _markers
        ..removeWhere((m) => m.markerId.value == 'driver' || m.markerId.value == 'pickup' || m.markerId.value == 'drop')
        ..add(Marker(
          markerId: const MarkerId('driver'),
          position: latLng,
          rotation: pos.heading,
          icon: laariIcon,
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

      // Polyline showing the path driven so far
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('route_driven'),
          points: List<LatLng>.from(_routePoints),
          color: const Color(0xFF43CEA2),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));

      if (_fullRoutePoints.isNotEmpty) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_full'),
          points: _fullRoutePoints,
          color: const Color(0xFF185A9D), // Same solid dark blue as Uber/Google
          width: 6, // Thick solid line
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      } else if (_pickupLatLng != null && _dropLatLng != null) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route_full'),
          points: [_pickupLatLng!, _dropLatLng!],
          color: const Color(0xFF185A9D),
          width: 6,
        ));
      }

      _locationUpdateCount++;
    });

    // Smoothly follow driver on map
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));

    // Update ETA and Distance every 1 minute or if it's the first time
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
          )
          .catchError((e) => debugPrint('Location update failed: $e'));
    }
  }

  Future<void> _updateEta(LatLng currentPos) async {
    if (_dropLatLng == null) return;
    
    final geoService = GeocodingService(_apiKey);
    final directions = await geoService.getDirectionsFromLatLng(currentPos, _dropLatLng!);
    
    if (directions != null && mounted) {
      setState(() {
        _eta = directions['duration'] ?? '--';
        _distanceRemaining = directions['distance'] ?? '--';
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
      if (newStatus != _tripStatus && mounted) {
        setState(() => _tripStatus = newStatus);
      }
    });
  }

  // ── Trip status actions ───────────────────────────────────────────────
  Future<void> _startTrip() async {
    setState(() => _isUpdating = true);
    try {
      await _firestoreService.updateTripStatus(widget.bookingId, 'in_transit');
      if (mounted) setState(() => _tripStatus = 'in_transit');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start trip: $e')));
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
    switch (_tripStatus) {
      case 'in_transit':
        return 'IN TRANSIT 🚛';
      case 'completed':
        return 'COMPLETED ✅';
      default:
        return 'GOING TO PICKUP 📍';
    }
  }

  Color get _statusColor {
    switch (_tripStatus) {
      case 'in_transit':
        return const Color(0xFF185A9D);
      case 'completed':
        return Colors.green;
      default:
        return const Color(0xFF43CEA2);
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
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverLatLng ?? const LatLng(12.3077, 76.6533),
              zoom: 16,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_driverLatLng != null) {
                controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_driverLatLng!, 16));
              }
            },
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

          // ── Recenter button ──────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 280,
            child: FloatingActionButton.small(
              heroTag: 'recenter_btn',
              backgroundColor: Colors.white,
              onPressed: () {
                if (_driverLatLng != null) {
                  _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_driverLatLng!, 16));
                }
              },
              child: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF185A9D)),
            ),
          ),

          // ── Bottom sheet: trip info + action buttons ─────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Call Customer'),
                        onPressed: () async {
                          final Uri url = Uri.parse('tel:+919876543210'); // Placeholder phone number
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                      ),
                        child: Column(
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

                  // Action button
                  if (_tripStatus == 'accepted')
                    _actionButton(
                      label: 'Start Trip 🚀',
                      color: const Color(0xFF185A9D),
                      onTap: _isUpdating ? null : _startTrip,
                    )
                  else if (_tripStatus == 'in_transit')
                    _actionButton(
                      label: 'Complete Trip ✅',
                      color: Colors.green.shade600,
                      onTap: _isUpdating ? null : _completeTrip,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('Trip Completed ✅',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 16)),
                      ),
                    ),
                ],
              ),
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
