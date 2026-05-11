import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'bookings_page.dart';
import 'earnings_page.dart';
import 'settings_page.dart';

class DriverMainPage extends StatefulWidget {
  const DriverMainPage({super.key});

  @override
  State<DriverMainPage> createState() => _DriverMainPageState();
}

class _DriverMainPageState extends State<DriverMainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    BookingsPage(),
    EarningsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(20),
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.dashboard_rounded, "Home"),
              _buildNavItem(1, Icons.history_rounded, "History"),
              _buildNavItem(2, Icons.account_balance_wallet_rounded, "Earnings"),
              _buildNavItem(3, Icons.settings_rounded, "Settings"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF43CEA2).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF43CEA2) : Colors.grey,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF185A9D),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
