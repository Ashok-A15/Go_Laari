import 'package:flutter/material.dart';
import 'tracking_screen.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  void _proceed() {
    if (_fromController.text.trim().isEmpty ||
        _toController.text.trim().isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackingScreen(
          pickupAddress: _fromController.text.trim(),
          dropAddress: _toController.text.trim(),
          vehicleName: 'Motorcycle',
          tier: 'Standard',
          itemTypes: const [],
          valueOfGoods: 'Under ₹2000',
          paymentMethod: 'Cash',
          totalFare: 950.0,
        ),
      ),
    );

  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Selection")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [


            TextField(
  controller: _fromController,
  decoration: const InputDecoration(
    labelText: "Pickup Location",
    hintText: "Eg: Koramangala, Bengaluru",
    prefixIcon: Icon(Icons.my_location),
  ),
),



            const SizedBox(height: 15),


            TextField(
  controller: _toController,
  decoration: const InputDecoration(
    labelText: "Drop Location",
    hintText: "Eg: MG Road, Bengaluru",
    prefixIcon: Icon(Icons.location_on),
  ),
),



            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _proceed,
                child: const Text("Get Route & Fare"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
