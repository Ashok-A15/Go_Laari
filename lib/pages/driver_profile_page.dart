import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'profile_info_page.dart';

class DriverProfilePage extends StatelessWidget {
  const DriverProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text("My Profile"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.driverStream(service.currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState(context);
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          
          final String name = data['name'] ?? 'Driver Name';
          final String phone = data['phone'] ?? '+91 XXXXXXXXXX';
          final String email = data['email'] ?? 'driver@golorry.com';
          final String vehicleNumber = data['vehicleNumber'] ?? 'Not Assigned';
          final String status = data['status'] ?? 'Active';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Section ---
                _buildHeader(context, name, "Driver", isDark),
                
                const SizedBox(height: 25),
                
                // --- Contact Details Card ---
                _buildSectionTitle("Personal Details"),
                const SizedBox(height: 12),
                _buildContactCard(context, phone, email, vehicleNumber, status, isDark),
                
                const SizedBox(height: 25),
                
                // --- Stats Overview ---
                _buildSectionTitle("Performance Overview"),
                const SizedBox(height: 12),
                _buildStatsSummary(context, isDark),
                
                const SizedBox(height: 25),
                
                // --- Action Buttons ---
                _buildActionButtons(context),
                
                const SizedBox(height: 100), // Space for FAB or Bottom Nav padding
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String role, bool isDark) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF43CEA2).withOpacity(0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: isDark ? const Color(0xFF1E272E) : Colors.white,
                  child: Icon(Icons.person_rounded, size: 60, color: Colors.grey.shade400),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF43CEA2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                role,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildContactCard(BuildContext context, String phone, String email, String vehicleNumber, String status, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.phone_rounded, "Phone", phone, const Color(0xFF43CEA2)),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(Icons.email_rounded, "Email", email, const Color(0xFF185A9D)),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(Icons.local_shipping_rounded, "Vehicle Number", vehicleNumber, Colors.orange),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(Icons.verified_user_rounded, "Status", status.toUpperCase(), status.toLowerCase() == 'active' ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSummary(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildStatItem(context, "12", "Total Trips", Icons.route_rounded, const Color(0xFF185A9D))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(context, "4.8", "Rating", Icons.star_rounded, Colors.orange)),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileInfoPage()),
              );
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text("Edit Details"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF43CEA2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF43CEA2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, size: 60, color: Color(0xFF43CEA2)),
            ),
            const SizedBox(height: 32),
            const Text(
              "Profile Not Found",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "We could not load your driver profile details.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
