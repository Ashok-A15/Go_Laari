import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_animarker/flutter_animarker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:golorry_customer_app/providers/tracking_provider.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:golorry_customer_app/services/map_camera_service.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:golorry_customer_app/utils/marker_helper.dart';

class LiveTrackingScreen extends StatefulWidget {
  final BookingModel booking;
  final String apiKey;

  const LiveTrackingScreen({
    super.key,
    required this.booking,
    required this.apiKey,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _truckIcon;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackingProvider>();
      
      print('DEBUG: Starting Live Tracking for Booking ${widget.booking.id}');
      
      // PRODUCTION: Replace with real destination from BookingModel
      const LatLng destination = LatLng(12.9352, 77.6245); 

      provider.startTracking(
        widget.booking.id,
        widget.apiKey,
        destination,
      );
      
      provider.addListener(_onTrackingUpdate);
    });
  }

  void _onTrackingUpdate() {
    final tracking = context.read<TrackingProvider>();
    if (tracking.driverLocation != null && _mapController != null) {
      MapCameraService.followDriver(
        controller: _mapController,
        driverPos: tracking.driverLocation!,
        heading: tracking.driverHeading,
      );
    }
  }

  Future<void> _loadAssets() async {
    _truckIcon = await MarkerHelper.getTruckMarker();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 7. Render ALL decoded coordinates in GoogleMap Polyline
    return Consumer<TrackingProvider>(
      builder: (context, tracking, child) {
        print('DEBUG UI: Rendering ${tracking.polylines.length} polylines');
        if (tracking.polylines.isNotEmpty) {
          final polyline = tracking.polylines.first;
          print('DEBUG UI: Polyline ID: ${polyline.polylineId}, Points: ${polyline.points.length}');
        }

        return Scaffold(
          body: Stack(
            children: [
              // 1. Map Layer with Animarker
              if (tracking.driverLocation != null)
                Animarker(
                  curve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 2000),
                  mapId: Future.value(_mapController?.mapId ?? 0),
                  markers: {
                    Marker(
                      markerId: const MarkerId('driver'),
                      position: tracking.driverLocation!,
                      icon: _truckIcon ?? BitmapDescriptor.defaultMarker,
                      rotation: tracking.driverHeading,
                      anchor: const Offset(0.5, 0.5),
                    ),
                  },
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: tracking.driverLocation!,
                      zoom: 17,
                      tilt: 45,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController?.setMapStyle(_silverMapStyle);
                    },
                    // 9. Connected correctly to provider polylines
                    polylines: tracking.polylines,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    mapType: MapType.normal,
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),

              _buildHeader(context),
              _buildBottomPanel(tracking),
            ],
          ),
        );
      },
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
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
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

  static const String _silverMapStyle = '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]';
}
