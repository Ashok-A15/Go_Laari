import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/directions_service.dart';
import '../services/geocoding_service.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import '../utils/app_colors.dart';

class TrackingScreen extends StatefulWidget {
  final String pickupAddress;
  final String dropAddress;
  final String vehicleName;
  final String tier;
  final List<String> itemTypes;
  final String valueOfGoods;
  final String paymentMethod;
  final double totalFare;

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
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;

  static const _apiKey = 'AIzaSyBRspa8sydUkQsiyfNKlQiGMKtRY_agSMg';

  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  double? _distanceKm;
  double? _durationMin;
  bool _loading = true;
  bool _confirming = false;
  bool _driversFound = false;

  // For the animated driver search
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initLocations();

    // Simulate "3 drivers found nearby" after 2 s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _driversFound = true);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocations() async {
    final geo = GeocodingService(_apiKey);
    _pickupLocation = await geo.getCoordinates(widget.pickupAddress);
    _dropLocation = await geo.getCoordinates(widget.dropAddress);

    _pickupLocation ??= const LatLng(12.9716, 77.5946);
    _dropLocation ??= const LatLng(12.9352, 77.6245);

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          infoWindow: InfoWindow(title: 'Pickup: ${widget.pickupAddress}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('drop'),
          position: _dropLocation!,
          infoWindow: InfoWindow(title: 'Drop: ${widget.dropAddress}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_pickupLocation == null || _dropLocation == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final result = await DirectionsService(_apiKey).getDirections(
        origin: _pickupLocation!, destination: _dropLocation!,
      );
      if (result != null) {
        _distanceKm = result.distanceKm;
        _durationMin = result.durationMin;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            color: AppColors.primary,
            width: 5,
            points: result.polylinePoints,
          ),
        };
      } else {
        _distanceKm = 8.5;
        _durationMin = 25;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            color: AppColors.primary,
            width: 5,
            points: [_pickupLocation!, _dropLocation!],
          ),
        };
      }
    } catch (e) {
      debugPrint('Route error: $e');
      _distanceKm = 8.5;
      _durationMin = 25;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: AppColors.primary,
          width: 5,
          points: [_pickupLocation!, _dropLocation!],
        ),
      };
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _fitCamera();
      }
    }
  }

  void _fitCamera() {
    if (_mapController == null || _pickupLocation == null || _dropLocation == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _pickupLocation!.latitude < _dropLocation!.latitude ? _pickupLocation!.latitude : _dropLocation!.latitude,
        _pickupLocation!.longitude < _dropLocation!.longitude ? _pickupLocation!.longitude : _dropLocation!.longitude,
      ),
      northeast: LatLng(
        _pickupLocation!.latitude > _dropLocation!.latitude ? _pickupLocation!.latitude : _dropLocation!.latitude,
        _pickupLocation!.longitude > _dropLocation!.longitude ? _pickupLocation!.longitude : _dropLocation!.longitude,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  Future<void> _confirmBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _confirming = true);
    try {
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
        status: 'pending',      // lowercase to match driver's Firestore query
        driverId: '',           // empty until a driver accepts
        createdAt: DateTime.now(),
        pickupLat: _pickupLocation?.latitude,
        pickupLng: _pickupLocation?.longitude,
        dropLat: _dropLocation?.latitude,
        dropLng: _dropLocation?.longitude,
      );
      await BookingService().createBooking(booking);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      debugPrint('Booking error: $e');
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final pickup = widget.pickupAddress.split(',').first.trim();
    final drop = widget.dropAddress.split(',').first.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Review & Confirm',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── MAP ──────────────────────────────────────
          Expanded(
            flex: 5,
            child: _loading
                ? Container(
                    color: isDark ? const Color(0xFF1B2028) : const Color(0xFFE8ECEF),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 14),
                        const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                        const SizedBox(height: 12),
                        Text('Fetching live location…',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(target: _pickupLocation ?? const LatLng(12.9716, 77.5946), zoom: 13),
                      markers: _markers,
                      polylines: _polylines,
                      zoomControlsEnabled: false,
                      onMapCreated: (c) { _mapController = c; _fitCamera(); },
                    ),
                  ),
          ),

          // ── INFO PANEL ────────────────────────────────
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  // ── Route card ────────────────────────
                  _card(isDark, child: Column(children: [
                    _routeRow(Icons.radio_button_checked_rounded, const Color(0xFF10B981), 'PICKUP', widget.pickupAddress),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Column(children: List.generate(3, (_) =>
                          Container(margin: const EdgeInsets.only(bottom: 3), width: 1.5, height: 5, color: AppColors.border))),
                    ),
                    _routeRow(Icons.location_on_rounded, const Color(0xFFEF4444), 'DROP', widget.dropAddress),

                    // Distance + ETA
                    if (_distanceKm != null) ...[
                      Divider(height: 18, color: AppColors.border),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _statCol(Icons.route_rounded, '${_distanceKm!.toStringAsFixed(1)} km', 'Distance', const Color(0xFF3B82F6)),
                        Container(width: 1, height: 32, color: AppColors.border),
                        _statCol(Icons.timer_outlined, '${_durationMin!.toStringAsFixed(0)} min', 'Est. Time', const Color(0xFF10B981)),
                        Container(width: 1, height: 32, color: AppColors.border),
                        _statCol(Icons.local_shipping_rounded, widget.vehicleName, 'Vehicle', const Color(0xFFF59E0B)),
                      ]),
                    ],
                  ])),

                  const SizedBox(height: 12),

                  // ── Traffic indicator ─────────────────
                  _card(isDark, child: Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.traffic_rounded, color: Color(0xFF10B981), size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Traffic: Moderate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('Slight delay possible on NH 275', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('+5 min', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFF59E0B)))),
                  ])),

                  const SizedBox(height: 12),

                  // ── Driver search ─────────────────────
                  _card(isDark, child: Row(children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.local_shipping_rounded, color: AppColors.primary, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _driversFound ? '3 drivers found nearby 🎉' : 'Searching for drivers…',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                            color: _driversFound ? const Color(0xFF10B981) : AppColors.textPrimary),
                      ),
                      Text(
                        _driversFound ? 'Best available driver will be assigned' : 'Matching with nearest lorry…',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ])),
                    if (!_driversFound)
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.primary)),
                  ])),

                  const SizedBox(height: 12),

                  // ── Booking summary ───────────────────
                  _card(isDark, child: Column(children: [
                    _summaryRow('Vehicle', widget.vehicleName),
                    _summaryRow('Tier', widget.tier),
                    _summaryRow('Payment', widget.paymentMethod),
                    if (widget.itemTypes.isNotEmpty) _summaryRow('Goods', widget.itemTypes.join(', ')),
                    Divider(height: 16, color: AppColors.border),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total Fare', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      Text('₹${widget.totalFare.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ]),
                  ])),

                  const SizedBox(height: 16),

                  // ── Confirm button ────────────────────
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _confirming ? null : _confirmBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00915E),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _confirming
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text('Confirm Booking', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                            ]),
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

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
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

  Widget _statCol(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
    ]);
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
