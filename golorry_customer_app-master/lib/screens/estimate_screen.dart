import 'package:flutter/material.dart';
import 'tracking_screen.dart';

class EstimateScreen extends StatelessWidget {
  final double distanceKm;
  final double durationMin;
  final double estimatedFare;

  const EstimateScreen({
    super.key,
    required this.distanceKm,
    required this.durationMin,
    required this.estimatedFare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Price Estimate")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.route),
              title: const Text("Distance"),
              trailing: Text("${distanceKm.toStringAsFixed(2)} km"),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text("Estimated Time"),
              trailing: Text("${durationMin.toStringAsFixed(0)} mins"),
            ),
            const Divider(),

            const Text(
              "Estimated Amount",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "₹ ${estimatedFare.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 32, color: Colors.green),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackingScreen(
                        pickupAddress: 'Pickup (Demo)',
                        dropAddress: 'Drop (Demo)',
                        vehicleName: 'Motorcycle',
                        tier: 'Standard',
                        itemTypes: const [],
                        valueOfGoods: 'Under ₹2000',
                        paymentMethod: 'Cash',
                        totalFare: estimatedFare,
                      ),
                    ),
                  );
                },
                child: const Text("Confirm Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
