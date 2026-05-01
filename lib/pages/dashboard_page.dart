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
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<Position>? _locationSubscription;
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
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
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
    if (_isOwner) return;

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _firestoreService.updateDriverLocation(position.latitude, position.longitude);
    });
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
          _fleetStats = stats;
          _isLoading = false;
        });
        _animController.forward();
        
        if (role == 'driver') {
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
      appBar: AppBar(
        title: Text(_isOwner ? "Owner Dashboard" : "Driver Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: FadeTransition(
        opacity: _animController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E272E), const Color(0xFF2C3E50)]
                        : [const Color(0xFF43CEA2), const Color(0xFF185A9D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF185A9D).withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_getGreeting()} 👋",
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                          ),
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isOwner ? "Owner" : "Driver",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              if (_isOwner) ...[
                const Text(
                  "Fleet Overview",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _statCard("${_fleetStats['total']}", "Total Laaris", Icons.local_shipping_rounded, 
                          [const Color(0xFF6dd5ed), const Color(0xFF2193b0)]),
                      _statCard("${_fleetStats['active']}", "Active", Icons.play_arrow_rounded, 
                          [const Color(0xFF43CEA2), const Color(0xFF185A9D)]),
                      _statCard("${_fleetStats['idle']}", "Idle", Icons.pause_circle_rounded, 
                          [const Color(0xFFff9966), const Color(0xFFff5e62)]),
                      _statCard("₹${(_fleetStats['earnings'] as num?)?.toStringAsFixed(0) ?? '0'}", "Earnings", Icons.account_balance_wallet_rounded, 
                          [const Color(0xFF56ab2f), const Color(0xFFa8e063)]),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOwner ? "Active Tracking" : "My Current Location",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isOwner)
                    TextButton(
                      onPressed: () {},
                      child: const Text("View All"),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingPage()));
                      },
                      child: const Text("Active Trip"),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const OwnerMap(),
                ),
              ),

              if (!_isOwner) ...[
                const SizedBox(height: 30),
                _buildTakeJobButton(),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTakeJobButton() {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43CEA2), Color(0xFF185A9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF185A9D).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AvailableJobsPage()));
          },
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 20),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    "Take New Job",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    "Available nearby trips",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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
            color: gradient[1].withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.9),
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
