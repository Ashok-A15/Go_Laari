import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // To access themeNotifier
import 'role_selection_page.dart';
import 'profile_info_page.dart';
import 'change_password_page.dart';
import 'notification_settings_page.dart';
import 'help_center_page.dart';
import 'privacy_policy_page.dart';
import '../services/firestore_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    
    return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  "Settings",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [const Color(0xFF1E272E), const Color(0xFF0F171A)]
                        : [const Color(0xFF43CEA2), const Color(0xFF185A9D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                
                _buildAnimatedSection("Account", 0),
                _buildAnimatedTile(
                  Icons.person_outline_rounded,
                  "Profile Information",
                  () => _navigateTo(const ProfileInfoPage()),
                  1,
                ),
                _buildAnimatedTile(
                  Icons.lock_outline_rounded,
                  "Change Password",
                  () => _navigateTo(const ChangePasswordPage()),
                  2,
                ),
                _buildAnimatedTile(
                  Icons.notifications_none_rounded,
                  "Notifications",
                  () => _navigateTo(const NotificationSettingsPage()),
                  3,
                ),
                
                const SizedBox(height: 24),
                _buildAnimatedSection("App Settings", 4),
                _buildAnimatedTile(
                  Icons.dark_mode_outlined,
                  "Dark Mode",
                  () {},
                  5,
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: const Color(0xFF43CEA2),
                    onChanged: (v) {
                      setState(() {
                        themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                _buildAnimatedSection("Support", 6),
                _buildAnimatedTile(
                  Icons.help_outline_rounded,
                  "Help Center",
                  () => _navigateTo(const HelpCenterPage()),
                  7,
                ),
                _buildAnimatedTile(
                  Icons.policy_outlined,
                  "Privacy Policy",
                  () => _navigateTo(const PrivacyPolicyPage()),
                  8,
                ),
                
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _animationController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        ),
                        title: const Text(
                          "Log Out",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text("Sign out of your account session"),
                        onTap: () async {
                          FirestoreService().clearCache();
                          final navigator = Navigator.of(context);
                          await FirebaseAuth.instance.signOut();
                          if (!mounted) return;
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Center(
                  child: Text(
                    "Version 1.2.4 • GoLorry Owner",
                    style: TextStyle(color: Colors.grey, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ],
        ),
    );
  }


  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildAnimatedSection(String title, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double delay = (index * 0.1).clamp(0.0, 1.0);
        final double opacity = (_animationController.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTile(IconData icon, String title, VoidCallback onTap, int index, {Widget? trailing, String? subtitle}) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double delay = (index * 0.1).clamp(0.0, 1.0);
        final opacity = (_animationController.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - opacity)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF185A9D).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF185A9D), size: 22),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: subtitle != null ? Text(subtitle) : null,
            trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
