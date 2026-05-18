import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../widgets/owner_map.dart';
import '../services/firestore_service.dart';
import 'available_jobs_page.dart';
import 'live_tracking_page.dart';
import 'notification_settings_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  String userName = "User";
  bool _isOwner = false;
  bool _isLoading = true;
  bool _isOnline = false;
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _jobSubscription;
  bool _hasNewJobAlert = false;
  Map<String, dynamic> _fleetStats = {'total': 0, 'active': 0, 'idle': 0, 'earnings': 0.0};
  
  // Map Type and Controls
  MapType _currentMapType = MapType.normal;
  bool _trafficEnabled = false;
  final GlobalKey<OwnerMapState> _mapKey = GlobalKey<OwnerMapState>();

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadDashboardData();
    _listenForJobs();
  }

  void _listenForJobs() {
    _jobSubscription?.cancel();
    _jobSubscription = _firestoreService.getAvailableBookingsStream().listen((snapshot) {
      if (!_isOwner && _isOnline) {
        final availableJobs = snapshot.docs.where((doc) => 
          (doc.data()['driverId'] ?? '').toString().isEmpty
        ).toList();

        if (mounted) {
          setState(() => _hasNewJobAlert = availableJobs.isNotEmpty);
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _jobSubscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  void _startLocationSharing() {
    if (_isOwner || !_isOnline) return;

    _locationSubscription?.cancel();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _firestoreService.updateDriverLocation(position.latitude, position.longitude);
    });
  }

  void _toggleOnlineStatus(bool value) async {
    setState(() {
      _isOnline = value;
      if (!value) _hasNewJobAlert = false;
    });
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !_isOwner) {
      await FirebaseFirestore.instance.collection('drivers').doc(user.uid).update({
        'isOnline': value,
      });
    }

    if (value) {
      _startLocationSharing();
    } else {
      _locationSubscription?.cancel();
      _locationSubscription = null;
    }
  }

  Future<void> _loadDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final role = await _firestoreService.getUserRole();
    final collection = role == 'owner' ? 'owners' : 'drivers';

    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .doc(user.uid)
          .get();

      Map<String, dynamic> stats = {'total': 0, 'active': 0, 'idle': 0, 'earnings': 0.0};
      if (role == 'owner') {
        stats = await _firestoreService.getFleetStats();
      }

      if (mounted) {
        setState(() {
          userName = snap.exists ? (snap.data()?["name"] ?? "User") : "User";
          _isOwner = role == 'owner';
          _isOnline = snap.exists ? (snap.data()?["isOnline"] ?? false) : false;
          _fleetStats = stats;
          _isLoading = false;
        });
        _animController.forward();
        
        if (role == 'driver' && _isOnline) {
          _startLocationSharing();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      body: Stack(
        children: [
          // 1. Full Screen Map
          Positioned.fill(
            child: OwnerMap(
              key: _mapKey,
              mapType: _currentMapType,
              trafficEnabled: _trafficEnabled,
              driverMode: true, // Hide other drivers, show only own lorry
            ),
          ),

          // 2. Floating Header Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            right: 15,
            child: FadeTransition(
              opacity: _animController,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E272E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isOwner ? "Owner Fleet" : "Driver Dashboard",
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF185A9D),
                            ),
                          ),
                          Text(
                            "${_getGreeting()}, $userName 👋",
                            style: TextStyle(
                              fontSize: 11, 
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isOwner) ...[
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isOnline ? "ONLINE" : "OFFLINE",
                            style: TextStyle(
                              fontSize: 8, 
                              fontWeight: FontWeight.bold,
                              color: _isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          SizedBox(
                            height: 24,
                            child: Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: _isOnline,
                                activeColor: const Color(0xFF43CEA2),
                                onChanged: (val) => _toggleOnlineStatus(val),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 20),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsPage())),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Stats (Owner Only)
          if (_isOwner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _animController,
                child: SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _statCard("${_fleetStats['total']}", "Total", Icons.local_shipping_rounded, [const Color(0xFF6dd5ed), const Color(0xFF2193b0)]),
                      _statCard("${_fleetStats['active']}", "Active", Icons.play_arrow_rounded, [const Color(0xFF43CEA2), const Color(0xFF185A9D)]),
                      _statCard("${_fleetStats['idle']}", "Idle", Icons.pause_circle_rounded, [const Color(0xFFff9966), const Color(0xFFff5e62)]),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Job Alert Banner
          if (_hasNewJobAlert && !_isOwner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 90,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableJobsPage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43CEA2),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: const Color(0xFF43CEA2).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "New Job Available! Tap to view",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Map Controls
          Positioned(
            right: 15,
            bottom: _isOwner ? 100 : 200,
            child: Column(
              children: [
                _mapControlButton(isDark: isDark, icon: Icons.layers_rounded, onTap: _showMapTypeSelector),
                const SizedBox(height: 12),
                _mapControlButton(isDark: isDark, icon: Icons.my_location_rounded, onTap: () => _mapKey.currentState?.animateToCurrentLocation()),
              ],
            ),
          ),

          // 6. Bottom Info Panel (Driver Only)
          if (!_isOwner)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _animController,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.getActiveBookingStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final bookingDoc = snapshot.data!.docs.first;
                      final bookingData = bookingDoc.data();
                      final pickup = bookingData['pickupAddress'] ?? bookingData['route'] ?? 'Unknown';
                      final status = bookingData['status'] ?? 'accepted';
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF185A9D),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Active Job: ${status.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                  Text(pickup, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTrackingPage(bookingId: bookingDoc.id, bookingData: bookingData))),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF185A9D),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text("RESUME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E272E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Status: ${_isOnline ? 'Online' : 'Offline'}", style: TextStyle(fontWeight: FontWeight.bold, color: _isOnline ? Colors.green : Colors.grey)),
                              Text(_isOnline ? "Waiting for new jobs..." : "Go online to see jobs", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableJobsPage())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF43CEA2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Jobs"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String title, IconData icon, List<Color> gradient) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: gradient[1].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton({required bool isDark, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 45,
        width: 45,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E272E) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: const Color(0xFF185A9D), size: 20),
      ),
    );
  }

  void _showMapTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E272E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Map type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _mapTypeItem(setSheetState, "Default", MapType.normal),
                  _mapTypeItem(setSheetState, "Satellite", MapType.satellite),
                  _mapTypeItem(setSheetState, "Terrain", MapType.terrain),
                ],
              ),
              const SizedBox(height: 30),
              const Text("Map details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(children: [_mapDetailItem(setSheetState, "Traffic", Icons.traffic_rounded, _trafficEnabled)]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapTypeItem(StateSetter setSheetState, String label, MapType type) {
    final isSelected = _currentMapType == type;
    return GestureDetector(
      onTap: () {
        setSheetState(() => _currentMapType = type);
        setState(() => _currentMapType = type);
      },
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFF43CEA2).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              border: Border.all(color: isSelected ? const Color(0xFF43CEA2) : Colors.transparent, width: 3),
            ),
            child: Icon(
              type == MapType.satellite ? Icons.satellite_alt_rounded : (type == MapType.terrain ? Icons.terrain_rounded : Icons.map_rounded),
              color: isSelected ? const Color(0xFF43CEA2) : Colors.grey,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
              color: isSelected ? const Color(0xFF43CEA2) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapDetailItem(StateSetter setSheetState, String label, IconData icon, bool enabled) {
    return GestureDetector(
      onTap: () {
        setSheetState(() => _trafficEnabled = !enabled);
        setState(() => _trafficEnabled = !enabled);
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFF43CEA2).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: enabled ? const Color(0xFF43CEA2) : Colors.transparent, width: 2),
            ),
            child: Icon(icon, color: enabled ? const Color(0xFF43CEA2) : Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
