import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:golorry_customer_app/services/geocoding_service.dart';
import 'package:golorry_customer_app/services/booking_service.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:golorry_customer_app/screens/more_details_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:golorry_customer_app/utils/marker_helper.dart';
import 'package:golorry_customer_app/screens/map_screen.dart';
import 'package:golorry_customer_app/utils/map_constants.dart';
import 'package:golorry_customer_app/services/directions_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:golorry_customer_app/screens/dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _userName = 'Customer';
  String _cityName = 'Locating...';
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── MAP & LOCATION STATE ──────────────────────
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  String? _currentAddress;
  bool _loadingLocation = true;
  bool _isLocatingOnMap = false;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  LatLng? _trackingPickup;
  LatLng? _trackingDrop;
  String? _lastBookingId;
  BitmapDescriptor _laariIcon = BitmapDescriptor.defaultMarker;
  LatLng? _lastDriverLatLng;
  String? _lastStatus;
  DateTime? _lastPolylineUpdate;

  // ── BOOKING WORKFLOW STATE ────────────────────
  bool _isSearching = false;
  MapType _currentMapType = MapType.normal;
  String? _pickupAddress;
  String? _dropAddress;
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  List<Map<String, dynamic>> _predictions = [];
  String? _activeField;
  bool _pickupFocused = false;
  bool _dropFocused = false;
  int? _totalDistanceMeters;
  
  // ── OPTIMIZATION: CACHED STREAMS ────────────────
  late Stream<BookingModel?> _activeBookingStream;
  StreamSubscription? _driversAroundSub;
  Set<Marker> _driverMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _determinePosition(); 
    _setCustomMarker();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    
    _activeBookingStream = BookingService().getActiveBooking().handleError((e) {
      debugPrint('Booking stream error: $e');
    });

    _subscribeToDriversAround();
  }

  void _subscribeToDriversAround() {
    _driversAroundSub?.cancel();
    _driversAroundSub = BookingService().getDriversAroundStream().listen((drivers) {
      final Set<Marker> newMarkers = {};
      for (var driver in drivers) {
        final GeoPoint? location = driver['currentLocation'] as GeoPoint?;
        final double heading = (driver['heading'] as num?)?.toDouble() ?? 0.0;
        if (location != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('driver_${driver['id']}'),
              position: LatLng(location.latitude, location.longitude),
              rotation: heading,
              icon: _laariIcon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: driver['name'] ?? "Lorry"),
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _driverMarkers = newMarkers;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _driversAroundSub?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    print('DEBUG [Location]: Starting determinePosition...');
    setState(() => _loadingLocation = true);

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('DEBUG [Location]: Location services are disabled.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled. Please enable them.'))
          );
          setState(() => _loadingLocation = false);
        }
        return;
      }

      // 2. Check Permission using permission_handler for more robustness
      var status = await Permission.location.status;
      print('DEBUG [Location]: Initial permission status: $status');

      if (status.isDenied) {
        print('DEBUG [Location]: Requesting permission...');
        status = await Permission.location.request();
      }

      if (status.isPermanentlyDenied) {
        print('DEBUG [Location]: Permission permanently denied. Opening settings...');
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Location Permission'),
              content: const Text('Location permission is required for booking. Please enable it in settings.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(onPressed: () {
                  openAppSettings();
                  Navigator.pop(ctx);
                }, child: const Text('Open Settings')),
              ],
            ),
          );
        }
        setState(() => _loadingLocation = false);
        return;
      }

      if (!status.isGranted) {
        print('DEBUG [Location]: Permission not granted.');
        setState(() => _loadingLocation = false);
        return;
      }

      // 3. Get Current Position with Timeout
      print('DEBUG [Location]: Fetching current position (High Accuracy)...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        print('DEBUG [Location]: GPS Fetch timed out. Using last known or fallback.');
        throw TimeoutException('GPS timeout');
      });

      print('DEBUG [Location]: Position received: ${position.latitude}, ${position.longitude}');

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _loadingLocation = false;
        });
        
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 15),
        );

        // Fetch address in background
        print('DEBUG [Location]: Fetching address for coordinates...');
        GeocodingService(MapConstants.googleMapsApiKey)
            .getAddressFromCoordinates(position.latitude, position.longitude)
            .then((address) {
          if (mounted && address != null) {
            print('DEBUG [Location]: Address found: $address');
            setState(() {
              _currentAddress = address;
              _pickupController.text = address;
            });
          }
        });
      }
    } catch (e) {
      print('DEBUG [Location] ERROR: $e');
      if (mounted) {
        setState(() => _loadingLocation = false);
        // If it's a timeout, use Bangalore as a safe fallback for UI initialization
        if (e is TimeoutException && _currentPosition == null) {
           _currentPosition = const LatLng(12.9716, 77.5946);
        }
      }
    }
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
          _laariIcon = BitmapDescriptor.bytes(data.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint("Error generating custom marker: $e");
    }
  }


  void _onSuggestionSelected(String description) async {
    if (_activeField == 'pickup') {
      _pickupController.text = description;
      _pickupAddress = description;
      _pickupFocused = false;
    } else if (_activeField == 'drop') {
      _dropController.text = description;
      _dropAddress = description;
      _dropFocused = false;
    }
    setState(() {
      _predictions.clear();
      _markers.clear();
      _polylines.clear();
    });
    
    // Use the unified DirectionsService instead of local _drawRoute
    _updateMapRoute(); 
  }

  void _proceed() async {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) return;

    print('DEBUG [Booking]: Starting booking flow for $pickup to $drop');
    setState(() => _isSearching = false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calculating route and fare...'), duration: Duration(seconds: 3))
    );

    try {
      final geo = GeocodingService(MapConstants.googleMapsApiKey);
      print('DEBUG [Booking]: Resolving coordinates (Max 4s)...');
      
      LatLng? pLatLng;
      LatLng? dLatLng;
      
      try {
        pLatLng = await geo.getCoordinates(pickup).timeout(const Duration(seconds: 4));
        dLatLng = await geo.getCoordinates(drop).timeout(const Duration(seconds: 4));
      } catch (e) {
        print('DEBUG [Booking]: Geocoding delay/error: $e. Using fallbacks.');
      }

      pLatLng ??= _currentPosition ?? const LatLng(12.9716, 77.5946);
      dLatLng ??= const LatLng(13.0827, 80.2707);

      print('DEBUG [Booking]: Fetching directions (Max 6s)...');
      final directions = await DirectionsService().getDirections(
        origin: pLatLng,
        destination: dLatLng,
      ).timeout(const Duration(seconds: 6), onTimeout: () {
        print('DEBUG [Booking]: Directions API timed out.');
        return null;
      });

      // ALWAYS close the dialog before moving to next step
      if (mounted) {
        print('DEBUG [Booking]: Closing loading dialog.');
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Prepare data for next screen
      String dist = directions?.distance ?? 'Calculating...';
      String dur = directions?.duration ?? 'Calculating...';
      int distMeters = directions?.distanceValue ?? 10000;
      
      double calculatedFare = 500 + ((distMeters / 1000.0) * 15);
      if (calculatedFare < 500) calculatedFare = 500;

      print('DEBUG [Booking]: Navigating to MoreDetailsScreen...');
      if (mounted) {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => MoreDetailsScreen(
              pickupAddress: pickup,
              dropAddress: drop,
              vehicleName: 'Lorry',
              tier: 'Regular',
              totalFare: calculatedFare,
              distance: dist,
              duration: dur,
              totalDistanceMeters: distMeters,
            ),
          ),
        );
      }
    } catch (e) {
      print('DEBUG [Booking] CRITICAL ERROR: $e');
      if (mounted) {
        // Safe pop to ensure dialog is gone
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e. Using estimate instead.'), backgroundColor: Colors.orange)
        );
        
        // Even on error, we try to move forward to avoid "stuck" UI
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => MoreDetailsScreen(
              pickupAddress: pickup,
              dropAddress: drop,
              vehicleName: 'Lorry',
              tier: 'Regular',
              totalFare: 500.0,
              distance: 'Unknown',
              duration: 'Unknown',
              totalDistanceMeters: 5000,
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateMapRoute() async {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) return;

    final geo = GeocodingService(MapConstants.googleMapsApiKey);
    final pLatLng = await geo.getCoordinates(pickup);
    final dLatLng = await geo.getCoordinates(drop);

    if (pLatLng == null || dLatLng == null) return;

    final result = await DirectionsService().getDirections(
      origin: pLatLng,
      destination: dLatLng,
    );

    if (result != null && mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            color: AppColors.primary,
            width: 6,
            points: result.polylinePoints,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };

        _markers = {
          Marker(
            markerId: const MarkerId('pickup'),
            position: pLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          ),
          Marker(
            markerId: const MarkerId('drop'),
            position: dLatLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        };
      });

      // Fit bounds
      final bounds = LatLngBounds(
        southwest: LatLng(
          pLatLng.latitude < dLatLng.latitude ? pLatLng.latitude : dLatLng.latitude,
          pLatLng.longitude < dLatLng.longitude ? pLatLng.longitude : dLatLng.longitude,
        ),
        northeast: LatLng(
          pLatLng.latitude > dLatLng.latitude ? pLatLng.latitude : dLatLng.latitude,
          pLatLng.longitude > dLatLng.longitude ? pLatLng.longitude : dLatLng.longitude,
        ),
      );
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _fetchUserProfile().timeout(const Duration(seconds: 4)),
        _fetchCity().timeout(const Duration(seconds: 4))
      ]);
    } catch (e) {
      debugPrint('Load data warning: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward();
      }
    }
  }

  Future<void> _fetchUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (doc.exists && data != null && data.containsKey('name')) {
        if (mounted) setState(() => _userName = data['name'] ?? 'User');
      }
    } catch (_) {}
  }

  Future<void> _fetchCity() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 5));
      final city = await GeocodingService(MapConstants.googleMapsApiKey).getCityFromCoordinates(pos.latitude, pos.longitude);
      if (mounted) setState(() => _cityName = city);
    } catch (_) {
      if (mounted) setState(() => _cityName = 'India');
    }
  }

  void _goToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 16,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Locate error: $e");
    }
  }

  void _confirmMapLocation() async {
    // Get the center of the map
    final center = await _mapController?.getVisibleRegion();
    if (center != null) {
      final lat = (center.northeast.latitude + center.southwest.latitude) / 2;
      final lng = (center.northeast.longitude + center.southwest.longitude) / 2;
      
      final address = await GeocodingService(MapConstants.googleMapsApiKey).getCityFromCoordinates(lat, lng);
      
      setState(() {
        if (_pickupController.text.isEmpty) {
          _pickupController.text = address;
        } else {
          _dropController.text = address;
        }
        _isLocatingOnMap = false;
        _isSearching = true;
      });
      _updateMapRoute(); // Use the unified route update logic
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      body: StreamBuilder<BookingModel?>(
        stream: _activeBookingStream,
        builder: (context, snapshot) {
          final activeBooking = snapshot.data;

          if (activeBooking != null) {
            // If we have an active booking, reset search state to prevent glitches
            if (_isSearching) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isSearching = false);
              });
            }
            return _buildActiveTrackingState(activeBooking);
          }

          return Stack(
            children: [
              // ── BACKGROUND MAP ───────────────────────────
              Positioned.fill(
                child: MapScreen(
                  initialPosition: _currentPosition,
                  markers: _markers.union(_driverMarkers),
                  polylines: _polylines,
                  onMapCreated: (c) => _mapController = c,
                ),
              ),

              // ── CENTER PIN (Only when locating) ───────────
              if (_isLocatingOnMap)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35),
                    child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 45),
                  ),
                ),

              // ── TOP HEADER (Gradient Overlay) ─────────────
              if (!_isSearching && !_isLocatingOnMap)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(),
                ),

              // ── MAP ACTION BUTTONS (BOTTOM RIGHT) ─────────
              if (!_isSearching && !_isLocatingOnMap)
                Positioned(
                  bottom: 180,
                  right: 20,
                  child: Column(
                    children: [
                      _mapActionBtn(
                        icon: _currentMapType == MapType.normal
                            ? Icons.layers_rounded
                            : Icons.map_rounded,
                        onTap: () {
                          setState(() {
                            _currentMapType = _currentMapType == MapType.normal
                                ? MapType.satellite
                                : MapType.normal;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _mapActionBtn(
                        icon: Icons.my_location_rounded,
                        onTap: _goToCurrentLocation,
                      ),
                      const SizedBox(height: 12),
                      _mapActionBtn(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          _loadData();
                          _determinePosition();
                        },
                      ),
                    ],
                  ),
                ),

              // ── MENU BUTTON ─────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: Builder(
                  builder: (context) => GestureDetector(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2028) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 24),
                    ),
                  ),
                ),
              ),

              // ── FLOATING LOCATION PILL ──────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                bottom: (_isSearching && !_isLocatingOnMap) ? 0 : (_isLocatingOnMap ? -800 : 100),
                left: 0,
                right: 0,
                top: (_isSearching && !_isLocatingOnMap) ? 0 : null,
                child: _buildSearchUI(),
              ),

              // ── MAP SELECTION UI (BOTTOM) ──────────────────
              if (_isLocatingOnMap)
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Move map to adjust pin', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _confirmMapLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirm Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateTrackingRoute(BookingModel booking) async {
    final geo = GeocodingService(MapConstants.googleMapsApiKey);
    final pCoord = await geo.getCoordinates(booking.pickupAddress);
    final dCoord = await geo.getCoordinates(booking.dropAddress);

    if (pCoord == null || dCoord == null) return;

    final result = await DirectionsService().getDirections(
      origin: pCoord,
      destination: dCoord,
    );

    if (result != null && mounted) {
      setState(() {
        _trackingPickup = pCoord;
        _trackingDrop = dCoord;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('tracking_route'),
            color: const Color(0xFF185A9D),
            width: 6,
            points: result.polylinePoints,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });
    }
  }

  Widget _buildActiveTrackingState(BookingModel booking) {
    if (_lastBookingId != booking.id || 
        _lastStatus != booking.status || 
        (_lastPolylineUpdate == null || DateTime.now().difference(_lastPolylineUpdate!).inSeconds > 60)) {
       _updateTrackingRoute(booking);
       _lastBookingId = booking.id;
       _lastStatus = booking.status;
       _lastPolylineUpdate = DateTime.now();
    }
    
    // Auto-follow driver
    if (booking.driverLocation != null) {
      final currentDriverPos = LatLng(booking.driverLocation!.latitude, booking.driverLocation!.longitude);
      if (_lastDriverLatLng == null || 
          _lastDriverLatLng!.latitude != currentDriverPos.latitude || 
          _lastDriverLatLng!.longitude != currentDriverPos.longitude) {
        
        _lastDriverLatLng = currentDriverPos;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(currentDriverPos));
        });
      }
    }
    
    final isDark = AppColors.isDark;
    
    return Stack(
      children: [
        Positioned.fill(
          child: MapScreen(
            initialPosition: _trackingPickup,
            markers: {
              if (_trackingPickup != null)
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: _trackingPickup!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                  infoWindow: InfoWindow(title: 'Pickup Point', snippet: booking.pickupAddress),
                ),
              if (_trackingDrop != null)
                Marker(
                  markerId: const MarkerId('drop'),
                  position: _trackingDrop!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  infoWindow: InfoWindow(title: 'Destination', snippet: booking.dropAddress),
                ),
              if (booking.driverLocation != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: LatLng(booking.driverLocation!.latitude, booking.driverLocation!.longitude),
                  rotation: booking.driverHeading ?? 0.0,
                  icon: _laariIcon,
                  anchor: const Offset(0.5, 0.5),
                  infoWindow: const InfoWindow(title: 'Lorry Location'),
                  zIndex: 2,
                ),
            },
            polylines: _polylines,
            onMapCreated: (c) {
              _mapController = c;
              if (_trackingPickup != null && _trackingDrop != null) {
                LatLngBounds bounds;
                if (_trackingPickup!.latitude > _trackingDrop!.latitude) {
                  bounds = LatLngBounds(southwest: _trackingDrop!, northeast: _trackingPickup!);
                } else {
                  bounds = LatLngBounds(southwest: _trackingPickup!, northeast: _trackingDrop!);
                }
                c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
              }
            },
          ),
        ),

        // Map Type Toggle
        Positioned(
          top: 60,
          right: 20,
          child: Column(
            children: [
              _mapActionBtn(
                icon: _currentMapType == MapType.normal ? Icons.layers_rounded : Icons.map_rounded,
                onTap: () {
                  setState(() {
                    _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal;
                  });
                },
              ),
              const SizedBox(height: 12),
              _mapActionBtn(
                icon: Icons.my_location_rounded,
                onTap: () {
                   if (booking.driverLocation != null) {
                     _mapController?.animateCamera(CameraUpdate.newLatLng(
                       LatLng(booking.driverLocation!.latitude, booking.driverLocation!.longitude)
                     ));
                   }
                },
              ),
              const SizedBox(height: 12),
              _mapActionBtn(
                icon: Icons.refresh_rounded,
                onTap: () {
                  _updateTrackingRoute(booking);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing live tracking...'), duration: Duration(seconds: 1))
                  );
                },
              ),
            ],
          ),
        ),

        Positioned(
          left: 16,
          right: 16,
          bottom: 100, 
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Driver Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00D4AA), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin_circle_rounded, size: 12, color: Color(0xFF00D4AA)),
                          const SizedBox(width: 4),
                          Text(
                            booking.status == 'accepted' 
                              ? (booking.eta != null ? 'Arriving in ${booking.eta}' : 'Driver is coming')
                              : (booking.status == 'in_transit' ? 'Heading to destination' : 'Driver Connected'),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF00D4AA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.call, color: Colors.green, size: 20),
                          onPressed: () async {
                            final Uri url = Uri.parse('tel:+919876543210');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          booking.distanceRemaining != null 
                            ? '${booking.distanceRemaining} away'
                            : 'ID: ${booking.id.substring(0, 8)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  booking.route,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.status == 'accepted' ? 'Driver is heading to pickup' : 'Driver is heading to destination',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Journey Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trip Progress', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        Text(
                          booking.status == 'accepted' ? 'To Pickup' : 'To Destination',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: () {
                          if (booking.totalDistanceMeters == null || booking.distanceRemainingMeters == null) {
                            return booking.status == 'in_transit' ? 0.5 : 0.2;
                          }
                          double progress = 1.0 - (booking.distanceRemainingMeters! / booking.totalDistanceMeters!);
                          return progress.clamp(0.0, 1.0);
                        }(),
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => BookingService().completeBooking(booking.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00915E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20),
                        const SizedBox(width: 10),
                        Text('Journey Completed', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapActionBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }

  Timer? _debounce;

  void _fetchSuggestions(String input, bool isPickup) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (input.length < 3) {
        if (mounted) setState(() => _predictions = []);
        return;
      }
      print('DEBUG [Search]: Fetching suggestions for: $input');
      final geo = GeocodingService(MapConstants.googleMapsApiKey);
      final results = await geo.getAutocomplete(input);
      if (mounted) {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(results);
          _activeField = isPickup ? 'pickup' : 'drop';
        });
      }
    });
  }

  Widget _buildSearchUI() {
    if (!_isSearching) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () {
            debugPrint('Opening Search UI...');
            setState(() {
              _isSearching = true;
              _isLocatingOnMap = false;
              // Clear previous search state when starting new one
              _markers.clear();
              _polylines.clear();
              _pickupController.clear();
              _dropController.clear();
              _pickupAddress = '';
              _dropAddress = '';
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Enter destination',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // ── TOP BAR (Back + Title + User)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => setState(() => _isSearching = false),
                  ),
                  Expanded(
                    child: Text(
                      'Destination',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance back button
                ],
              ),
            ),

            // ── MAIN SEARCH CONTENT (SCROLLABLE)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ── INPUT FIELDS
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _inputRow(
                              controller: _pickupController,
                              hint: 'Pickup Location',
                              icon: Icons.my_location_rounded,
                              iconColor: AppColors.primary,
                              suffixIcon: IconButton(
                                icon: Icon(Icons.gps_fixed_rounded, size: 18, color: AppColors.primary),
                                onPressed: _determinePosition,
                              ),
                              onChanged: (v) => _fetchSuggestions(v, true),
                              onFocusChange: (f) => setState(() => _pickupFocused = f),
                            ),
                            Divider(height: 1, indent: 48, color: AppColors.border),
                            _inputRow(
                              controller: _dropController,
                              hint: 'Enter destination',
                              icon: Icons.location_on_rounded,
                              iconColor: AppColors.error,
                              onChanged: (v) => _fetchSuggestions(v, false),
                              onFocusChange: (f) => setState(() => _dropFocused = f),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── SUGGESTIONS LIST
                    if (_isSearching && _predictions.isEmpty && (_pickupController.text.length > 2 || _dropController.text.length > 2))
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),

                    if (_predictions.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1),
                        itemBuilder: (context, index) {
                          final p = _predictions[index];
                          return ListTile(
                            leading: Icon(Icons.location_on_outlined, size: 20, color: AppColors.textMuted),
                            title: Text(p['description'], style: GoogleFonts.inter(fontSize: 14)),
                            onTap: () => _onSuggestionSelected(p['description']),
                          );
                        },
                      )
                    else if (_predictions.isEmpty)
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          _suggestionItem('Mysore Railway Station', 'Pedestrian Overpass, Medar Block...'),
                          _suggestionItem('1 New Kantharaj Urs Rd', 'CFTRI Layout Sharad...'),
                        ],
                      ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── BOTTOM BUTTONS (FIXED AT BOTTOM)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _isSearching = false;
                      _isLocatingOnMap = true;
                    }),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: Text('Locate on map', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_pickupController.text.isNotEmpty && _dropController.text.isNotEmpty) ? _proceed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Proceed', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputRow({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required Function(String) onChanged,
    required Function(bool) onFocusChange,
    Widget? suffixIcon,
  }) {
    return Focus(
      onFocusChange: onFocusChange,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _suggestionItem(String title, String subtitle) {
    return ListTile(
      leading: const Icon(Icons.history_rounded, size: 20),
      title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
      onTap: () {
        if (_activeField == 'pickup') {
          _pickupController.text = title;
        } else {
          _dropController.text = title;
        }
        setState(() => _predictions.clear());
        _updateMapRoute();
      },
    );
  }


  // ─────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Stack(
      children: [
        // Gradient background with curved bottom
        ClipPath(
          clipper: _HeaderClipper(),
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF26C6B0), const Color(0xFF2DD4BF)],
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location pill
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: Color(0xFF00D4AA)),
                          const SizedBox(width: 4),
                          Text(
                            _cityName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00D4AA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_greeting, ${_firstName(_userName)} 👋',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Book trucks for your transport needs',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: Colors.white, size: 26),
                        onPressed: () {},
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFFF43F5E),
                              shape: BoxShape.circle),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = AppColors.isDark;
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF11131A) : Colors.white,
      width: MediaQuery.of(context).size.width * 0.75,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 24, bottom: 24, right: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF26C6B0), const Color(0xFF2DD4BF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  child: const CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.person, color: AppColors.primary, size: 35)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome!', style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8))),
                      Text(_userName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _drawerTile(Icons.home_rounded, 'Home', () => Navigator.pop(context)),
                _drawerTile(Icons.person_rounded, 'Profile', () {
                  Navigator.pop(context);
                  DashboardScreen.tabNotifier.value = 2; // Profile index
                }),
                _drawerTile(Icons.notifications_rounded, 'Notifications', () => _showDrawerContent(context, 'Notifications', 'Stay updated with real-time transit alerts, driver assignments, and exclusive logistics offers.')),
                const Divider(indent: 20, endIndent: 20, height: 32),
                _drawerTile(Icons.headset_mic_rounded, 'Support', () => _showDrawerContent(context, 'Support', 'Contact our 24/7 dedicated logistics support team for assistance with your current or past shipments.')),
                _drawerTile(Icons.help_center_rounded, 'FAQ', () => _showDrawerContent(context, 'FAQ', 'Find quick answers to common questions about lorry types, pricing, and our delivery network.')),
                _drawerTile(Icons.info_rounded, 'About US', () => _showDrawerContent(context, 'About US', 'GoLorry is your premium logistics partner, connecting businesses with reliable transport solutions.')),
                _drawerTile(Icons.policy_rounded, 'Policy info', () => _showDrawerContent(context, 'Policies', 'Review our terms of service, privacy policy, and logistics safety guidelines.')),
                _drawerTile(Icons.share_rounded, 'Invite Friends', () => _showDrawerContent(context, 'Refer & Earn', 'Invite your friends to GoLorry and get 10% off on your next high-capacity shipment!')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text('GoLorry v1.0.0', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Premium Logistics Partner', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted.withOpacity(0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
    );
  }

  String _firstName(String name) {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'there';
  }

  void _showDrawerContent(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.isDark ? const Color(0xFF1E2028) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text(title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text(content, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('Got it', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────

// ─────────────────────────────────────────────────
// CUSTOM CLIPPER FOR CURVED HEADER BOTTOM
// ─────────────────────────────────────────────────
class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 36);
    path.quadraticBezierTo(
        size.width / 2, size.height + 12, size.width, size.height - 36);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HeaderClipper old) => false;
}
