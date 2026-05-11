import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  MapType _currentMapType = MapType.normal;

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
            mapType: _currentMapType,
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
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
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
                      color: const Color(0xFF43CEA2).withValues(alpha: 0.1),
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
                      color: const Color(0xFF43CEA2).withValues(alpha: 0.1),
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
                      color: const Color(0xFF56ab2f).withValues(alpha: 0.1),
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
                _buildActionButton(context, Icons.layers_rounded, _showMapTypeSelector),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Select Map Type",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMapTypeOption(MapType.normal, "Default", Icons.map_rounded),
                _buildMapTypeOption(MapType.satellite, "Satellite", Icons.satellite_alt_rounded),
                _buildMapTypeOption(MapType.terrain, "Transport", Icons.terrain_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(MapType type, String label, IconData icon) {
    final isSelected = _currentMapType == type;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        setState(() => _currentMapType = type);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF43CEA2).withValues(alpha: 0.1) : theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF43CEA2) : Colors.grey.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF43CEA2).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFF43CEA2) : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF43CEA2) : Colors.grey,
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
            color: Colors.black.withValues(alpha: 0.1),
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
