import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _smsEnabled = true;
  bool _marketingEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Settings"),
        flexibleSpace: Container(
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
        foregroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionHeader("Alert Types"),
            _buildSwitchTile("Push Notifications", "Receive real-time updates on your phone", _pushEnabled, (v) => setState(() => _pushEnabled = v)),
            _buildSwitchTile("Email Alerts", "Get monthly summaries and receipts via email", _emailEnabled, (v) => setState(() => _emailEnabled = v)),
            _buildSwitchTile("SMS Notifications", "Critical alerts via text message", _smsEnabled, (v) => setState(() => _smsEnabled = v)),
            
            const SizedBox(height: 30),
            _buildSectionHeader("Marketing"),
            _buildSwitchTile("Promotions", "Exclusive offers and platform news", _marketingEnabled, (v) => setState(() => _marketingEnabled = v)),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Last updated: Today, 10:45 AM",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF185A9D), letterSpacing: 1.1, fontSize: 13),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF43CEA2),
      ),
    );
  }
}
