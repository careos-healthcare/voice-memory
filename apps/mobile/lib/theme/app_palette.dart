import 'package:flutter/material.dart';

/// Light and dark values for every consumer colour token.
///
/// Widgets read [AppPaletteContext.palette] so a dark theme does not paint
/// the light [AppColors] hex values.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.accentPrimary,
    required this.accentLight,
    required this.warmSurface,
    required this.warmBorder,
    required this.lockedSurface,
    required this.lockedText,
    required this.lockedIcon,
    required this.proofConfidenceLow,
    required this.proofConfidenceMedium,
    required this.proofConfidenceHigh,
    required this.error,
    required this.success,
    required this.warning,
  });

  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color accentPrimary;
  final Color accentLight;
  final Color warmSurface;
  final Color warmBorder;
  final Color lockedSurface;
  final Color lockedText;
  final Color lockedIcon;
  final Color proofConfidenceLow;
  final Color proofConfidenceMedium;
  final Color proofConfidenceHigh;
  final Color error;
  final Color success;
  final Color warning;

  static const light = AppPalette(
    backgroundPrimary: Color(0xFFF8F6F1),
    backgroundSecondary: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F0EA),
    textPrimary: Color(0xFF172033),
    textSecondary: Color(0xFF667085),
    textMuted: Color(0xFF4B5568),
    borderSubtle: Color(0xFFE5E0D8),
    accentPrimary: Color(0xFF2563EB),
    accentLight: Color(0xFFEAF2FF),
    warmSurface: Color(0xFFFFFBF5),
    warmBorder: Color(0xFFF5E6D3),
    lockedSurface: Color(0xFFEDEBE4),
    lockedText: Color(0xFF3F4757),
    lockedIcon: Color(0xFF5B6478),
    proofConfidenceLow: Color(0xFF9A6A00),
    proofConfidenceMedium: Color(0xFF2563EB),
    proofConfidenceHigh: Color(0xFF15803D),
    error: Color(0xFFDC2626),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
  );

  static const dark = AppPalette(
    backgroundPrimary: Color(0xFF0F1419),
    backgroundSecondary: Color(0xFF1A2234),
    surfaceAlt: Color(0xFF232D3F),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFFD1D5DB),
    borderSubtle: Color(0xFF2D3748),
    accentPrimary: Color(0xFF3B82F6),
    accentLight: Color(0xFF1E3A5F),
    warmSurface: Color(0xFF2A241C),
    warmBorder: Color(0xFF4A3F32),
    lockedSurface: Color(0xFF2C3340),
    lockedText: Color(0xFFD1D5DB),
    lockedIcon: Color(0xFF9CA3AF),
    proofConfidenceLow: Color(0xFFFBBF24),
    proofConfidenceMedium: Color(0xFF60A5FA),
    proofConfidenceHigh: Color(0xFF4ADE80),
    error: Color(0xFFF87171),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
  );

  @override
  AppPalette copyWith({
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
    Color? accentPrimary,
    Color? accentLight,
    Color? warmSurface,
    Color? warmBorder,
    Color? lockedSurface,
    Color? lockedText,
    Color? lockedIcon,
    Color? proofConfidenceLow,
    Color? proofConfidenceMedium,
    Color? proofConfidenceHigh,
    Color? error,
    Color? success,
    Color? warning,
  }) {
    return AppPalette(
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentLight: accentLight ?? this.accentLight,
      warmSurface: warmSurface ?? this.warmSurface,
      warmBorder: warmBorder ?? this.warmBorder,
      lockedSurface: lockedSurface ?? this.lockedSurface,
      lockedText: lockedText ?? this.lockedText,
      lockedIcon: lockedIcon ?? this.lockedIcon,
      proofConfidenceLow: proofConfidenceLow ?? this.proofConfidenceLow,
      proofConfidenceMedium:
          proofConfidenceMedium ?? this.proofConfidenceMedium,
      proofConfidenceHigh: proofConfidenceHigh ?? this.proofConfidenceHigh,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      backgroundPrimary: Color.lerp(
        backgroundPrimary,
        other.backgroundPrimary,
        t,
      )!,
      backgroundSecondary: Color.lerp(
        backgroundSecondary,
        other.backgroundSecondary,
        t,
      )!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      warmSurface: Color.lerp(warmSurface, other.warmSurface, t)!,
      warmBorder: Color.lerp(warmBorder, other.warmBorder, t)!,
      lockedSurface: Color.lerp(lockedSurface, other.lockedSurface, t)!,
      lockedText: Color.lerp(lockedText, other.lockedText, t)!,
      lockedIcon: Color.lerp(lockedIcon, other.lockedIcon, t)!,
      proofConfidenceLow: Color.lerp(
        proofConfidenceLow,
        other.proofConfidenceLow,
        t,
      )!,
      proofConfidenceMedium: Color.lerp(
        proofConfidenceMedium,
        other.proofConfidenceMedium,
        t,
      )!,
      proofConfidenceHigh: Color.lerp(
        proofConfidenceHigh,
        other.proofConfidenceHigh,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Compile-time gate. Dark mode stays off until V1 screens read [AppPalette].
const bool thoughtprintDarkModeReady = bool.fromEnvironment(
  'THOUGHTPRINT_DARK_MODE_READY',
  defaultValue: false,
);
