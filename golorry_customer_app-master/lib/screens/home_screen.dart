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
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:golorry_customer_app/services/geocoding_service.dart';
import 'package:golorry_customer_app/services/booking_service.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:golorry_customer_app/screens/location_select_screen.dart';
import 'package:golorry_customer_app/screens/tracking_screen.dart';
import 'package:golorry_customer_app/screens/more_details_screen.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  static const _apiKey = 'AIzaSyByiIPu7kHZroCo8L6bgOVIk2t2riBdM4A';

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
  List<LatLng> _polylineCoordinates = [];
  BitmapDescriptor _laariIcon = BitmapDescriptor.defaultMarker;

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
  
  // ── OPTIMIZATION: CACHED STREAMS ────────────────
  late Stream<BookingModel?> _activeBookingStream;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _loadData();
    _determinePosition();
    _setCustomMarker();
    
    _activeBookingStream = BookingService().getActiveBooking().handleError((e) {
      debugPrint('Booking stream error: $e');
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _loadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        return Position(
          latitude: 12.9716,
          longitude: 77.5946,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      });
      
      GeocodingService(_apiKey)
          .getAddressFromCoordinates(position.latitude, position.longitude)
          .then((address) {
        if (mounted && address != null) {
          setState(() {
            _currentAddress = address;
            _pickupAddress ??= address;
            _pickupController.text = address;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _loadingLocation = false);
      });
      
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _loadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 15),
        );
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _loadingLocation = false);
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

  Future<void> _fetchSuggestions(String query, bool isPickup) async {
    if (query.isEmpty) {
      setState(() => _predictions.clear());
      return;
    }
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&components=country:in&key=$_apiKey',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && mounted) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(data['predictions']);
            _activeField = isPickup ? 'pickup' : 'drop';
          });
        }
      }
    } catch (e) {
      debugPrint('Places API error: $e');
    }
  }

  void _onSuggestionSelected(String description) {
    if (_activeField == 'pickup') {
      _pickupController.text = description;
      _pickupAddress = description;
      _pickupFocused = false;
    } else if (_activeField == 'drop') {
      _dropController.text = description;
      _dropAddress = description;
      _dropFocused = false;
    }
    setState(() => _predictions.clear());
    _drawRoute(); // Draw route when suggestion is picked
  }

  void _proceed() async {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final directions = await GeocodingService(_apiKey).getDirections(pickup, drop);
      
      double distanceKm = 0;
      if (directions != null) {
        distanceKm = (directions['distanceValue'] as int) / 1000.0;
      }
      double calculatedFare = 500 + (distanceKm * 15);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MoreDetailsScreen(
              pickupAddress: pickup,
              dropAddress: drop,
              vehicleName: 'Lorry',
              tier: 'Regular',
              totalFare: calculatedFare,
              distance: directions?['distance'] ?? 'Calculating...',
              duration: directions?['duration'] ?? 'Calculating...',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _drawRoute() async {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) return;

    final directions = await GeocodingService(_apiKey).getDirections(pickup, drop);
    if (directions == null) return;

    final polylinePoints = PolylinePoints();
    List<PointLatLng> result = polylinePoints.decodePolyline(directions['polyline']);
    
    List<LatLng> polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        color: const Color(0xFF3B82F6),
        width: 6,
        points: polylineCoordinates,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));

      _markers.clear();
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: polylineCoordinates.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
      _markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: polylineCoordinates.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });

    // Fit bounds
    LatLngBounds bounds;
    if (polylineCoordinates.first.latitude > polylineCoordinates.last.latitude) {
      bounds = LatLngBounds(southwest: polylineCoordinates.last, northeast: polylineCoordinates.first);
    } else {
      bounds = LatLngBounds(southwest: polylineCoordinates.first, northeast: polylineCoordinates.last);
    }
    
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
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
      if (doc.exists && doc.data()!.containsKey('name')) {
        if (mounted) setState(() => _userName = doc.data()!['name']);
      }
    } catch (_) {}
  }

  Future<void> _fetchCity() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 5));
      final city = await GeocodingService(_apiKey).getCityFromCoordinates(pos.latitude, pos.longitude);
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
      
      final address = await GeocodingService(_apiKey).getCityFromCoordinates(lat, lng);
      
      setState(() {
        if (_pickupController.text.isEmpty) {
          _pickupController.text = address;
        } else {
          _dropController.text = address;
        }
        _isLocatingOnMap = false;
        _isSearching = true;
      });
      _drawRoute(); // Draw the route after selection
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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? const LatLng(12.9716, 77.5946),
                    zoom: _currentPosition == null ? 10 : 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
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


              // ── SEARCH INTERFACE (BOTTOM) ──────────────────
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

  Future<void> _getPolyline(BookingModel booking) async {
    if (_lastBookingId == booking.id && _polylineCoordinates.isNotEmpty) return;
    
    _lastBookingId = booking.id;
    final geo = GeocodingService(_apiKey);
    
    try {
      final pCoord = await geo.getCoordinates(booking.pickupAddress);
      final dCoord = await geo.getCoordinates(booking.dropAddress);
      
      if (pCoord == null || dCoord == null) {
        // DO NOT set _lastBookingId to null here as it causes infinite rebuild loop
        // Just return, the UI will handle missing coordinates
        return;
      }

      final directions = await geo.getDirections(booking.pickupAddress, booking.dropAddress);
      
      if (mounted) {
        setState(() {
          _trackingPickup = pCoord;
          _trackingDrop = dCoord;
          
          if (directions != null) {
            final polylinePoints = PolylinePoints();
            List<PointLatLng> result = polylinePoints.decodePolyline(directions['polyline']);
            _polylineCoordinates = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
          } else {
            // Fallback to straight line if API fails
            print('Directions API failed. Showing straight line fallback.');
            _polylineCoordinates = [pCoord, dCoord];
          }
        });
      }
    } catch (e) {
      print('Tracking route error: $e');
      // DO NOT set _lastBookingId to null here as it causes infinite rebuild loop
    }
  }

  Widget _buildActiveTrackingState(BookingModel booking) {
    if (_lastBookingId != booking.id) {
       _getPolyline(booking);
    }
    
    final isDark = AppColors.isDark;
    
    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: CameraPosition(
              target: _trackingPickup ?? const LatLng(12.9716, 77.5946), 
              zoom: 12,
            ),
            myLocationEnabled: true,
            zoomControlsEnabled: false,
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
            polylines: {
              if (_polylineCoordinates.isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('tracking_route'),
                  color: const Color(0xFF185A9D), // Same solid dark blue as Driver app
                  width: 6,
                  points: _polylineCoordinates,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
            },
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
                onTap: () {},
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
                            booking.eta != null 
                              ? 'Arriving in ${booking.eta}' 
                              : 'Driver Connected',
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
                  'Driver is heading to destination',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
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
                const Icon(Icons.search, color: AppColors.primary),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16),
                        const SizedBox(width: 4),
                        Text('Myself', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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

            // ── SUGGESTIONS
            Expanded(
              child: _predictions.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1),
                      itemBuilder: (context, index) {
                        final p = _predictions[index];
                        return ListTile(
                          leading: const Icon(Icons.history_rounded, size: 20),
                          title: Text(p['description'], style: GoogleFonts.inter(fontSize: 14)),
                          onTap: () => _onSuggestionSelected(p['description']),
                        );
                      },
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 20),
                        _suggestionItem('Mysore Railway Station', 'Pedestrian Overpass, Medar Block...'),
                        _suggestionItem('1 New Kantharaj Urs Rd', 'CFTRI Layout Sharad...'),
                      ],
                    ),
            ),

            // ── BOTTOM BUTTONS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 60), // Added bottom padding to move button up
              child: Column(
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
        if (_pickupController.text.isEmpty) {
          _pickupController.text = title;
        } else {
          _dropController.text = title;
        }
        setState(() {});
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
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

  String _firstName(String name) {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'there';
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
