import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golorry_customer_app/services/booking_service.dart';
import 'package:golorry_customer_app/models/booking_model.dart';
import 'package:intl/intl.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _selectedMethod = 'UPI';

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Payment Insights', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: BookingService().getUserBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
          }
          
          final bookings = snapshot.data ?? [];
          
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined, size: 80, color: AppColors.textMuted.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No payment history found', 
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Your trip transactions will appear here', 
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                ],
              ),
            );
          }

          final upiTotal = _calculateTotal(bookings, 'UPI');
          final cashTotal = _calculateTotal(bookings, 'Cash');
          final otherTotal = _calculateTotal(bookings, 'Other');

          double currentDisplayAmount = 0;
          if (_selectedMethod == 'UPI') currentDisplayAmount = upiTotal;
          if (_selectedMethod == 'Cash') currentDisplayAmount = cashTotal;
          if (_selectedMethod == 'Other') currentDisplayAmount = otherTotal;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── MAIN DISPLAY ────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getGradient(_selectedMethod),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: _getGradient(_selectedMethod)[0].withValues(alpha: 0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Text('Total Used via $_selectedMethod', 
                        style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      Text('₹${NumberFormat('#,##,###').format(currentDisplayAmount)}', 
                        style: GoogleFonts.outfit(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Last transaction: ${_getLastDate(bookings, _selectedMethod)}', 
                        style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── SELECTION OPTIONS ───────────────────────
                Text('SELECT PAYMENT METHOD', 
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                
                _methodOption('UPI', Icons.account_balance_rounded, const Color(0xFF6366F1), upiTotal),
                const SizedBox(height: 12),
                _methodOption('Cash', Icons.payments_rounded, const Color(0xFF10B981), cashTotal),
                const SizedBox(height: 12),
                _methodOption('Other', Icons.more_horiz_rounded, const Color(0xFF64748B), otherTotal),

                const SizedBox(height: 40),

                // ── FOOTER INSIGHT ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF132548).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insights_rounded, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Your primary payment choice is $_selectedMethod. Switch methods above to see historical spend.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _methodOption(String id, IconData icon, Color color, double amount) {
    final isSelected = _selectedMethod == id;
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.15) 
              : (isDark ? const Color(0xFF1E2028) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border, 
            width: isSelected ? 2 : 1
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('Usage summary', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Text('₹${amount.toInt()}', 
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? color : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  double _calculateTotal(List<BookingModel> bookings, String method) {
    return bookings
        .where((b) => b.paymentMethod.toLowerCase().contains(method.toLowerCase()) || 
                      (method == 'Other' && !b.paymentMethod.toLowerCase().contains('upi') && !b.paymentMethod.toLowerCase().contains('cash')))
        .fold(0.0, (sum, b) => sum + b.totalFare);
  }

  String _getLastDate(List<BookingModel> bookings, String method) {
    final filtered = bookings.where((b) => b.paymentMethod.toLowerCase().contains(method.toLowerCase())).toList();
    if (filtered.isEmpty) return 'No history';
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return DateFormat('MMM dd, yyyy').format(filtered.first.createdAt);
  }

  List<Color> _getGradient(String method) {
    if (method == 'UPI') return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
    if (method == 'Cash') return [const Color(0xFF059669), const Color(0xFF10B981)];
    return [const Color(0xFF475569), const Color(0xFF64748B)];
  }
}
