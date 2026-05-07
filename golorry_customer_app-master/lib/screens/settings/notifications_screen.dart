import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Trip Updates
  bool _tripStatus = true;
  bool _driverArrival = true;
  // Payments
  bool _invoiceReceipts = true;
  bool _paymentConfirm = true;
  // Promotions
  bool _offers = false;
  // Communication
  bool _smsAlerts = true;
  bool _pushNotif = true;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Trip Updates ──────────────────────────────
            _buildSection(
              isDark: isDark,
              icon: Icons.local_shipping_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: '🚛 Trip Updates',
              children: [
                _toggleTile(
                  isDark: isDark,
                  title: 'Trip Status Changes',
                  subtitle: 'Get notified when your trip status updates',
                  value: _tripStatus,
                  onChanged: (v) => setState(() => _tripStatus = v),
                ),
                _divider(isDark),
                _toggleTile(
                  isDark: isDark,
                  title: 'Driver Arrival',
                  subtitle: 'Know when your driver is arriving',
                  value: _driverArrival,
                  onChanged: (v) => setState(() => _driverArrival = v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Payments ──────────────────────────────────
            _buildSection(
              isDark: isDark,
              icon: Icons.payment_rounded,
              iconColor: const Color(0xFF10B981),
              title: '💳 Payments',
              children: [
                _toggleTile(
                  isDark: isDark,
                  title: 'Invoice & Receipts',
                  subtitle: 'Receive digital invoices after each trip',
                  value: _invoiceReceipts,
                  onChanged: (v) => setState(() => _invoiceReceipts = v),
                ),
                _divider(isDark),
                _toggleTile(
                  isDark: isDark,
                  title: 'Payment Confirmations',
                  subtitle: 'Alerts when a payment is processed',
                  value: _paymentConfirm,
                  onChanged: (v) => setState(() => _paymentConfirm = v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Promotions ────────────────────────────────
            _buildSection(
              isDark: isDark,
              icon: Icons.local_offer_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: '📢 Promotions',
              children: [
                _toggleTile(
                  isDark: isDark,
                  title: 'Offers & Discounts',
                  subtitle: 'Receive special deals and promo codes',
                  value: _offers,
                  onChanged: (v) => setState(() => _offers = v),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Communication ─────────────────────────────
            _buildSection(
              isDark: isDark,
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: '📡 Communication',
              children: [
                _toggleTile(
                  isDark: isDark,
                  title: 'SMS Alerts',
                  subtitle: 'Receive updates via SMS on your phone',
                  value: _smsAlerts,
                  onChanged: (v) => setState(() => _smsAlerts = v),
                ),
                _divider(isDark),
                _toggleTile(
                  isDark: isDark,
                  title: 'Push Notifications',
                  subtitle: 'Allow GoLorry to send push notifications',
                  value: _pushNotif,
                  onChanged: (v) => setState(() => _pushNotif = v),
                ),
              ],
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF00D4AA), size: 18),
                      const SizedBox(width: 10),
                      Text('Notification preferences saved!',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600))
                    ]),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Save Preferences',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2028) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _toggleTile({
    required bool isDark,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF00D4AA),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border.withValues(alpha: 0.5));
}
