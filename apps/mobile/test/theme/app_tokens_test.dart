import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:archiveme_mobile/theme/archive_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary, neutral, and 4px spacing match the Tailwind scales', () {
    expect(AppTokens.primary600, const Color(0xFF2563EB));
    expect(AppTokens.primary600, AppColors.accentPrimary);
    expect(AppTokens.primary700, ArchiveDesignTokens.accentHover);
    expect(AppTokens.primary50, const Color(0xFFEFF6FF));
    expect(AppTokens.primary900, const Color(0xFF1E3A8A));

    expect(AppTokens.neutral50, const Color(0xFFFAFAFA));
    expect(AppTokens.neutral500, const Color(0xFF737373));
    expect(AppTokens.neutral900, const Color(0xFF171717));

    expect(AppTokens.spacing1, 4);
    expect(AppTokens.spacing2, 8);
    expect(AppTokens.spacing2, ArchiveDesignTokens.spaceXs);
    expect(AppTokens.spacing4, ArchiveDesignTokens.spaceSm);
    expect(AppTokens.spacing6, ArchiveDesignTokens.spaceMd);
    expect(AppTokens.spacing8, ArchiveDesignTokens.spaceLg);
    expect(AppTokens.spacing11, ArchiveDesignTokens.spaceTouch);
    expect(AppTokens.spacing12, ArchiveDesignTokens.spaceXl);
    expect(AppTokens.spacing14, ArchiveDesignTokens.spaceButton);
  });

  test('AppTheme uses the shared type hierarchy and brand primary', () {
    final theme = AppTheme.light();
    expect(theme.colorScheme.primary, AppTokens.primary600);
    expect(theme.textTheme.headlineLarge?.fontSize, 32);
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.headlineLarge?.height, 1.35);
    expect(theme.textTheme.headlineLarge?.letterSpacing, -0.4);
    expect(theme.textTheme.titleLarge?.fontSize, 22);
    expect(theme.textTheme.titleMedium?.fontSize, 18);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(AppTokens.writing().fontSize, 17);
    expect(AppTokens.writing().height, 1.7);
  });
}
