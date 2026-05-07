import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_colors.dart';
import '../services/geocoding_service.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onBookLorry;

  const HomeScreen({super.key, this.onBookLorry});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  static const _apiKey = 'AIzaSyBRspa8sydUkQsiyfNKlQiGMKtRY_agSMg';

  String _userName = 'Customer';
  String _cityName = 'Locating...';
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Quick Services
  final List<_ServiceItem> _services = [
    _ServiceItem('Multi-stop\nDelivery', Icons.alt_route_rounded, const Color(0xFF6366F1)),
    _ServiceItem('Scheduled\nBooking', Icons.event_available_rounded, const Color(0xFF10B981)),
    _ServiceItem('Hire\nHelpers', Icons.people_alt_rounded, const Color(0xFFF59E0B)),
    _ServiceItem('Bulk\nTransport', Icons.inventory_2_rounded, const Color(0xFF3B82F6)),
    _ServiceItem('Invoice &\nBilling', Icons.receipt_long_rounded, const Color(0xFFEC4899)),
    _ServiceItem('Proof of\nDelivery', Icons.verified_rounded, const Color(0xFF06B6D4)),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_fetchUserProfile(), _fetchCity()]);
    if (mounted) {
      setState(() => _isLoading = false);
      _animController.forward();
    }
  }

  Future<void> _fetchUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _db.collection('users').doc(user.uid).get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data()!.containsKey('name')) {
        _userName = doc.data()!['name'];
      } else {
        _userName = user.displayName ??
            user.email?.split('@')[0] ??
            'Customer';
      }
    } catch (_) {
      _userName = _auth.currentUser?.email?.split('@')[0] ?? 'Customer';
    }
  }

  Future<void> _fetchCity() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _cityName = 'India';
        return;
      }
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        final addr = await GeocodingService(_apiKey)
            .getAddressFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 4));
        if (addr != null) {
          final parts = addr.split(',');
          _cityName = parts.isNotEmpty ? parts[0].trim() : 'India';
        }
      } else {
        _cityName = 'India';
      }
    } catch (_) {
      _cityName = 'India';
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _animController.reset();
              await _loadData();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ── GRADIENT HEADER ───────────────────────────
                SliverToBoxAdapter(child: _buildHeader()),

                // ── BOOK A LORRY CTA ─────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  sliver: SliverToBoxAdapter(child: _buildBookCTA()),
                ),

                // ── QUICK SERVICES ────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _sectionHeader('Quick Services', null),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _buildServicesGrid()),
                ),

                // ── RECENT ACTIVITY ───────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _sectionHeader('Recent Activity', 'View all'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _buildRecentActivity()),
                ),

                // ── TIPS & GUIDES ─────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _sectionHeader('Tips & Guides', null),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
                  sliver: SliverToBoxAdapter(child: _buildTipsCarousel()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────
  Widget _buildHeader() {
    return Stack(
      children: [
        // Gradient background with curved bottom
        ClipPath(
          clipper: _HeaderClipper(),
          child: Container(
            height: 190,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Greeting
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location pill
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: Color(0xFF00D4AA)),
                          const SizedBox(width: 4),
                          Text(
                            _cityName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00D4AA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_greeting, ${_firstName(_userName)} 👋',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Book trucks for your transport needs',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded,
                            color: Colors.white, size: 26),
                        onPressed: () {},
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFFF43F5E),
                              shape: BoxShape.circle),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // BOOK A LORRY CTA
  // ─────────────────────────────────────────────────
  Widget _buildBookCTA() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onBookLorry ?? () {},
        splashColor: AppColors.primary.withValues(alpha: 0.15),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00D4AA), Color(0xFF0097A7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book a Lorry',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to select pickup & drop location',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // QUICK SERVICES GRID
  // ─────────────────────────────────────────────────
  Widget _buildServicesGrid() {
    final isDark = AppColors.isDark;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _services.length,
      itemBuilder: (context, i) {
        final s = _services[i];
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            splashColor: s.color.withValues(alpha: 0.1),
            child: Ink(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2028) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.icon, color: s.color, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // RECENT ACTIVITY
  // ─────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    final isDark = AppColors.isDark;
    return StreamBuilder<List<BookingModel>>(
      stream: BookingService().getUserBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shimmerCard(isDark);
        }

        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) {
          return _emptyActivity(isDark);
        }

        // Show last 2 bookings
        final recent = bookings.take(2).toList();
        return Column(
          children: recent.map((b) => _activityCard(b, isDark)).toList(),
        );
      },
    );
  }

  Widget _activityCard(BookingModel b, bool isDark) {
    final statusColor = _statusColor(b.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_shipping_rounded,
                  color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.route,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.distance.isNotEmpty ? b.distance : b.vehicleName,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${b.totalFare.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    b.status,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyActivity(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No trips yet',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Your bookings will appear here',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _shimmerCard(bool isDark) {
    final c = isDark ? const Color(0xFF2A2E39) : const Color(0xFFF0F0F0);
    return Container(
      height: 76,
      decoration: BoxDecoration(
          color: c, borderRadius: BorderRadius.circular(16)),
    );
  }

  // ─────────────────────────────────────────────────
  // TIPS & GUIDES
  // ─────────────────────────────────────────────────
  Widget _buildTipsCarousel() {
    final isDark = AppColors.isDark;
    final tips = [
      _TipItem('How to post a load?',
          'Learn to book in just 3 taps', Icons.play_circle_fill_rounded, const Color(0xFF6366F1)),
      _TipItem('How pricing works?',
          'Understand fare calculations', Icons.attach_money_rounded, const Color(0xFF10B981)),
      _TipItem('Best truck for your goods',
          'Pick the right vehicle type', Icons.local_shipping_rounded, const Color(0xFF3B82F6)),
    ];
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: tips.length,
        itemBuilder: (context, i) {
          final t = tips[i];
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2028) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: t.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(t.icon, color: t.color, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.title,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                                maxLines: 2),
                            const SizedBox(height: 4),
                            Text(t.subtitle,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                                maxLines: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────
  Widget _sectionHeader(String title, String? actionLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }

  String _firstName(String name) {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'there';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in transit':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'accepted':
        return const Color(0xFF10B981);
      default: // pending, etc.
        return const Color(0xFFF59E0B);
    }
  }
}

// ─────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────
class _ServiceItem {
  final String label;
  final IconData icon;
  final Color color;
  const _ServiceItem(this.label, this.icon, this.color);
}

class _TipItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _TipItem(this.title, this.subtitle, this.icon, this.color);
}

// ─────────────────────────────────────────────────
// CUSTOM CLIPPER FOR CURVED HEADER BOTTOM
// ─────────────────────────────────────────────────
class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 36);
    path.quadraticBezierTo(
        size.width / 2, size.height + 12, size.width, size.height - 36);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HeaderClipper old) => false;
}
