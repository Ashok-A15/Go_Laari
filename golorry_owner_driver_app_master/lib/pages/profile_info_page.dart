import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class ProfileInfoPage extends StatefulWidget {
  const ProfileInfoPage({super.key});

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  String _email = "";

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final role = await _firestoreService.getUserRole();
    final collection = role == 'owner' ? 'owners' : 'drivers';
    final doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(_firestoreService.currentUid)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _cityController.text = data['city'] ?? '';
      _companyController.text = data['company'] ?? '';
      _email = data['email'] ?? '';
    }

    if (mounted) setState(() => _isLoading = false);

    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      await _firestoreService.updateOwnerProfile({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'company': _companyController.text.trim(),
      });

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile updated successfully!"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF43CEA2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red.shade600,
          ),
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
        title: const Text("Profile Information"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _animController,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar section
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF43CEA2).withValues(alpha: 0.4), width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: isDark ? const Color(0xFF1E272E) : Colors.white,
                              child: Text(
                                _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : "?",
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF185A9D)),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF43CEA2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Email (read-only)
                    _buildReadOnlyField("Email Address", _email, Icons.email_rounded),

                    const SizedBox(height: 20),

                    // Editable fields
                    Container(
                      padding: const EdgeInsets.all(24),
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
                          _buildEditField("Full Name", _nameController, Icons.person_rounded),
                          const Divider(height: 32),
                          _buildEditField("Phone Number", _phoneController, Icons.phone_rounded, keyboard: TextInputType.phone),
                          const Divider(height: 32),
                          _buildEditField("City", _cityController, Icons.location_on_rounded),
                          const Divider(height: 32),
                          _buildEditField("Company", _companyController, Icons.business_rounded),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43CEA2),
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: _isSaving
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _hasChanges ? "Save Changes" : "No Changes",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _hasChanges ? Colors.white : Colors.grey.shade500,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value.isNotEmpty ? value : "Not set", style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text("Read Only", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboard}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF43CEA2), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            decoration: InputDecoration(
              labelText: label,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
