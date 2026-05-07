import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';
import 'live_screen.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-build the entire scaffold whenever the theme toggles
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppColors.themeNotifier,
      builder: (context, _, __) {
        final isDark = AppColors.isDark;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Lazy PageView — tabs only init when first visited
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentIndex = i),
                children: [
                  HomeScreen(
                    onBookLorry: () {
                      setState(() => _currentIndex = 1);
                      _pageController.jumpToPage(1);
                    },
                  ),
                  LiveScreen(),
                  ActivityScreen(),
                  ProfileScreen(),
                ],
              ),

              // Floating Bottom Nav Bar
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232731) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(0, Icons.grid_view_rounded, 'Home', isDark),
                      _navItem(1, Icons.gps_fixed_rounded, 'Live', isDark),
                      _navItem(2, Icons.receipt_long_rounded, 'Bookings', isDark),
                      _navItem(3, Icons.settings_rounded, 'Settings', isDark),
                    ],
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

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.jumpToPage(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textMuted,
              size: 24,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
