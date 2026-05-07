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
  static Color background    = const Color(0xFF11131A);
  static Color surface       = const Color(0xFF1A1D24);
  static Color card          = const Color(0xFF1A1D24);
  static Color cardElevated  = const Color(0xFF232731);

  static Color textPrimary   = const Color(0xFFFFFFFF);
  static Color textSecondary = const Color(0xFF9CA3AF);
  static Color textMuted     = const Color(0xFF6B7280);

  static Color border        = const Color(0xFF2A2E39);
  static Color borderLight   = const Color(0xFF353945);

  static void _updateColors() {
    if (isDark) {
      // ── DARK ────────────────────────────────────────────
      background    = const Color(0xFF11131A);
      surface       = const Color(0xFF1A1D24);
      card          = const Color(0xFF1A1D24);
      cardElevated  = const Color(0xFF232731);

      textPrimary   = const Color(0xFFFFFFFF);
      textSecondary = const Color(0xFF9CA3AF);
      textMuted     = const Color(0xFF6B7280);

      border        = const Color(0xFF2A2E39);
      borderLight   = const Color(0xFF353945);
    } else {
      // ── LIGHT (Driver-app inspired palette) ─────────────
      // Warm off-white backgrounds — not stark white
      background    = const Color(0xFFF4F6F9);   // cool grey page bg
      surface       = const Color(0xFFFFFFFF);   // pure white cards/bars
      card          = const Color(0xFFFFFFFF);
      cardElevated  = const Color(0xFFF0F2F5);

      // Rich dark text — not flat black
      textPrimary   = const Color(0xFF1A1F2E);   // near-black navy
      textSecondary = const Color(0xFF4B5563);   // medium slate
      textMuted     = const Color(0xFF9CA3AF);   // light grey hint

      // Subtle borders
      border        = const Color(0xFFE2E8F0);   // slate-200
      borderLight   = const Color(0xFFCBD5E1);   // slate-300
    }
  }

  // ── Constant Brand Colors ────────────────────────────────
  static const primary       = Color(0xFF00D4AA);
  static const primaryDark   = Color(0xFF00B894);
  static const primaryLight  = Color(0xFF33DEBB);

  static const secondary     = Color(0xFF2563EB);
  static const secondaryDark = Color(0xFF1D4ED8);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);
}
