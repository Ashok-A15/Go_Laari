import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide Marker;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps show Marker;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golorry_customer_app/services/directions_service.dart';
import 'package:golorry_customer_app/services/geocoding_service.dart';
import 'package:golorry_customer_app/services/booking_service.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:lottie/lottie.dart';
import 'package:golorry_customer_app/widgets/skeleton_loader.dart';
import 'package:golorry_customer_app/utils/marker_helper.dart';
import 'package:golorry_customer_app/utils/map_constants.dart';

class TrackingScreen extends StatefulWidget {
  final String pickupAddress;
  final String dropAddress;
  final String vehicleName;
  final String tier;
  final List<String> itemTypes;
  final String valueOfGoods;
  final String paymentMethod;
  final double totalFare;
  final int? totalDistanceMeters;

  const TrackingScreen({
    super.key,
    required this.pickupAddress,
    required this.dropAddress,
    required this.vehicleName,
    required this.tier,
    required this.itemTypes,
    required this.valueOfGoods,
    required this.paymentMethod,
    required this.totalFare,
    this.totalDistanceMeters,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  Set<gmaps.Marker> _markers = {};
  Set<Polyline> _polylines = {};

  double? _distanceKm;
  double? _durationMin;
  bool _loading = true;
  bool _confirming = false;
  bool _driversFound = false;
  bool _mapExpanded = false;

  @override
  void initState() {
    super.initState();
    _initLocations();

    // Simulate finding drivers
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _driversFound = true);
    });
  }

  Future<void> _initLocations() async {
    final geo = GeocodingService(MapConstants.googleMapsApiKey);
    _pickupLocation = await geo.getCoordinates(widget.pickupAddress);
    _dropLocation = await geo.getCoordinates(widget.dropAddress);

    // Fallbacks for demo if geocoding fails
    _pickupLocation ??= const LatLng(12.9716, 77.5946);
    _dropLocation ??= const LatLng(12.9352, 77.6245);

    // Generate REAL professional markers
    final pickupIcon = await MarkerHelper.getCustomMarker(Icons.local_shipping_rounded, const Color(0xFF00D4AA));
    final dropIcon = await MarkerHelper.getCustomMarker(Icons.warehouse_rounded, const Color(0xFFEF4444));

    if (mounted) {
      setState(() {
        _markers = {
          gmaps.Marker(
            markerId: const MarkerId('pickup'),
            position: _pickupLocation!,
            icon: pickupIcon,
            infoWindow: InfoWindow(title: 'Pickup', snippet: widget.pickupAddress),
          ),
          gmaps.Marker(
            markerId: const MarkerId('drop'),
            position: _dropLocation!,
            icon: dropIcon,
            infoWindow: InfoWindow(title: 'Drop-off', snippet: widget.dropAddress),
          ),
        };
      });
      await _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    if (_pickupLocation == null || _dropLocation == null) {
      setState(() => _loading = false);
      return;
    }
    
    final result = await DirectionsService().getDirections(
      origin: _pickupLocation!,
      destination: _dropLocation!,
    );

    if (mounted) {
      setState(() {
        if (result != null) {
          _distanceKm = result.distanceValue / 1000.0;
          _durationMin = result.durationValue / 60.0;
          _loading = false;
        } else {
          _loading = false;
        }
      });
    }
  }


  Future<void> _confirmBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _confirming = true);
    try {
      final String generatedOtp = (1000 + Random().nextInt(9000)).toString();
      final booking = BookingModel(
        id: '',
        customerId: user.uid,
        pickupAddress: widget.pickupAddress,
        dropAddress: widget.dropAddress,
        vehicleName: widget.vehicleName,
        tier: widget.tier,
        itemTypes: widget.itemTypes,
        valueOfGoods: widget.valueOfGoods,
        paymentMethod: widget.paymentMethod,
        totalFare: widget.totalFare,
        route: '${widget.pickupAddress.split(',')[0]} → ${widget.dropAddress.split(',')[0]}',
        distance: '${(_distanceKm ?? 8.5).toStringAsFixed(1)} km • ${(_durationMin ?? 25).toStringAsFixed(0)} min',
        status: 'pending',
        createdAt: DateTime.now(),
        otp: generatedOtp,
        totalDistanceMeters: widget.totalDistanceMeters,
      );
      await BookingService().createBooking(booking);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.network(
                      'https://lottie.host/17b9c9df-1510-476c-843c-62c1d0637172/u9Zp5N0T8F.json',
                      height: 120,
                      repeat: false,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Booking Confirmed!',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connecting you with your driver...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Wait a bit to show the animation, then go home
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint('Booking creation failed: $e');
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create booking: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _confirming ? null : AppBar(
        title: Text('Booking Summary', // Changed to Summary/Report feel
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, size: 24, color: AppColors.textPrimary), // Using Close for report feel
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _confirming 
        ? Container(color: isDark ? const Color(0xFF1B1E26) : const Color(0xFFF8FAFC))
        : Container(
            color: isDark ? const Color(0xFF1B1E26) : const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BOOKING REPORT', 
                style: GoogleFonts.inter(
                  fontSize: 12, 
                  fontWeight: FontWeight.w800, 
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
                      const SizedBox(height: 16),
                      
                      _reportSection(isDark, 'Route Details', [
                        _routeRow(Icons.radio_button_checked_rounded, const Color(0xFF00D4AA), 'PICKUP', widget.pickupAddress),
                        _dottedLine(),
                        _routeRow(Icons.location_on_rounded, const Color(0xFFEF4444), 'DROP', widget.dropAddress),
                        
                        if (_distanceKm != null) ...[
                          const Divider(height: 32),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _statItem('Distance', '${_distanceKm!.toStringAsFixed(1)} km'),
                            _statItem('Est. Time', '${(_durationMin ?? 25).toStringAsFixed(0)} min'),
                            _statItem('Vehicle', widget.vehicleName),
                          ]),
                        ],
                      ]),

                      const SizedBox(height: 16),

                      _reportSection(isDark, 'Service Details', [
                        _summaryRow('Tier', widget.tier),
                        _summaryRow('Payment', widget.paymentMethod),
                        if (widget.itemTypes.isNotEmpty) _summaryRow('Goods', widget.itemTypes.join(', ')),
                        _summaryRow('Value', widget.valueOfGoods),
                      ]),

                      const SizedBox(height: 16),

                      _reportSection(isDark, 'Pricing Summary', [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Base Fare', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          Text('₹${(widget.totalFare * 0.85).toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        ]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Taxes & Fees', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                          Text('₹${(widget.totalFare * 0.15).toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        ]),
                        const Divider(height: 24),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Total Payable', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('₹${widget.totalFare.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ]),
                      ]),

                      const SizedBox(height: 32),

                      // ── ACTION BUTTONS ────────────────────
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton(
                              onPressed: (_confirming || !_driversFound) ? null : _confirmBooking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00915E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: _confirming
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Icon(Icons.check_circle_outline_rounded, size: 22),
                                      const SizedBox(width: 12),
                                      Text('Confirm Booking and Track', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                                    ]),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('Cancel Booking', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _reportSection(bool isDark, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232731) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _routeRow(IconData icon, Color color, String label, String address) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        Text(address, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }

  Widget _dottedLine() {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(children: List.generate(3, (_) =>
          Container(margin: const EdgeInsets.only(bottom: 3), width: 1.5, height: 5, color: AppColors.border))),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 70, child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
        Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ]),
    );
  }
}
