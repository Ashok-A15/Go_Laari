import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _selectedCategory = 0;

  final _categories = ['All', 'Booking', 'Payments', 'Tracking', 'Drivers'];

  final _faqs = [
    _FAQ('Booking Issues', 'How do I book a truck?',
        'Go to the Live tab → tap "Book a Lorry" → enter pickup & drop → select vehicle → confirm.'),
    _FAQ('Booking Issues', 'Can I cancel a booking?',
        'Yes, you can cancel before the driver accepts. Open the Bookings tab → select trip → Cancel.'),
    _FAQ('Payments', 'What payment methods are accepted?',
        'We accept UPI, Net Banking, Debit/Credit cards, and Cash on Delivery.'),
    _FAQ('Payments', 'When will I get my invoice?',
        'Invoices are sent to your email within 30 minutes of trip completion.'),
    _FAQ('Tracking', 'How do I track my shipment?',
        'Open the Live tab after booking. You will see real-time location of your truck.'),
    _FAQ('Tracking', 'Why is my tracking not updating?',
        'Ensure the driver has GPS enabled. Contact support if the issue persists.'),
    _FAQ('Drivers', 'How are drivers verified?',
        'All GoLorry drivers are background checked, licensed, and vehicle-inspected.'),
    _FAQ('Drivers', 'What if my driver does not arrive?',
        'After 10 mins past ETA, use the Help button to contact support or request a replacement.'),
  ];

  List<_FAQ> get _filtered {
    final cat = _categories[_selectedCategory];
    return _faqs.where((f) {
      final matchCat = cat == 'All' || f.category == cat;
      final matchQ = _query.isEmpty ||
          f.question.toLowerCase().contains(_query.toLowerCase()) ||
          f.answer.toLowerCase().contains(_query.toLowerCase());
      return matchCat && matchQ;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Help Center',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: _buildFAB(context),
      body: Column(
        children: [
          // ── Search ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2028) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search help articles...',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          })
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF00D4AA), width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // ── Category Chips ────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final active = _selectedCategory == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF00D4AA)
                          : (isDark
                              ? const Color(0xFF1E2028)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? const Color(0xFF00D4AA)
                              : AppColors.border),
                    ),
                    child: Text(_categories[i],
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textPrimary)),
                  ),
                );
              },
            ),
          ),

          // ── FAQs ──────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off_rounded,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No results found',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text('Try different keywords',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted)),
                  ]))
                : ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _filtered.length) {
                        return _buildSupportOptions(isDark);
                      }
                      return _faqCard(_filtered[i], isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _faqCard(_FAQ faq, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.help_outline_rounded,
                size: 16, color: Color(0xFF00D4AA)),
          ),
          title: Text(faq.question,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          children: [
            Text(faq.answer,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOptions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Contact Support',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _supportBtn(Icons.phone_rounded, 'Call', const Color(0xFF10B981), isDark)),
          const SizedBox(width: 10),
          Expanded(child: _supportBtn(Icons.chat_bubble_outline_rounded, 'Chat', const Color(0xFF3B82F6), isDark)),
          const SizedBox(width: 10),
          Expanded(child: _supportBtn(Icons.email_outlined, 'Email', const Color(0xFF8B5CF6), isDark)),
        ]),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _supportBtn(IconData icon, String label, Color color, bool isDark) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2028) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFF00D4AA),
        icon: const Icon(Icons.support_agent_rounded, color: Colors.white),
        label: Text('Live Chat',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: Colors.white)),
        elevation: 6,
      ),
    );
  }
}

class _FAQ {
  final String category;
  final String question;
  final String answer;
  const _FAQ(this.category, this.question, this.answer);
}
