import 'package:flutter/material.dart';
import '../widgets/owner_map.dart';

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laari Booking Platform"),
      ),
      body: const OwnerMap(),
    );
  }
}
