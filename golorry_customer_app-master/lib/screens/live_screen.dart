import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../utils/app_colors.dart';
import '../services/booking_service.dart';
import '../services/geocoding_service.dart';
import '../models/booking_model.dart';
import 'location_select_screen.dart';
import 'more_details_screen.dart';
import 'trip_completed_screen.dart';

class VehicleType {
  final String name;
  final String desc;
  final String capacity;
  final IconData icon;

  VehicleType(this.name, this.desc, this.capacity, this.icon);
}

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  String? _currentAddress;
  bool _loadingLocation = true;

  final String _placesApiKey = 'AIzaSyBHKu2YcOIN7RN-_mbU-UfzzXexvXh2apA';

  // Booking Flow State
  bool _isBookingSheetOpen = false;
  String? _pickupAddress;
  String? _dropAddress;
  int? _selectedVehicleIndex;

  final List<VehicleType> _vehicles = [
    VehicleType('7ft', 'Best for delivering furniture & commercial goods', '2.2 x 1.4 x 1.8 Meter • Up to 750 kg', Icons.local_shipping_rounded),
    VehicleType('8ft', 'Best for delivering office furniture & heavy machinery', '2.5 x 1.4 x 1.8 Meter • Up to 1000 kg', Icons.fire_truck_rounded),
    VehicleType('Tata 407', 'Best for delivering heavy machinery & building material', '2.9 x 1.8 x 1.8 Meter • Up to 2500 kg', Icons.agriculture_rounded),
  ];

  StreamSubscription<BookingModel?>? _activeBookingSub;
  BookingModel? _lastActiveBooking;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _listenToActiveBooking();
  }

  void _listenToActiveBooking() {
    _activeBookingSub = BookingService().getActiveBooking().listen((booking) async {
      if (booking != null) {
        _lastActiveBooking = booking;
        if (mounted) setState(() {});
      } else {
        // active booking became null. Did it complete?
        if (_lastActiveBooking != null) {
          final completedBooking = await BookingService().getBookingById(_lastActiveBooking!.id);
          if (completedBooking != null && completedBooking.status == 'completed') {
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TripCompletedScreen(booking: completedBooking)));
            }
          }
          _lastActiveBooking = null;
          if (mounted) setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _activeBookingSub?.cancel();
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

      // Use LOW accuracy + timeout to avoid ANR on slow GPS devices
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 8), onTimeout: () {
        return Position(
          latitude: 20.5937, longitude: 78.9629,
          timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: 0,
          speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
        );
      });
      
      // Reverse geocode in background, don't block UI
      GeocodingService(_placesApiKey)
          .getAddressFromCoordinates(position.latitude, position.longitude)
          .then((address) {
        if (mounted) {
          setState(() {
            _currentAddress = address;
            _pickupAddress ??= address;
          });
        }
      }).catchError((_) {});
      
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _loadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition!, 14),
        );
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _lastActiveBooking != null
          ? _buildActiveTrackingState(_lastActiveBooking!)
          : _buildInteractiveBookingState(context),
    );
  }

  Widget _buildInteractiveBookingState(BuildContext context) {
    final isDark = AppColors.isDark;

    return Stack(
      children: [
        // 1) Background Map
        Positioned.fill(
          child: _loadingLocation 
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? const LatLng(20.5937, 78.9629),
                  zoom: _currentPosition == null ? 4.0 : 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) => _mapController = controller,
              ),
        ),

        // 2) Top Left Menu Header
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: IconButton(
                      icon: Icon(_isBookingSheetOpen ? Icons.arrow_back_rounded : Icons.menu, color: Colors.black87), 
                      onPressed: () {
                        if (_isBookingSheetOpen) {
                          setState(() => _isBookingSheetOpen = false);
                        }
                      }
                    ),
                  ),
                  Text(
                    'GoLorry',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF00915E), letterSpacing: -0.5),
                  ),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87), onPressed: () {}),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3) My Location Recenter Button
        Positioned(
          top: 80,
          right: 16,
          child: GestureDetector(
            onTap: () {
              if (_currentPosition != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                );
              } else {
                setState(() => _loadingLocation = true);
                _determinePosition();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.my_location_rounded, color: Colors.black87, size: 20),
            ),
          ),
        ),

        // 4) Bottom View Controller (Either 'Book a Lorry' card or Full Sheet)
        if (!_isBookingSheetOpen)
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentAddress ?? 'Locating your position...',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isBookingSheetOpen = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00915E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Book a Lorry', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          DraggableScrollableSheet(
            initialChildSize: 0.60,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B1E26) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5))
                  ],
                ),
                child: Stack(
                  children: [
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(top: 12, bottom: 100),
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Location Input Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LocationSelectScreen()),
                              );
                              if (result != null && result is Map) {
                                setState(() {
                                  _pickupAddress = result['pickup'];
                                  _dropAddress = result['drop'];
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF232731) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border, width: 0.5),
                                boxShadow: [
                                  if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                                ],
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.radio_button_unchecked, color: Color(0xFF00915E), size: 16),
                                    title: Text(_pickupAddress ?? 'Pick-up location', style: GoogleFonts.inter(fontSize: 14, color: _pickupAddress != null ? AppColors.textPrimary : AppColors.textMuted, fontWeight: _pickupAddress != null ? FontWeight.w600 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: Text('Now ⌄', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                                  ),
                                  Divider(color: AppColors.border, height: 1, indent: 48),
                                  ListTile(
                                    visualDensity: VisualDensity.compact,
                                    leading: Icon(Icons.location_on, color: AppColors.error, size: 18),
                                    title: Text(_dropAddress ?? 'Drop-off location', style: GoogleFonts.inter(fontSize: 14, color: _dropAddress != null ? AppColors.textPrimary : AppColors.textMuted, fontWeight: _dropAddress != null ? FontWeight.w600 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Divider(color: AppColors.border, height: 1),
                                  InkWell(
                                    onTap: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add, size: 18, color: AppColors.textMuted),
                                          const SizedBox(width: 8),
                                          Text('Add Stop', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Available vehicles', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 12),

                        // Vehicles List
                        ...List.generate(_vehicles.length, (index) {
                          final v = _vehicles[index];
                          final isSelected = _selectedVehicleIndex == index;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedVehicleIndex = index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF232731) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF00915E) : AppColors.border,
                                  width: isSelected ? 1.5 : 0.5,
                                ),
                                boxShadow: [
                                  if (isSelected) BoxShadow(color: const Color(0xFF00915E).withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7E6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(v.icon, color: const Color(0xFFF59E0B), size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(v.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        const SizedBox(height: 4),
                                        Text(v.desc, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary), maxLines: 2),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(child: Text(v.capacity, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF00915E), size: 24),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    // Bottom Sticky Panel (Proceed to Tier Selection)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B1E26) : Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_pickupAddress != null && _dropAddress != null && _selectedVehicleIndex != null)
                                  ? () => _showDeliveryTiersSheet(context)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00915E),
                                disabledBackgroundColor: const Color(0xFFE5E7EB),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.black38,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                (_pickupAddress == null || _dropAddress == null) ? 'Enter Address ⌄' : 'Next',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _showDeliveryTiersSheet(BuildContext context) {
    String selectedTier = 'Pooling'; // Default matched to screenshot
    final isDark = AppColors.isDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              padding: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1E26) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    
                    _buildTierOption(
                      'Priority', '₹2,122.00', 'Match faster for quick deliveries', 
                      selectedTier == 'Priority', () => setSheetState(() => selectedTier = 'Priority'), isDark
                    ),
                    _buildTierOption(
                      'Regular', '₹1,147.00', null, 
                      selectedTier == 'Regular', () => setSheetState(() => selectedTier = 'Regular'), isDark
                    ),
                    _buildTierOption(
                      'Pooling', '₹918.00', 'Save costs • Wait a little longer', 
                      selectedTier == 'Pooling', () => setSheetState(() => selectedTier = 'Pooling'), isDark,
                      showInfoIcon: true,
                    ),

                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext); // close sheet
                            
                            // Map dummy prices based on selection
                            double fare = 918.00;
                            if (selectedTier == 'Priority') fare = 2122.00;
                            if (selectedTier == 'Regular') fare = 1147.00;
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MoreDetailsScreen(
                                pickupAddress: _pickupAddress!,
                                dropAddress: _dropAddress!,
                                vehicleName: _vehicles[_selectedVehicleIndex!].name,
                                tier: selectedTier,
                                totalFare: fare,
                              )),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00915E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Next', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildTierOption(String title, String price, String? subtitle, bool isSelected, VoidCallback onTap, bool isDark, {bool showInfoIcon = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00915E).withValues(alpha: 0.05) : (isDark ? const Color(0xFF232731) : Colors.white),
          border: Border.all(color: isSelected ? const Color(0xFF00915E) : AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (showInfoIcon) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                      ]
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ]
                ],
              ),
            ),
            Text(price, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTrackingState(BookingModel booking) {
    final isDark = AppColors.isDark;
    
    return Stack(
      children: [
        // Real Google Map (uses the already-loaded _currentPosition)
        Positioned.fill(
          child: _currentPosition == null
              ? Container(
                  color: isDark ? const Color(0xFF1B1E26) : const Color(0xFFE5E7EB),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Locating your position...',
                          style: GoogleFonts.inter(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    if (booking.pickupLat != null && booking.pickupLng != null)
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(booking.pickupLat!, booking.pickupLng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        infoWindow: InfoWindow(title: 'Pickup: ${booking.pickupAddress}'),
                      ),
                    if (booking.dropLat != null && booking.dropLng != null)
                      Marker(
                        markerId: const MarkerId('drop'),
                        position: LatLng(booking.dropLat!, booking.dropLng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: InfoWindow(title: 'Drop: ${booking.dropAddress}'),
                      ),
                    if (booking.driverLat != null && booking.driverLng != null)
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: LatLng(booking.driverLat!, booking.driverLng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        anchor: const Offset(0.5, 0.5),
                        infoWindow: const InfoWindow(title: 'Driver Location'),
                        zIndexInt: 2,
                      ),
                  },
                  polylines: {
                    if (booking.pickupLat != null && booking.dropLat != null)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        color: AppColors.primary,
                        width: 5,
                        points: [
                          LatLng(booking.pickupLat!, booking.pickupLng!),
                          LatLng(booking.dropLat!, booking.dropLng!),
                        ],
                      ),
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (booking.pickupLat != null && booking.dropLat != null) {
                      final bounds = LatLngBounds(
                        southwest: LatLng(
                          booking.pickupLat! < booking.dropLat! ? booking.pickupLat! : booking.dropLat!,
                          booking.pickupLng! < booking.dropLng! ? booking.pickupLng! : booking.dropLng!,
                        ),
                        northeast: LatLng(
                          booking.pickupLat! > booking.dropLat! ? booking.pickupLat! : booking.dropLat!,
                          booking.pickupLng! > booking.dropLng! ? booking.pickupLng! : booking.dropLng!,
                        ),
                      );
                      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
                    } else {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                      );
                    }
                  },
                ),
        ),

        // Top GoLorry header bar
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black87),
                      onPressed: () {},
                    ),
                  ),
                  Text('GoLorry',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF00915E), letterSpacing: -0.5)),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87), onPressed: () {}),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom info card
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
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking.status,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      booking.id.length > 8 ? booking.id.substring(0, 8) : booking.id,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
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
                  // Use lowercase comparison now that status is normalized
                  booking.status == 'pending' ? 'Waiting for a driver to accept...' : 'Driver is heading to pickup',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await BookingService().cancelBooking(booking.id);
                      } catch (e) {
                        debugPrint('Cancel error: $e');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel Booking', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
