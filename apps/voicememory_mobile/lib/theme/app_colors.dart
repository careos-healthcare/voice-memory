import 'package:flutter/material.dart';

/// ArchiveMe consumer light palette — calm, premium, ambition-pressure tracking.
class AppColors {
  AppColors._();

  /// Page background — warm off-white.
  static const Color backgroundPrimary = Color(0xFFF8F6F1);

  /// Cards, sheets, nav bar.
  static const Color backgroundSecondary = Color(0xFFFFFFFF);

  /// Subtle grouped sections.
  static const Color surfaceAlt = Color(0xFFF3F0EA);

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);

  static const Color borderSubtle = Color(0xFFE5E0D8);

  /// Primary CTA / links.
  static const Color accentPrimary = Color(0xFF2563EB);

  /// Loop Mode / secondary emphasis.
  static const Color accentSecondary = Color(0xFF0F766E);

  /// Soft highlight fills (chips, selected states).
  static const Color accentLight = Color(0xFFEAF2FF);

  static const Color onAccent = Color(0xFFFFFFFF);

  static const Color warning = Color(0xFFB45309);
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFDC2626);

  static Color get shadowColor => const Color(0x0D172033);
}
