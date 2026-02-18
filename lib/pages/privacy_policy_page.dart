import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
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
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Privacy Policy for GoLorry",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Last Updated: January 2026",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 30),
            _buildPolicySection(
              "1. Information We Collect",
              "We collect information you provide directly to us when you create or modify your account, request services, contact customer support, or otherwise communicate with us. This information may include: name, email, phone number, postal address, profile picture, payment method, and other information you choose to provide.",
            ),
            _buildPolicySection(
              "2. Use of Information",
              "We use the information we collect to provide, maintain, and improve our Services, such as to facilitate payments, send receipts, provide products and services you request, and develop new features.",
            ),
            _buildPolicySection(
              "3. Sharing of Information",
              "We may share the information we collect about you as described in this Statement or as described at the time of collection or sharing, including: with vendors, consultants, marketing partners, and other service providers who need access to such information to carry out work on our behalf.",
            ),
            _buildPolicySection(
              "4. Security",
              "We are committed to protecting your personal information. We use appropriate technical and organizational measures to protect your personal information against unauthorized access, use, disclosure, alteration, or destruction.",
            ),
            const SizedBox(height: 50),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("I Understand"),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column( 
        crossAxisAlignment: CrossAxisAlignment.start,
         children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF185A9D))),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.grey)),
        ],
      ),
    );
  }
}
    