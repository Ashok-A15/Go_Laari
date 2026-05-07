import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Realistic demo data shown when Firestore is empty
  static final List<BookingModel> _demoBookings = [
    BookingModel(
      id: 'GL-10492',
      customerId: 'demo',
      pickupAddress: 'Mysuru, Karnataka',
      dropAddress: 'Bangalore, Karnataka',
      vehicleName: 'Tata 407',
      tier: 'Priority',
      itemTypes: ['Furniture'],
      valueOfGoods: '₹25,000',
      paymentMethod: 'UPI',
      totalFare: 2450,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      route: 'Mysuru → Bangalore',
      distance: '145 km • 3h 20m',
    ),
    BookingModel(
      id: 'GL-10491',
      customerId: 'demo',
      pickupAddress: 'Pune, Maharashtra',
      dropAddress: 'Mumbai, Maharashtra',
      vehicleName: '7ft Mini Truck',
      tier: 'Regular',
      itemTypes: ['Electronics'],
      valueOfGoods: '₹40,000',
      paymentMethod: 'Cash',
      totalFare: 3800,
      status: 'in transit',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      route: 'Pune → Mumbai',
      distance: '150 km • 3h 05m',
    ),
    BookingModel(
      id: 'GL-10488',
      customerId: 'demo',
      pickupAddress: 'Chennai, Tamil Nadu',
      dropAddress: 'Coimbatore, Tamil Nadu',
      vehicleName: '8ft Lorry',
      tier: 'Regular',
      itemTypes: ['Building Materials'],
      valueOfGoods: '₹15,000',
      paymentMethod: 'Net Banking',
      totalFare: 5200,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      route: 'Chennai → Coimbatore',
      distance: '490 km • 7h 30m',
    ),
    BookingModel(
      id: 'GL-10480',
      customerId: 'demo',
      pickupAddress: 'Hyderabad, Telangana',
      dropAddress: 'Vijayawada, Andhra Pradesh',
      vehicleName: 'Tata 407',
      tier: 'Pooling',
      itemTypes: ['Machinery'],
      valueOfGoods: '₹80,000',
      paymentMethod: 'UPI',
      totalFare: 4100,
      status: 'cancelled',
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      route: 'Hyderabad → Vijayawada',
      distance: '280 km • 5h 15m',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Gradient App Bar ──────────────────────────
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0F3460),
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F3460), Color(0xFF16213E)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('My Bookings',
                            style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Track and manage all your trips',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.65))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                onPressed: () => _showFilterSheet(context, isDark),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                color: isDark ? const Color(0xFF0F3460) : const Color(0xFF0F3460),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF00D4AA),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      Colors.white.withValues(alpha: 0.50),
                  labelStyle: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle:
                      GoogleFonts.inter(fontSize: 13),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Active'),
                    Tab(text: 'Completed'),
                    Tab(text: 'Cancelled'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<BookingModel>>(
          stream: BookingService()
              .getUserBookings()
              .handleError((e) => debugPrint('Booking error: $e')),
          builder: (context, snapshot) {
            List<BookingModel> allBookings;

            if (snapshot.hasError) {
              return _buildErrorState(isDark);
            }

            // Show demo data immediately while loading or if empty
            allBookings = (snapshot.data == null || snapshot.data!.isEmpty)
                ? _demoBookings
                : snapshot.data!;

            // Summary stats
            final total = allBookings.length;
            final spend = allBookings.fold<double>(
                0, (sum, b) => sum + b.totalFare);

            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(allBookings, 'All', total, spend, isDark),
                _buildList(
                    allBookings
                        .where((b) => b.status == 'in transit' || b.status == 'pending' || b.status == 'accepted')
                        .toList(),
                    'Active',
                    total,
                    spend,
                    isDark),
                _buildList(
                    allBookings
                        .where((b) => b.status == 'completed')
                        .toList(),
                    'Completed',
                    total,
                    spend,
                    isDark),
                _buildList(
                    allBookings
                        .where((b) => b.status == 'cancelled')
                        .toList(),
                    'Cancelled',
                    total,
                    spend,
                    isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // LIST WITH SUMMARY
  // ─────────────────────────────────────────────────
  Widget _buildList(List<BookingModel> bookings, String tab, int totalAll,
      double totalSpend, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Summary card (only on All tab)
        if (tab == 'All')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _buildSummaryCard(totalAll, totalSpend, isDark),
            ),
          ),

        if (bookings.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(tab, isDark))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration:
                        Duration(milliseconds: 300 + (index * 80)),
                    curve: Curves.easeOut,
                    builder: (_, opacity, child) =>
                        Opacity(opacity: opacity, child: child),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildBookingCard(bookings[index], isDark),
                    ),
                  );
                },
                childCount: bookings.length,
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // SUMMARY CARD
  // ─────────────────────────────────────────────────
  Widget _buildSummaryCard(int trips, double spend, bool isDark) {
    final lastDate = _demoBookings.isNotEmpty
        ? _formatDate(_demoBookings.first.createdAt)
        : 'N/A';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4AA), Color(0xFF0097A7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryCol('$trips', 'Trips', Icons.local_shipping_rounded),
          _vertDivider(),
          _summaryCol('₹${_formatAmt(spend)}', 'Spent',
              Icons.currency_rupee_rounded),
          _vertDivider(),
          _summaryCol(lastDate, 'Last Trip', Icons.calendar_today_rounded),
        ],
      ),
    );
  }

  Widget _summaryCol(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
      ],
    );
  }

  Widget _vertDivider() => Container(
      width: 1, height: 48, color: Colors.white.withValues(alpha: 0.3));

  // ─────────────────────────────────────────────────
  // BOOKING CARD
  // ─────────────────────────────────────────────────
  Widget _buildBookingCard(BookingModel b, bool isDark) {
    final statusColor = _statusColor(b.status);
    final statusIcon = _statusIcon(b.status);
    final isActive = ['in transit', 'pending', 'accepted'].contains(b.status.toLowerCase());
    final isDemo = b.customerId == 'demo';

    // Parse city names from address strings
    final pickup = _cityName(b.pickupAddress);
    final drop = _cityName(b.dropAddress);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        splashColor: statusColor.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2028) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isActive
                    ? statusColor.withValues(alpha: 0.5)
                    : AppColors.border.withValues(alpha: 0.5),
                width: isActive ? 1.5 : 0.6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP ROW ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    // Status icon container
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('#${b.id.length > 8 ? b.id.substring(0, 8).toUpperCase() : b.id}',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted)),
                            const Spacer(),
                            _statusBadge(b.status, statusColor),
                          ]),
                          const SizedBox(height: 2),
                          Text(b.vehicleName,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── ROUTE TIMELINE ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF15171F)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('FROM',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                      letterSpacing: 0.8)),
                            ]),
                            const SizedBox(height: 2),
                            Text(pickup,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(children: [
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: AppColors.textMuted),
                          if (b.distance.isNotEmpty)
                            Text(
                              b.distance.split('•').first.trim(),
                              style: GoogleFonts.inter(
                                  fontSize: 9, color: AppColors.textMuted),
                            ),
                        ]),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('TO',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.8)),
                                const SizedBox(width: 6),
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(drop,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── DATE + PRICE + DRIVER ────────────────
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(_formatDate(b.createdAt),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted)),
                  const Spacer(),
                  Text('₹${b.totalFare.toInt()}',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ]),
              ),

              // Driver info (demo realistic data)
              if (!isActive && b.status != 'cancelled')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    Icon(Icons.person_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      isDemo ? _demoDriver(b.id) : 'Driver assigned',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded,
                        size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 2),
                    Text(isDemo ? _demoRating(b.id) : '—',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600)),
                    if (isDemo) ...[
                      const SizedBox(width: 8),
                      Text('• ${_demoVehicleNum(b.id)}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textMuted)),
                    ]
                  ]),
                ),

              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5)),

              // ── ACTION BUTTONS ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(children: [
                  if (isActive) ...[
                    Expanded(
                      child: _actionBtn(
                        label: 'Track',
                        icon: Icons.gps_fixed_rounded,
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _actionBtn(
                      label: 'Details',
                      icon: Icons.info_outline_rounded,
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                      onTap: () => _showDetails(context, b, isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn(
                      label: isActive ? 'Cancel' : 'Rebook',
                      icon: isActive ? Icons.cancel_outlined : Icons.refresh_rounded,
                      color: isActive ? AppColors.error : const Color(0xFF00D4AA),
                      isDark: isDark,
                      onTap: () async {
                        if (isActive) {
                          try {
                            await BookingService().cancelBooking(b.id);
                          } catch (e) {
                            debugPrint('Cancel error: $e');
                          }
                        } else {
                          _snack('Rebook feature coming soon!');
                        }
                      },
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ─────────────────────────────────────────────────
  // LOADING STATE
  // ─────────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, i) => Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2028)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
              const SizedBox(height: 12),
              Text('Fetching your bookings…',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────
  Widget _buildEmptyState(String tab, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No $tab bookings 🚛',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              tab == 'All'
                  ? 'Your trips will appear here\nonce you book a lorry'
                  : 'No $tab trips found.\nTry a different filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // ERROR STATE
  // ─────────────────────────────────────────────────
  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 44,
                  color: AppColors.error.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 20),
            Text('Something went wrong',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Please check your connection\nand try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.6)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Try Again',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4AA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(140, 46),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // FILTER BOTTOM SHEET
  // ─────────────────────────────────────────────────
  void _showFilterSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Filter Bookings',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            _filterRow(Icons.date_range_rounded, 'Date Range',
                'Select a date range', isDark),
            _filterRow(Icons.local_shipping_rounded, 'Truck Type',
                'All truck types', isDark),
            _filterRow(Icons.flag_rounded, 'Status',
                'All statuses', isDark),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _snack('Filter applied!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Apply Filter',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(
      IconData icon, String title, String subtitle, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // DETAILS BOTTOM SHEET
  // ─────────────────────────────────────────────────
  void _showDetails(BuildContext context, BookingModel b, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Trip Details',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  _statusBadge(b.status, _statusColor(b.status)),
                ]),
                const SizedBox(height: 20),
                _detailRow('Booking ID', '#${b.id.length > 10 ? b.id.substring(0, 10).toUpperCase() : b.id}'),
                _detailRow('Vehicle', b.vehicleName),
                _detailRow('Tier', b.tier),
                _detailRow('Pickup', b.pickupAddress),
                _detailRow('Drop', b.dropAddress),
                _detailRow('Distance', b.distance.isNotEmpty ? b.distance : '—'),
                _detailRow('Fare', '₹${b.totalFare.toInt()}'),
                _detailRow('Payment', b.paymentMethod),
                _detailRow('Goods', b.itemTypes.join(', ')),
                _detailRow('Date', _formatDate(b.createdAt)),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _snack('Rebook feature coming soon!');
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text('Rebook This Trip',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4AA),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'in transit':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'accepted':
        return const Color(0xFF10B981);
      default: // pending
        return const Color(0xFFF59E0B);
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'in transit':
        return Icons.local_shipping_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.pending_rounded;
    }
  }

  String _cityName(String addr) {
    if (addr.isEmpty) return 'Unknown';
    return addr.split(',').first.trim();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatAmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }

  // Realistic demo driver names keyed by booking id
  String _demoDriver(String id) {
    final drivers = ['Ramesh K.', 'Suresh M.', 'Ravi B.', 'Anand T.'];
    return drivers[id.hashCode.abs() % drivers.length];
  }

  String _demoRating(String id) {
    final ratings = ['4.8', '4.6', '4.9', '4.7'];
    return ratings[id.hashCode.abs() % ratings.length];
  }

  String _demoVehicleNum(String id) {
    final nums = ['KA-01-AB-1234', 'MH-12-CD-5678', 'TN-22-EF-9012', 'AP-09-GH-3456'];
    return nums[id.hashCode.abs() % nums.length];
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }
}
