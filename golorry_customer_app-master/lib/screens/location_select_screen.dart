import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:golorry_customer_app/utils/app_colors.dart';

class LocationSelectScreen extends StatefulWidget {
  const LocationSelectScreen({super.key});

  @override
  State<LocationSelectScreen> createState() => _LocationSelectScreenState();
}

class _LocationSelectScreenState extends State<LocationSelectScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  bool _pickupFocused = false;
  bool _dropFocused = false;

  final String _placesApiKey = 'AIzaSyBHKu2YcOIN7RN-_mbU-UfzzXexvXh2apA';
  List<Map<String, dynamic>> _predictions = [];
  String? _activeField;

  Future<void> _fetchSuggestions(String query, bool isPickup) async {
    if (query.isEmpty) {
      setState(() => _predictions.clear());
      return;
    }
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&components=country:in&key=$_placesApiKey',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && mounted) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(data['predictions']);
            _activeField = isPickup ? 'pickup' : 'drop';
          });
        }
      }
    } catch (e) {
      debugPrint('Places API error: $e');
    }
  }

  void _onSuggestionSelected(String description) {
    if (_activeField == 'pickup') {
      _pickupController.text = description;
      _pickupFocused = false;
      FocusScope.of(context).unfocus();
    } else if (_activeField == 'drop') {
      _dropController.text = description;
      _dropFocused = false;
      FocusScope.of(context).unfocus();
    }
    setState(() => _predictions.clear());
  }

  void _proceed() {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter both pickup and drop locations',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, {'pickup': pickup, 'drop': drop});
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book a Lorry'),
        backgroundColor: AppColors.surface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Locations',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter pickup & delivery addresses',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 28),

              // ── Location Card ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    // Pickup
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          setState(() => _pickupFocused = hasFocus);
                          if (hasFocus && _pickupController.text.isNotEmpty) {
                            _fetchSuggestions(_pickupController.text, true);
                          }
                        },
                        child: TextField(
                          controller: _pickupController,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
                          onChanged: (val) => _fetchSuggestions(val, true),
                          decoration: InputDecoration(
                            fillColor: Colors.transparent,
                            filled: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Pickup Location',
                            hintStyle: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.my_location_rounded,
                              color: _pickupFocused
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Divider with dashes
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppColors.border,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Drop
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          setState(() => _dropFocused = hasFocus);
                          if (hasFocus && _dropController.text.isNotEmpty) {
                            _fetchSuggestions(_dropController.text, false);
                          }
                        },
                        child: TextField(
                          controller: _dropController,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                          ),
                          onChanged: (val) => _fetchSuggestions(val, false),
                          decoration: InputDecoration(
                            fillColor: Colors.transparent,
                            filled: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Drop Location',
                            hintStyle: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.location_on_rounded,
                              color: _dropFocused
                                  ? AppColors.error
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Autocomplete Results OR Popular Routes ──────
              Expanded(
                child: _predictions.isNotEmpty
                    ? ListView.separated(
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: AppColors.border, height: 1),
                        itemBuilder: (context, index) {
                          final pred = _predictions[index];
                          return ListTile(
                            leading: Icon(
                              Icons.place_outlined,
                              color: AppColors.textSecondary,
                            ),
                            title: Text(
                              pred['structured_formatting']['main_text'] ??
                                  pred['description'],
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              pred['structured_formatting']['secondary_text'] ??
                                  '',
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () =>
                                _onSuggestionSelected(pred['description']),
                          );
                        },
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Popular Routes',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _suggestionChip('Bengaluru City Centre'),
                          const SizedBox(height: 8),
                          _suggestionChip('Koramangala, Bengaluru'),
                          const SizedBox(height: 8),
                          _suggestionChip('Whitefield, Bengaluru'),
                        ],
                      ),
              ),

              // ── Proceed Button ─────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      _pickupController.text.isNotEmpty &&
                          _dropController.text.isNotEmpty
                      ? _proceed
                      : null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: AppColors.card,
                    disabledForegroundColor: AppColors.textMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Proceed',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return GestureDetector(
      onTap: () {
        if (_pickupController.text.isEmpty) {
          _pickupController.text = label;
        } else {
          _dropController.text = label;
        }
        setState(() {});
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.north_west_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
