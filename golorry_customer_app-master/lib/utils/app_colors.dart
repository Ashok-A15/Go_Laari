import 'package:flutter/material.dart';

class AppColors {
  // ── Theme State ──────────────────────────────────────────
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

  static bool get isDark => themeNotifier.value == ThemeMode.dark;

  static void toggleTheme() {
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    _updateColors();
  }

  // Call once at startup so light-mode colors are correct from the first frame
  static void init() => _updateColors();

  // ── Mutable Semantic Colors ──────────────────────────────
  // DARK defaults (initialised here, overwritten by _updateColors on light)
  static Color background    = const Color(0xFF081120);
  static Color surface       = const Color(0xFF0F172A);
  static Color card          = const Color(0xFF0F172A);
  static Color cardElevated  = const Color(0xFF161F2E);

  static Color textPrimary   = const Color(0xFFFFFFFF);
  static Color textSecondary = const Color(0xFF9CA3AF);
  static Color textMuted     = const Color(0xFF6B7280);

  static Color border        = const Color(0xFF1E293B);
  static Color borderLight   = const Color(0xFF2D3748);

  static void _updateColors() {
    if (isDark) {
      // ── DARK ────────────────────────────────────────────
      background    = const Color(0xFF081120);
      surface       = const Color(0xFF0F172A);
      card          = const Color(0xFF0F172A);
      cardElevated  = const Color(0xFF161F2E);

      textPrimary   = const Color(0xFFFFFFFF);
      textSecondary = const Color(0xFF9CA3AF);
      textMuted     = const Color(0xFF6B7280);

      border        = const Color(0xFF1E293B);
      borderLight   = const Color(0xFF2D3748);
    } else {
      // ── LIGHT (Teal Brand Theme) ─────────────
      background    = const Color(0xFFF8FAFC);   // Light gray background
      surface       = const Color(0xFFFFFFFF);   // White for cards
      card          = const Color(0xFFFFFFFF);
      cardElevated  = const Color(0xFFF1F5F9);

      textPrimary   = const Color(0xFF0F172A);   // Dark Slate-900
      textSecondary = const Color(0xFF475569);   // Slate-600
      textMuted     = const Color(0xFF94A3B8);   // Slate-400

      border        = const Color(0xFFE2E8F0);   // Slate-200
      borderLight   = const Color(0xFFF1F5F9);   // Slate-100
    }
  }

  // ── Constant Brand Colors ────────────────────────────────
  static const primary       = Color(0xFF2DD4BF); // Vibrant Teal from images
  static const authBackground = Color(0xFF2DD4BF); // The Teal bg
  static const primaryDark   = Color(0xFF1D4ED8); // The Deep Blue
  static const primaryLight  = Color(0xFF33DEBB); // Light Teal

  static const secondary     = Color(0xFF2563EB); // Vibrant Blue
  static const secondaryDark = Color(0xFF1D4ED8); // Deep Navy

  static const gradientStart = Color(0xFF33DEBB);
  static const gradientEnd   = Color(0xFF1D4ED8);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);
}
