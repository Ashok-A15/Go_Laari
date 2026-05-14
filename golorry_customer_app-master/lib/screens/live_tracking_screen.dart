import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:golorry_customer_app/providers/tracking_provider.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:golorry_customer_app/screens/map_screen.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:golorry_customer_app/utils/marker_helper.dart';

class LiveTrackingScreen extends StatefulWidget {
  final BookingModel booking;

  const LiveTrackingScreen({
    super.key,
    required this.booking,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _truckIcon;
  BitmapDescriptor? _destinationIcon;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackingProvider>();
      
      // Get destination LatLng from booking or geocode it
      // For now, assuming we have a way to get it. 
      // In a real app, BookingModel should have pickup/drop LatLng.
      // If not, we'd geocode it here once.
      // For this "fresh" implementation, I'll use a placeholder or 
      // better, I'll assume the provider will handle it if we pass addresses.
      // But LatLng is better.
      
      // Temporary: using a static LatLng for demonstration of road-following
      final LatLng destination = const LatLng(12.9352, 77.6245); 

      provider.startTracking(widget.booking.id, destination);
    });
  }

  Future<void> _loadMarkers() async {
    _truckIcon = await MarkerHelper.getTruckMarker();
    _destinationIcon = await MarkerHelper.getCustomMarker(Icons.location_on, Colors.red);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TrackingProvider>(
        builder: (context, tracking, child) {
          final driverLoc = tracking.driverLocation;
          
          print('DEBUG [LiveTrackingScreen]: UI Update. Driver Loc: $driverLoc, Polylines: ${tracking.polylines.length}');
          if (tracking.polylines.isNotEmpty) {
            print('DEBUG [LiveTrackingScreen]: Active Polyline ID: ${tracking.polylines.first.polylineId.value}, Points: ${tracking.polylines.first.points.length}');
          }

          if (driverLoc == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Auto-follow logic
          if (_mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(driverLoc));
          }

          return Stack(
            children: [
              MapScreen(
                initialPosition: driverLoc,
                isLiveTracking: true,
                driverLocation: driverLoc,
                driverHeading: tracking.driverHeading,
                polylines: tracking.polylines,
                markers: {
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: driverLoc,
                    icon: _truckIcon ?? BitmapDescriptor.defaultMarker,
                    rotation: tracking.driverHeading,
                    anchor: const Offset(0.5, 0.5),
                  ),
                  if (tracking.polylines.isNotEmpty)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: tracking.polylines.first.points.last,
                      icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
                    ),
                },
                onMapCreated: (controller) => _mapController = controller,
              ),

              _buildHeader(context),
              _buildBottomPanel(tracking),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleIcon(Icons.arrow_back, () => Navigator.pop(context)),
          _statusBadge(),
          _circleIcon(Icons.support_agent, () {}),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(TrackingProvider tracking) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESTIMATED ARRIVAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
                    Text(tracking.eta, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                ),
                _tripStat('Distance', tracking.distanceRemaining),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                const CircleAvatar(radius: 25, backgroundImage: NetworkImage('https://i.pravatar.cc/150')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rahul S.', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Suzuki Carry • KA 01 JS 9922', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                _actionBtn(Icons.call, Colors.green),
                const SizedBox(width: 8),
                _actionBtn(Icons.message, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text('On the way', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
