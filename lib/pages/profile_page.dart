import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder(
        stream: service.ownerStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("Owner data not found"),
            );
          }

          final data = snapshot.data!.data()!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(
                    data['name'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(data['email'] ?? ''),
                ),

                const SizedBox(height: 24),

                _card(
                  "₹${data['totalEarnings']}",
                  "Total Earnings",
                  Colors.green,
                ),
                const SizedBox(height: 12),

                _card(
                  "${data['activeLaaris']}",
                  "Active Laaris",
                  Colors.blue,
                ),
                const SizedBox(height: 12),

                _card(
                  "${data['activeDrivers']}",
                  "Active Drivers",
                  Colors.orange,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(String value, String label, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}
