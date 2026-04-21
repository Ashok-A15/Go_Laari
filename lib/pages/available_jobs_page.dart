import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class AvailableJobsPage extends StatefulWidget {
  const AvailableJobsPage({super.key});

  @override
  State<AvailableJobsPage> createState() => _AvailableJobsPageState();
}

class _AvailableJobsPageState extends State<AvailableJobsPage> {
  final FirestoreService _firestoreService = FirestoreService();

  void _takeJob(String bookingId) async {
    try {
      await _firestoreService.takeJob(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Job Accepted!"),
            backgroundColor: const Color(0xFF43CEA2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text("Available Jobs"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.getAvailableBookingsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Show the actual error so we can diagnose issues
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "Error loading jobs:\n${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Client-side filter: only unassigned bookings (driverId is empty or null)
          var docs = (snapshot.data?.docs ?? []).where((d) {
            final driverId = (d.data()['driverId'] ?? '').toString().trim();
            return driverId.isEmpty;
          }).toList();
          docs.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  Text("No new jobs available", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;
              
              // Handle customer app model vs driver app custom mock
              final pickup = data['pickupAddress'] ?? data['route'] ?? 'Unknown Pickup';
              final drop = data['dropAddress'] ?? '';
              final fare = data['totalFare']?.toString() ?? data['price']?.toString() ?? '0';
              final distance = data['distance']?.toString() ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              
              final dateStr = createdAt != null 
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E272E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.my_location, color: Color(0xFF185A9D), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(pickup, style: const TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              if (drop.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 7),
                                  child: Text(" |", style: TextStyle(color: Colors.grey)),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(drop, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          "₹$fare",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF185A9D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          distance.isNotEmpty ? "$distance km" : "",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43CEA2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _takeJob(docId),
                        child: const Text("Take Job", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
