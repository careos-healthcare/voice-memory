import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Internal design tokens — delegates to [AppColors] for consumer surfaces.
class VoiceMemoryColors {
  VoiceMemoryColors._();

  static const Color primaryIndigo = AppColors.accentPrimary;
  static const Color primaryIndigoHover = Color(0xFF1D4ED8);
  static const Color secondaryLavender = AppColors.accentSecondary;

  static const Color background = AppColors.backgroundPrimary;
  static const Color surface = AppColors.backgroundSecondary;
  static const Color surfaceSecondary = AppColors.accentLight;

  static const Color onPrimary = AppColors.onAccent;

  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = Color(0xFF98A2B3);

  static const Color border = AppColors.borderSubtle;

  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.error;

  static const Color discoveryGold = AppColors.warning;
  static const Color discoveryGoldBackground = Color(0xFFFFF7ED);
  static const Color discoveryGoldBorder = AppColors.warning;

  static const Color beliefIndigo = AppColors.accentPrimary;
  static const Color beliefIndigoLight = Color(0xFF3B82F6);
  static const Color themeLavender = AppColors.accentSecondary;
  static const Color chapterBlue = Color(0xFF60A5FA);
  static const Color contradictionRose = Color(0xFFE8A0A8);
  static const Color blindSpotAmber = Color(0xFFF59E0B);
  static const Color beliefChangeGold = AppColors.warning;

  static const Color captureSuccess = AppColors.success;

  static const LinearGradient beliefGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentPrimary, beliefIndigoLight],
  );

  static const LinearGradient progressHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accentPrimary, Color(0xFF1E40AF)],
  );
}