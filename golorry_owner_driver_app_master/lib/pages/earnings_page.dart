import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'name': 'Driver',
    'totalTrips': 0,
    'earnings': 0.0,
    'distance': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _firestoreService.getDriverStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
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
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text("My Earnings"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF56ab2f).withOpacity(0.1),
              child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF56ab2f)),
            ),
            const SizedBox(height: 12),
            Text(
              _stats['name'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Professional Driver", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 30),
            const Icon(Icons.account_balance_wallet_rounded, size: 60, color: Color(0xFF56ab2f)),
            const SizedBox(height: 10),
            Text(
              "₹${(_stats['earnings'] as double).toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF56ab2f)),
            ),
            const Text("Total Earnings", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  _statRow("Total Trips", "${_stats['totalTrips']}"),
                  const Divider(height: 40),
                  _statRow("Total Distance", "${(_stats['distance'] as double).toStringAsFixed(1)} km"),
                  const Divider(height: 40),
                  _statRow("Wallet Status", "Active", color: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
