import 'package:flutter/material.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help Center"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "How can we help you?",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: "Search for topics or questions",
                prefixIcon: const Icon(Icons.search_rounded),
                fillColor: isDark ? const Color(0xFF1E272E) : Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 40),
            const Text("Top Categories", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildCategoryCard(Icons.local_shipping_rounded, "Fleet Management"),
                _buildCategoryCard(Icons.account_balance_wallet_rounded, "Payments & Fees"),
                _buildCategoryCard(Icons.security_rounded, "Security"),
                _buildCategoryCard(Icons.support_agent_rounded, "Contact Support"),
              ],
            ),
            const SizedBox(height: 40),
            const Text("Frequently Asked Questions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _buildFAQTile("How to add a new driver?"),
            _buildFAQTile("What are the platform charges?"),
            _buildFAQTile("How to track live earnings?"),
            _buildFAQTile("Can I manage multiple fleets?"),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(IconData icon, String title) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF185A9D), size: 30),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF43CEA2)),
        onTap: () {},
      ),
    );
  }
}
