import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    _PolicySection(
      icon: Icons.info_outline_rounded,
      title: 'Information We Collect',
      color: Color(0xFF6366F1),
      points: [
        'Name, email, and phone number during registration',
        'GPS location data while using the booking service',
        'Payment details (processed securely via third-party providers)',
        'Device information and app usage analytics',
      ],
    ),
    _PolicySection(
      icon: Icons.share_outlined,
      title: 'How We Use Your Information',
      color: Color(0xFF3B82F6),
      points: [
        'To match you with available lorry drivers',
        'To process bookings and payments',
        'To send booking updates and notifications',
        'To improve our services and app experience',
      ],
    ),
    _PolicySection(
      icon: Icons.people_outline_rounded,
      title: 'Information Sharing',
      color: Color(0xFF10B981),
      points: [
        'We share location with assigned drivers for trip completion',
        'Payment processors receive billing details (not stored by us)',
        'We do not sell your personal data to third parties',
        'Legal disclosures may occur if required by law',
      ],
    ),
    _PolicySection(
      icon: Icons.security_rounded,
      title: 'Data Security',
      color: Color(0xFFF59E0B),
      points: [
        'All data is encrypted in transit using HTTPS/TLS',
        'Firebase Authentication secures your login credentials',
        'Firestore security rules restrict unauthorized access',
        'We conduct regular security audits',
      ],
    ),
    _PolicySection(
      icon: Icons.person_outline_rounded,
      title: 'Your Rights',
      color: Color(0xFFEC4899),
      points: [
        'Request access to your personal data anytime',
        'Update your profile information in Account Settings',
        'Request deletion of your account and associated data',
        'Opt out of promotional communications',
      ],
    ),
    _PolicySection(
      icon: Icons.cookie_outlined,
      title: 'Cookies & Tracking',
      color: Color(0xFF06B6D4),
      points: [
        'We use analytics to understand app usage patterns',
        'No advertising cookies are used',
        'You can clear app data at any time through device settings',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Privacy Policy',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Last Updated Badge ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.update_rounded,
                    size: 16, color: Color(0xFF00D4AA)),
                const SizedBox(width: 8),
                Text('Last Updated: March 2026',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00D4AA))),
                const Spacer(),
                Text('v2.0',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Intro ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2028) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Text(
              'GoLorry ("we", "our", "us") is committed to protecting your privacy. '
              'This policy explains how we collect, use, and safeguard your information '
              'when you use our truck booking platform.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.7),
            ),
          ),

          const SizedBox(height: 16),

          // ── Policy Sections ───────────────────────────
          ..._sections.map((s) => _buildSectionCard(s, isDark)),

          const SizedBox(height: 16),

          // ── Contact ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2028) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.contact_mail_outlined,
                      size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text('Contact Us',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 10),
                Text(
                  'For privacy concerns, contact us at:\nprivacy@golorry.in',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionCard(_PolicySection s, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2028) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(s.icon, size: 18, color: s.color),
              ),
              const SizedBox(width: 12),
              Text(s.title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
            const SizedBox(height: 14),
            ...s.points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: s.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> points;
  const _PolicySection(
      {required this.icon,
      required this.title,
      required this.color,
      required this.points});
}
