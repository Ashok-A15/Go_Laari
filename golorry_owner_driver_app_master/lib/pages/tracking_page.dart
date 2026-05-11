import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  GoogleMapController? _mapController;
  LatLng? _customerLocation;
  String _customerAddress = "Searching for customer...";
  String _status = "ON DUTY";

  static const CameraPosition _startLocation = CameraPosition(
    target: LatLng(22.7196, 75.8577), 
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _fetchActiveJob();
  }

  Future<void> _fetchActiveJob() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Find active booking for driver
    final snap = await FirebaseFirestore.instance.collection('bookings')
        .where('driverId', isEqualTo: uid)
        .where('status', whereIn: ['Confirmed', 'In Transit'])
        .limit(1)
        .get();
        
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final data = doc.data();
      String pickup = data['pickupAddress'] ?? data['route'] ?? 'Unknown location';
      
      setState(() {
        _customerAddress = pickup;
        _status = data['status'] == 'Confirmed' ? 'TO PICKUP' : 'IN TRANSIT';
      });

      // Try to geocode
      try {
        List<Location> locations = await locationFromAddress(pickup);
        if (locations.isNotEmpty) {
          setState(() {
            _customerLocation = LatLng(locations.first.latitude, locations.first.longitude);
          });
          
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _customerLocation!, zoom: 15)
              )
            );
          }
        }
      } catch (e) {
        debugPrint("Geocoding failed for $pickup: $e");
      }
    } else {
      setState(() {
        _customerAddress = "No active trip";
        _status = "IDLE";
      });
    }
  }

  Future<void> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _animateToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    if (_customerLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: "Customer Location"),
        )
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Location Map"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _startLocation,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_customerLocation != null) {
                controller.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(target: _customerLocation!, zoom: 15)
                ));
              }
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_customerAddress, 
                      style: TextStyle(color: Colors.grey.shade600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            top: 90,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: "tracking_loc_btn",
              onPressed: _animateToCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF185A9D)),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF43CEA2).withOpacity(0.1),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF185A9D)),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Customer Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("Customer details hidden", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(_status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _infoItem(Icons.route_rounded, "Destination", _customerAddress)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call_rounded, color: Colors.white),
                          label: const Text("Call Customer", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF185A9D)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.close_rounded, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
