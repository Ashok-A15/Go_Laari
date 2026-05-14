import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:golorry_customer_app/utils/app_colors.dart';
import 'package:golorry_customer_app/screens/home_screen.dart';
import 'package:golorry_customer_app/screens/live_screen.dart';
import 'package:golorry_customer_app/screens/chatbot_screen.dart';
import 'package:golorry_customer_app/screens/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static final ValueNotifier<int> tabNotifier = ValueNotifier(0);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    DashboardScreen.tabNotifier.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() => _currentIndex = DashboardScreen.tabNotifier.value);
      _pageController.jumpToPage(DashboardScreen.tabNotifier.value);
    }
  }

  @override
  void dispose() {
    DashboardScreen.tabNotifier.removeListener(_onTabChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppColors.themeNotifier,
      builder: (context, _, __) {
        final isDark = AppColors.isDark;
        final navBgColor = isDark ? const Color(0xFF132548).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9);

        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        return Scaffold(
          resizeToAvoidBottomInset: false, // Map should not resize
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentIndex = i),
                children: const [
                  HomeScreen(),
                  LiveScreen(),
                  ProfileScreen(),
                  ChatbotScreen(),
                ],
              ),

              // ── PREMIUM FLOATING DOCK ────────────────────
              if (!isKeyboardOpen)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: navBgColor,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _navItem(0, Icons.grid_view_rounded, 'Home', isDark),
                            _navItem(1, Icons.local_shipping_rounded, 'Orders', isDark),
                            _navItem(2, Icons.person_outline_rounded, 'Profile', isDark),
                            _navItem(3, Icons.auto_awesome_rounded, 'AI Assistant', isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isDark) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFF2DD4BF) : AppColors.textMuted;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.jumpToPage(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: isActive ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
