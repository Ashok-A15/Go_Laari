import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../widgets/owner_map.dart';
import '../services/firestore_service.dart';
import 'available_jobs_page.dart';
import 'tracking_page.dart';

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
      appBar: null,
      body: Stack(
        children: [
          // 1. Full Screen Map
          const Positioned.fill(
            child: OwnerMap(),
          ),

          // 2. Floating Header Card (Matching Bottom Style)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            right: 15,
            child: FadeTransition(
              opacity: _animController,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark 
                    ? const Color(0xFF1E272E).withValues(alpha: 0.9) 
                    : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
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
                                onChanged: _toggleOnlineStatus,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Top UI Elements (Stats for Owner)
          if (_isOwner)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _animController,
                child: Column(
                  children: [
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _statCard("${_fleetStats['total']}", "Total", Icons.local_shipping_rounded, 
                              [const Color(0xFF6dd5ed), const Color(0xFF2193b0)]),
                          _statCard("${_fleetStats['active']}", "Active", Icons.play_arrow_rounded, 
                              [const Color(0xFF43CEA2), const Color(0xFF185A9D)]),
                          _statCard("${_fleetStats['idle']}", "Idle", Icons.pause_circle_rounded, 
                              [const Color(0xFFff9966), const Color(0xFFff5e62)]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2.5 New Job Alert Banner
          if (_hasNewJobAlert && !_isOwner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 90,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableJobsPage()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43CEA2),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF43CEA2).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.notifications_active, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
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

          // 3. Floating Quick Info for Driver
          if (!_isOwner)
            Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _animController,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Status: Online", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          Text("Waiting for new jobs...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableJobsPage()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43CEA2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Jobs"),
                      ),
                    ],
                  ),
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
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
