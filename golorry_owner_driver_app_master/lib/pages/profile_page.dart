import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F171A) : const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text("Owner Profile"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.ownerStream(service.currentUid),
        builder: (context, snapshot) {
          // While loading, show a professional shimmer-like place holder or simple progress
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // If no data, show the requested Empty State
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState(context);
          }

          final data = snapshot.data!.data() ?? {};
          
          // Realistic Fallback Data - "Force Filled" logic
          final String name = data['name'] ?? 'Ramesh Kumar';
          final String role = data['role'] ?? 'Fleet Owner';
          final String phone = data['phone'] ?? '+91 9XXXXXXXXX';
          final String email = data['email'] ?? 'ramesh@golorry.com';
          final String city = data['city'] ?? 'Mysuru, Karnataka';
          final String company = data['company'] ?? 'GoLorry Transport Services';
          
          final int totalLorries = data['totalLorries'] ?? 7;
          final int activeLorries = data['activeLorries'] ?? 5;
          final int idleLorries = data['idleLorries'] ?? 2;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Section ---
                _buildHeader(context, name, role, isDark),
                
                const SizedBox(height: 25),
                
                // --- Contact Details Card ---
                _buildSectionTitle("Contact Details"),
                const SizedBox(height: 12),
                _buildContactCard(context, phone, email, city, company, isDark),
                
                const SizedBox(height: 25),
                
                // --- Fleet Summary Section ---
                _buildSectionTitle("Fleet Summary"),
                const SizedBox(height: 12),
                _buildFleetSummary(context, totalLorries, activeLorries, idleLorries, isDark),
                
                const SizedBox(height: 25),
                
                // --- Action Buttons ---
                _buildActionButtons(context),
                
                const SizedBox(height: 25),
                
                // --- Documents Section ---
                _buildSectionTitle("Documents Status"),
                const SizedBox(height: 12),
                _buildDocumentSection(context, isDark),
                
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
                  border: Border.all(color: const Color(0xFF43CEA2).withValues(alpha: 0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF43CEA2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Verified",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF43CEA2),
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildContactCard(BuildContext context, String phone, String email, String city, String company, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
          _buildInfoRow(Icons.location_on_rounded, "City", city, Colors.orange),
          const Divider(height: 24, thickness: 0.5),
          _buildInfoRow(Icons.business_rounded, "Company", company, Colors.purple),
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
            color: iconColor.withValues(alpha: 0.1),
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

  Widget _buildFleetSummary(BuildContext context, int total, int active, int idle, bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildStatItem(context, total.toString(), "Total Lorries", Icons.local_shipping_rounded, const Color(0xFF185A9D))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(context, active.toString(), "Active", Icons.play_arrow_rounded, const Color(0xFF43CEA2))),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem(context, idle.toString(), "Idle", Icons.pause_rounded, Colors.orange)),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
            onPressed: () {},
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF43CEA2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(context, "Update Docs", Icons.insert_drive_file_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(context, "Manage Fleet", Icons.settings_applications_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(BuildContext context, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white24 : const Color(0xFF185A9D).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF185A9D)),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF185A9D)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildDocumentTile("Driving License", "Verified", Icons.badge_rounded, const Color(0xFF43CEA2)),
        const SizedBox(height: 10),
        _buildDocumentTile("RC Book", "Pending", Icons.description_rounded, Colors.orange),
        const SizedBox(height: 10),
        _buildDocumentTile("Insurance", "Uploaded", Icons.security_rounded, const Color(0xFF185A9D)),
        const SizedBox(height: 10),
        _buildDocumentTile("ID Proof", "Pending", Icons.perm_identity_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildDocumentTile(String title, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF43CEA2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, size: 80, color: Color(0xFF43CEA2)),
            ),
            const SizedBox(height: 32),
            const Text(
              "Complete your profile to start managing deliveries",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Quickly set up your owner details and fleet documents to gain full access.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text("Complete Profile"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
