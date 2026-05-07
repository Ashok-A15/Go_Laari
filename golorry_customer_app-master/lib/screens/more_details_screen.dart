import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import 'tracking_screen.dart';

class MoreDetailsScreen extends StatefulWidget {
  final String pickupAddress;
  final String dropAddress;
  final String vehicleName;
  final String tier;
  final double totalFare;

  const MoreDetailsScreen({
    super.key,
    required this.pickupAddress,
    required this.dropAddress,
    required this.vehicleName,
    required this.tier,
    required this.totalFare,
  });

  @override
  State<MoreDetailsScreen> createState() => _MoreDetailsScreenState();
}

class _MoreDetailsScreenState extends State<MoreDetailsScreen> {
  bool _favDriver = false;
  bool _detailsExpanded = true;
  final _notesCtrl = TextEditingController();

  // Goods types (chips)
  final Map<String, String> _goodsTypes = {
    'Furniture': '🛋',
    'Electronics': '📱',
    'Groceries': '🥬',
    'Clothing': '👕',
    'Construction': '🧱',
    'Machinery': '⚙️',
    'Household': '🏠',
    'Others': '📦',
  };
  final Set<String> _selectedGoods = {};

  // Weight estimate
  String _weightEst = 'Less than 250 kg';
  final _weights = ['Less than 250 kg', '250 – 500 kg', '500 – 1000 kg', '1000+ kg'];

  // Value of goods
  String _valueOfGoods = 'Less than ₹2,000';
  final _values = ['Less than ₹2,000', '₹2,000 – ₹10,000', '₹10,000 – ₹50,000', '₹50,000+'];

  // Payment
  String _paymentMethod = 'Online payment';
  String? _couponCode;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Add Details',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Route summary bar ───────────────────────
          _buildRouteSummary(isDark),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Goods Type ───────────────────────
                _sectionCard(
                  isDark: isDark,
                  icon: Icons.inventory_2_outlined,
                  title: 'Goods Type',
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _goodsTypes.entries.map((e) {
                      final sel = _selectedGoods.contains(e.key);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) _selectedGoods.remove(e.key); else _selectedGoods.add(e.key);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF00915E).withValues(alpha: 0.08) : (isDark ? const Color(0xFF232731) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? const Color(0xFF00915E) : AppColors.border, width: sel ? 1.5 : 0.6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(e.value, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(e.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, color: sel ? const Color(0xFF00915E) : AppColors.textPrimary)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Weight Estimate ───────────────────
                _sectionCard(
                  isDark: isDark,
                  icon: Icons.scale_outlined,
                  title: 'Weight Estimate',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _weights.map((w) {
                        final sel = _weightEst == w;
                        return GestureDetector(
                          onTap: () => setState(() => _weightEst = w),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF00915E).withValues(alpha: 0.08) : (isDark ? const Color(0xFF232731) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? const Color(0xFF00915E) : AppColors.border, width: sel ? 1.5 : 0.6),
                            ),
                            child: Text(w, style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, color: sel ? const Color(0xFF00915E) : AppColors.textPrimary)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Value of Goods ───────────────────
                _sectionCard(
                  isDark: isDark,
                  icon: Icons.monetization_on_outlined,
                  title: 'Value of Goods',
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _values.map((v) {
                      final sel = _valueOfGoods == v;
                      return GestureDetector(
                        onTap: () => setState(() => _valueOfGoods = v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFF00915E).withValues(alpha: 0.08) : (isDark ? const Color(0xFF232731) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? const Color(0xFF00915E) : AppColors.border, width: sel ? 1.5 : 0.6),
                          ),
                          child: Text(v, style: GoogleFonts.inter(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal, color: sel ? const Color(0xFF00915E) : AppColors.textPrimary)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Driver Notes ─────────────────────
                _sectionCard(
                  isDark: isDark,
                  icon: Icons.comment_outlined,
                  title: 'Notes to Driver (optional)',
                  child: TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'E.g. Handle with care, fragile items, ring doorbell…',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF232731) : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Favourite Drivers ──────────────────
                _switchCard(isDark, Icons.favorite_outline_rounded, 'Favourite drivers first',
                    'Assign drivers you\'ve rated 5⭐', _favDriver, (v) => setState(() => _favDriver = v)),
                const SizedBox(height: 12),

                // ── Payment Method ────────────────────
                _sectionCard(
                  isDark: isDark,
                  icon: Icons.payments_outlined,
                  title: 'Payment Method',
                  child: Column(children: [
                    _paymentOption('UPI', Icons.account_balance_rounded, 'Pay via Google Pay, PhonePe…', isDark),
                    _paymentOption('Online payment', Icons.payment_rounded, 'Debit / Credit card', isDark),
                    _paymentOption('Cash', Icons.money_rounded, 'Pay driver directly', isDark),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Coupon ────────────────────────────
                _couponCard(isDark),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // ── Bottom bar ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1E26) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      Text('₹${widget.totalFare.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(widget.tier, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      Text(widget.vehicleName, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TrackingScreen(
                          pickupAddress: widget.pickupAddress,
                          dropAddress: widget.dropAddress,
                          vehicleName: widget.vehicleName,
                          tier: widget.tier,
                          itemTypes: _selectedGoods.toList(),
                          valueOfGoods: _valueOfGoods,
                          paymentMethod: _paymentMethod,
                          totalFare: widget.totalFare,
                        ),
                      )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00915E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Review Order →', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Route summary ─────────────────────────────────
  Widget _buildRouteSummary(bool isDark) {
    final pickup = widget.pickupAddress.split(',').first.trim();
    final drop = widget.dropAddress.split(',').first.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Column(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
          Container(width: 1.5, height: 22, color: AppColors.border),
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pickup, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(drop, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(widget.vehicleName, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          Text('₹${widget.totalFare.toInt()}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      ]),
    );
  }

  Widget _sectionCard({required bool isDark, required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 17, color: const Color(0xFF00915E)),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _switchCard(bool isDark, IconData icon, String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF00915E)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        ])),
        Switch(value: value, activeColor: const Color(0xFF00915E), onChanged: onChanged),
      ]),
    );
  }

  Widget _paymentOption(String method, IconData icon, String sub, bool isDark) {
    final sel = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF00915E).withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? const Color(0xFF00915E) : AppColors.border, width: sel ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: sel ? const Color(0xFF00915E) : AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(method, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text(sub, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ])),
          if (sel) const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF00915E)),
        ]),
      ),
    );
  }

  Widget _couponCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _couponCode != null ? const Color(0xFF10B981) : AppColors.border,
          width: _couponCode != null ? 1.5 : 0.5,
        ),
      ),
      child: Row(children: [
        Icon(Icons.local_offer_outlined, size: 18, color: _couponCode != null ? const Color(0xFF10B981) : AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: _couponCode != null
            ? Row(children: [
                Text('GLORY20 applied!', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                const SizedBox(width: 6),
                Text('– ₹50 off', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981))),
              ])
            : Text('Add coupon code', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        ),
        GestureDetector(
          onTap: () => setState(() => _couponCode = _couponCode == null ? 'GLORY20' : null),
          child: Text(_couponCode != null ? 'Remove' : 'Apply',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _couponCode != null ? AppColors.error : AppColors.primary)),
        ),
      ]),
    );
  }
}
