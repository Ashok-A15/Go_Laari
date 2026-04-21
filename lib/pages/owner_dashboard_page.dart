import 'package:flutter/material.dart';
import '../widgets/owner_map.dart';
import '../services/firestore_service.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final GlobalKey<OwnerMapState> _mapKey = GlobalKey<OwnerMapState>();
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic> _fleetStats = {'total': 0, 'active': 0, 'idle': 0, 'earnings': 0.0};

  @override
  void initState() {
    super.initState();
    _loadFleetStats();
  }

  Future<void> _loadFleetStats() async {
    final stats = await _firestoreService.getFleetStats();
    if (mounted) setState(() => _fleetStats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          OwnerMap(
            key: _mapKey,
            showDefaultLocationButton: false,
          ),
          
          // Fleet Status Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43CEA2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF185A9D)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Fleet Status",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                        ),
                        Text(
                          "${_fleetStats['active']} Active • ${_fleetStats['idle']} Idle",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Compact stat badges
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF43CEA2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${_fleetStats['total']} Total",
                      style: const TextStyle(
                        color: Color(0xFF43CEA2),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Earnings badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF56ab2f).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "₹${(_fleetStats['earnings'] as num?)?.toStringAsFixed(0) ?? '0'}",
                      style: const TextStyle(
                        color: Color(0xFF56ab2f),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Positioned(
            bottom: 120,
            right: 20,
            child: Column(
              children: [
                _buildActionButton(context, Icons.my_location_rounded, () {
                  _mapKey.currentState?.animateToCurrentLocation();
                }),
                const SizedBox(height: 12),
                _buildActionButton(context, Icons.refresh_rounded, () {
                  _loadFleetStats();
                }),
                const SizedBox(height: 12),
                _buildActionButton(context, Icons.layers_rounded, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, VoidCallback onTap, {bool primary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF185A9D) : Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: primary ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
