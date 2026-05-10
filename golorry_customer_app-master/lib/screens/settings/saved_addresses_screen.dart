import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Saved Addresses', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final addresses = (data?['savedAddresses'] as List<dynamic>?) ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, size: 80, color: AppColors.textMuted.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No addresses saved yet', 
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Save your home, work, or frequent spots', 
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index] as Map<String, dynamic>;
              return _addressCard(addr, isDark, index);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressDialog,
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text('Add New', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> addr, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132548).withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getIconForType(addr['type'] ?? 'Other'),
              color: const Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addr['label'] ?? 'Address', 
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(addr['address'] ?? '', 
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteAddress(index),
            icon: Icon(Icons.delete_outline_rounded, color: AppColors.error.withValues(alpha: 0.6), size: 20),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Home': return Icons.home_rounded;
      case 'Work': return Icons.work_rounded;
      case 'Warehouse': return Icons.warehouse_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  void _showAddAddressDialog() {
    final labelCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    String type = 'Home';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add Saved Address', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(labelCtrl, 'Label (e.g. My Home)', Icons.label_outline_rounded),
            const SizedBox(height: 12),
            _dialogField(addrCtrl, 'Full Address', Icons.map_outlined),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              dropdownColor: AppColors.surface,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: ['Home', 'Work', 'Warehouse', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => type = v!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              if (labelCtrl.text.isNotEmpty && addrCtrl.text.isNotEmpty) {
                _addAddress({
                  'label': labelCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'type': type,
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _addAddress(Map<String, dynamic> newAddr) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    await _db.collection('users').doc(userId).update({
      'savedAddresses': FieldValue.arrayUnion([newAddr])
    });
  }

  Future<void> _deleteAddress(int index) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    final doc = await _db.collection('users').doc(userId).get();
    final addresses = List<dynamic>.from(doc.data()?['savedAddresses'] ?? []);
    addresses.removeAt(index);
    
    await _db.collection('users').doc(userId).update({
      'savedAddresses': addresses
    });
  }
}
