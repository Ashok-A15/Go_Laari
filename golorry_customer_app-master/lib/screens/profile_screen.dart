import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'settings/profile_info_screen.dart';
import 'settings/change_password_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/help_center_screen.dart';
import 'settings/privacy_policy_screen.dart';
import 'settings/saved_addresses_screen.dart';
import 'settings/payments_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _userName = 'Customer';
  String _email = '';
  int _totalTrips = 0;
  double _totalSpend = 0;
  bool _isLoading = true;

  late AnimationController _waveController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _load();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        _db.collection('users').doc(user.uid).get(),
        _db.collection('bookings').where('customerId', isEqualTo: user.uid).get(),
      ]);
      final userDoc = results[0] as DocumentSnapshot;
      final bookingSnap = results[1] as QuerySnapshot;

      final bookings = bookingSnap.docs;
      double spend = 0;
      for (final d in bookings) {
        spend += ((d.data() as Map)['totalFare'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _userName = userDoc.exists
              ? (userDoc['name'] ?? user.email?.split('@')[0] ?? 'Customer')
              : (user.email?.split('@')[0] ?? 'Customer');
          _email = user.email ?? '';
          _totalTrips = bookings.length;
          _totalSpend = spend;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userName = _auth.currentUser?.email?.split('@')[0] ?? 'Customer';
          _email = _auth.currentUser?.email ?? '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: AppColors.surface.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: AppColors.error.withValues(alpha: 0.2))),
          title: Text('Log Out', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          content: Text('Are you sure you want to exit the GoLorry platform?', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Stay', style: GoogleFonts.inter(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Exit Now', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    // Layered backgrounds for enhanced dark mode
    final layeredBg = isDark 
        ? const Color(0xFF081120) 
        : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: layeredBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── HERO HEADER ────────────────────────────
                SliverToBoxAdapter(child: _buildHeroHeader(isDark)),

                // ── SMART STATS ────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(child: _buildStatsGrid(isDark)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      
                      _sectionTitle('ACCOUNT'),
                      _glassPanel(isDark, [
                        _tile(Icons.person_rounded, 'Personal Info', 'Manage your profile details', const Color(0xFF6366F1), () => _push(const ProfileInfoScreen())),
                        _divider(isDark),
                        _tile(Icons.location_on_rounded, 'Saved Addresses', 'Quick access to locations', const Color(0xFF3B82F6), () => _push(const SavedAddressesScreen())),
                        _divider(isDark),
                        _tile(Icons.credit_card_rounded, 'Payments', 'Wallet & Transaction history', const Color(0xFF10B981), () => _push(const PaymentsScreen())),
                      ]),

                      const SizedBox(height: 24),

                      // ── LOGISTICS PERSONALIZATION ───────
                      _sectionTitle('LOGISTICS SMARTS'),
                      _glassPanel(isDark, [
                        _tile(Icons.auto_graph_rounded, 'Cost Optimization', 'Save on your frequent routes', const Color(0xFFF59E0B), () {}),
                        _divider(isDark),
                        _tile(Icons.map_rounded, 'Smart Route Suggester', 'AI-powered transit efficiency', const Color(0xFF8B5CF6), () {}),
                      ]),

                      const SizedBox(height: 24),

                      // ── TRUST & SAFETY ──────────────────
                      _sectionTitle('TRUST & SAFETY'),
                      _glassPanel(isDark, [
                        _tile(Icons.verified_user_rounded, 'Verified Customer', 'Your status is confirmed', const Color(0xFF00D4AA), () {}, trailing: _badge()),
                      ]),

                      const SizedBox(height: 24),

                      // ── APP SETTINGS ─────────────────────
                      _sectionTitle('PREFERENCES'),
                      _glassPanel(isDark, [
                        _tile(Icons.notifications_active_rounded, 'Notifications', 'Real-time transit alerts', const Color(0xFF6366F1), () => _push(const NotificationsScreen())),
                        _divider(isDark),
                        _darkModeRow(isDark),
                      ]),

                      const SizedBox(height: 24),

                      // ── SUPPORT HUB ──────────────────────
                      _sectionTitle('SUPPORT HUB'),
                      _glassPanel(isDark, [
                        _tile(Icons.help_center_rounded, 'FAQ & Help', 'Common logistics answers', const Color(0xFF64748B), () {}),
                      ]),

                      const SizedBox(height: 24),

                      // ── LOGOUT ───────────────────────────
                      _logoutButton(isDark),

                      const SizedBox(height: 120), // Extra space for floating nav
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroHeader(bool isDark) {
    return Container(
      height: 300, // Increased height to prevent overflow
      child: Stack(
        children: [
          // Animated Wave Background
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: _WavePainter(_waveController.value, isDark),
                size: const Size(double.infinity, 280),
              );
            },
          ),
          
          // Logistics Grid Pattern
          Opacity(
            opacity: 0.1,
            child: CustomPaint(
              painter: _GridPainter(),
              size: const Size(double.infinity, 260),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Settings', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Profile Card (Glass)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        // Avatar with Animated Ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _particleController,
                              builder: (context, child) {
                                return Container(
                                  width: 76, height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.5 * _particleController.value), width: 4),
                                  ),
                                );
                              },
                            ),
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                              child: Text(_userName[0].toUpperCase(), style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text(_email, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        _statCard(isDark, '$_totalTrips', 'Total Shipments', Icons.local_shipping_rounded, const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        _statCard(isDark, '₹${_formatAmount(_totalSpend)}', 'Total Logistics Spend', Icons.account_balance_wallet_rounded, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _statCard(bool isDark, String val, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0E1A32) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(val, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _glassPanel(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132548).withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap, {Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted.withValues(alpha: 0.3), size: 14),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF00D4AA).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00D4AA), size: 16),
    );
  }

  Widget _darkModeRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.dark_mode_rounded, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('Switch app appearance', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppColors.themeNotifier,
            builder: (_, mode, __) => Switch(
              value: mode == ThemeMode.dark,
              activeTrackColor: const Color(0xFF2DD4BF).withValues(alpha: 0.5),
              activeColor: const Color(0xFF2DD4BF),
              onChanged: (_) => AppColors.toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFEF4444).withValues(alpha: 0.1), const Color(0xFFEF4444).withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
      ),
      child: ListTile(
        onTap: _logout,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
        ),
        title: Text('Log Out', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFEF4444))),
        subtitle: Text('Sign out of your session', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444), size: 24),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.5)),
    );
  }

  Widget _divider(bool isDark) => Divider(height: 1, color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1));

  String _formatAmount(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

class _WavePainter extends CustomPainter {
  final double value;
  final bool isDark;
  _WavePainter(this.value, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: isDark 
            ? [const Color(0xFF0F3460), const Color(0xFF16213E), const Color(0xFF081120)]
            : [const Color(0xFF0EA5E9), const Color(0xFF3B82F6), const Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.lineTo(0, size.height - 40);
    
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(i, size.height - 40 + (8 * (1 - value) * (i / 100).remainder(1) * 2 - 1).abs());
    }
    // Simple wave approximation
    path.reset();
    path.lineTo(0, size.height - 20);
    path.quadraticBezierTo(size.width * 0.25, size.height - 60, size.width * 0.5, size.height - 20);
    path.quadraticBezierTo(size.width * 0.75, size.height + 20, size.width, size.height - 20);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
