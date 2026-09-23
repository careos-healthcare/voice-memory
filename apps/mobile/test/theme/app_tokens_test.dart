import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary, neutral, and 4px spacing match the Tailwind scales', () {
    expect(AppTokens.primary600, const Color(0xFF2563EB));
    expect(AppTokens.primary700, const Color(0xFF1D4ED8));
    expect(AppTokens.primary600, AppColors.accentPrimary);
    expect(AppTokens.primary700, ArchiveDesignTokens.accentHover);
    expect(AppTokens.neutral50, const Color(0xFFFAFAFA));
    expect(AppTokens.neutral900, const Color(0xFF171717));

    const primary = <int, Color>{
      50: AppTokens.primary50,
      100: AppTokens.primary100,
      200: AppTokens.primary200,
      300: AppTokens.primary300,
      400: AppTokens.primary400,
      500: AppTokens.primary500,
      600: AppTokens.primary600,
      700: AppTokens.primary700,
      800: AppTokens.primary800,
      900: AppTokens.primary900,
    };
    final neutral = <int, Color>{
      50: AppTokens.neutral50,
      100: AppTokens.neutral100,
      200: AppTokens.neutral200,
      300: AppTokens.neutral300,
      400: AppTokens.neutral400,
      500: AppTokens.neutral500,
      600: AppTokens.neutral600,
      700: AppTokens.neutral700,
      800: AppTokens.neutral800,
      900: AppTokens.neutral900,
    };
    expect(primary.keys, [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]);
    expect(neutral.keys, primary.keys);
    expect(neutral[50], const Color(0xFFFAFAFA));
    expect(neutral[900], const Color(0xFF171717));

    final spacing = <int, double>{
      1: AppTokens.spacing1,
      2: AppTokens.spacing2,
      3: AppTokens.spacing3,
      4: AppTokens.spacing4,
      5: AppTokens.spacing5,
      6: AppTokens.spacing6,
      7: AppTokens.spacing7,
      8: AppTokens.spacing8,
      9: AppTokens.spacing9,
      10: AppTokens.spacing10,
      11: AppTokens.spacing11,
      12: AppTokens.spacing12,
      13: AppTokens.spacing13,
      14: AppTokens.spacing14,
      15: AppTokens.spacing15,
      16: AppTokens.spacing16,
    };
    for (final step in spacing.keys) {
      expect(spacing[step], step * 4.0);
    }
    expect(AppTokens.spacing4, 16);
    expect(AppTokens.spacing12, 48);
  });

  test('AppTheme.light uses the warm page background and shared type scale', () {
    final theme = AppTheme.light();
    const page = Color(0xFFF8F6F1);
    expect(theme.scaffoldBackgroundColor, page);
    expect(theme.canvasColor, page);
    expect(AppTheme.background, page);
    expect(theme.colorScheme.primary, const Color(0xFF2563EB));

    expect(theme.textTheme.headlineLarge?.fontSize, 32);
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.headlineLarge?.height, 1.35);
    expect(theme.textTheme.headlineLarge?.letterSpacing, -0.4);
    expect(theme.textTheme.titleLarge?.fontSize, 22);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.titleMedium?.fontSize, 18);
    expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyLarge?.fontWeight, FontWeight.w400);
    expect(theme.textTheme.bodySmall?.fontSize, 14);
    expect(theme.textTheme.bodySmall?.fontWeight, FontWeight.w400);
    expect(theme.textTheme.bodyMedium?.fontSize, 17);
    expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
    expect(theme.textTheme.bodyMedium?.height, 1.7);
    expect(theme.textTheme.bodyMedium?.letterSpacing, 0.15);
  });
}
