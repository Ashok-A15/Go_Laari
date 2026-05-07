import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';
import 'settings/profile_info_screen.dart';
import 'settings/change_password_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/help_center_screen.dart';
import 'settings/privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _userName = 'Customer';
  String _email = '';
  int _totalTrips = 0;
  double _totalSpend = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final results = await Future.wait([
        _db.collection('users').doc(user.uid).get(),
        _db
            .collection('bookings')
            .where('customerId', isEqualTo: user.uid)
            .get(),
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
          _userName =
              userDoc.exists ? (userDoc['name'] ?? user.email?.split('@')[0] ?? 'Customer') : (user.email?.split('@')[0] ?? 'Customer');
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
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log Out',
                style: GoogleFonts.inter(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // ── GRADIENT HEADER ───────────────────────────
                SliverToBoxAdapter(child: _buildHeader(isDark)),

                // ── ACCOUNT SUMMARY ───────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(child: _buildSummaryCard(isDark)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── ACCOUNT ───────────────────────────
                        _sectionLabel('ACCOUNT'),
                        const SizedBox(height: 10),
                        _menuCard(isDark, children: [
                          _tile(context, Icons.person_outline_rounded,
                              'Profile Information', const Color(0xFF6366F1), isDark,
                              onTap: () => _push(const ProfileInfoScreen())),
                          _divider(isDark),
                          _tile(context, Icons.location_on_outlined,
                              'Saved Addresses', const Color(0xFF3B82F6), isDark,
                              onTap: () => _snack('Saved Addresses coming soon')),
                          _divider(isDark),
                          _tile(context, Icons.payment_rounded,
                              'Payment Methods', const Color(0xFF10B981), isDark,
                              onTap: () => _snack('Payment Methods coming soon')),
                        ]),

                        const SizedBox(height: 20),

                        // ── SECURITY ──────────────────────────
                        _sectionLabel('SECURITY'),
                        const SizedBox(height: 10),
                        _menuCard(isDark, children: [
                          _tile(context, Icons.lock_outline_rounded,
                              'Change Password', const Color(0xFFF59E0B), isDark,
                              onTap: () => _push(const ChangePasswordScreen())),
                        ]),

                        const SizedBox(height: 20),

                        // ── APP SETTINGS ──────────────────────
                        _sectionLabel('APP SETTINGS'),
                        const SizedBox(height: 10),
                        _menuCard(isDark, children: [
                          _tile(context, Icons.notifications_none_rounded,
                              'Notifications', const Color(0xFF8B5CF6), isDark,
                              onTap: () => _push(const NotificationsScreen())),
                          _divider(isDark),
                          _darkModeRow(isDark),
                        ]),

                        const SizedBox(height: 20),

                        // ── SUPPORT ───────────────────────────
                        _sectionLabel('SUPPORT'),
                        const SizedBox(height: 10),
                        _menuCard(isDark, children: [
                          _tile(context, Icons.help_outline_rounded,
                              'Help Center', const Color(0xFF06B6D4), isDark,
                              onTap: () => _push(const HelpCenterScreen())),
                          _divider(isDark),
                          _tile(context, Icons.privacy_tip_outlined,
                              'Privacy Policy', const Color(0xFF64748B), isDark,
                              onTap: () => _push(const PrivacyPolicyScreen())),
                        ]),

                        const SizedBox(height: 24),

                        // ── LOGOUT ────────────────────────────
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _logout,
                            splashColor: AppColors.error.withValues(alpha: 0.1),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A1E24)
                                    : AppColors.error.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.error.withValues(alpha: 0.2),
                                    width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: AppColors.error
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle),
                                    child: Icon(Icons.exit_to_app_rounded,
                                        color: AppColors.error, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Log Out',
                                            style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.error)),
                                        Text('Sign out of your account',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      color: AppColors.error.withValues(alpha: 0.5),
                                      size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Header ────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final initial =
        _userName.trim().isNotEmpty ? _userName.trim()[0].toUpperCase() : 'C';
    return Stack(
      children: [
        ClipPath(
          clipper: _HeaderClipper(),
          child: Container(
            height: 210,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Account',
                        style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: Colors.white, size: 24),
                        onPressed: () {},
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF00D4AA), width: 2),
                          ),
                          child: Center(
                            child: Text(initial,
                                style: GoogleFonts.inter(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: Color(0xFF00D4AA), shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded,
                                size: 12, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_userName,
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(_email,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.65))),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  // ── Account Summary Card ──────────────────────────
  Widget _buildSummaryCard(bool isDark) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2028) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statCol('$_totalTrips', 'Total Trips',
                Icons.local_shipping_rounded, const Color(0xFF6366F1)),
            _verticalDivider(isDark),
            _statCol('₹${_formatAmount(_totalSpend)}', 'Total Spend',
                Icons.currency_rupee_rounded, const Color(0xFF10B981)),
            _verticalDivider(isDark),
            _statCol('0', 'Saved Routes',
                Icons.bookmark_outline_rounded, const Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }

  Widget _statCol(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
        width: 1, height: 60, color: AppColors.border.withValues(alpha: 0.5));
  }

  // ── Helpers ───────────────────────────────────────
  Widget _menuCard(bool isDark, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label,
      Color iconColor, bool isDark,
      {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkModeRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.dark_mode_outlined,
                size: 18, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text('Switch app appearance',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppColors.themeNotifier,
            builder: (_, mode, __) => Switch(
              value: mode == ThemeMode.dark,
              activeColor: const Color(0xFF00D4AA),
              onChanged: (_) => AppColors.toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: AppColors.border.withValues(alpha: 0.5));

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1.2)),
      );

  String _formatAmount(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.inter()),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 40);
    p.quadraticBezierTo(
        size.width / 2, size.height + 10, size.width, size.height - 40);
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
