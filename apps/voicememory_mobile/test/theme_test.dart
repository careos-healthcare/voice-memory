import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/theme_system/theme_engine.dart';
import 'package:voicememory_mobile/features/theme_system/theme_models.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  group('ArchiveMe themes', () {
    // Asserts the behaviour rather than grepping app.dart for a literal. The
    // mode is now resolved by themeModeFor, so a source scan reported a
    // regression while the app was in fact honouring the system setting.
    test('app entry follows the system theme mode', () {
      expect(themeModeFor(ThemeArchetype.dynamicSystem), ThemeMode.system);

      final app = File('lib/app.dart').readAsStringSync();
      expect(app, contains('themeModeFor('));
      expect(app, contains('AppTheme.fromTokens(lightTokens)'));
      expect(app, contains('AppTheme.fromTokens(darkTokens)'));
    });

    test('default theme brightness is light', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('scaffold background is warm light not black', () {
      final theme = AppTheme.light();
      final bg = theme.scaffoldBackgroundColor;
      expect(bg, AppColors.backgroundPrimary);
      expect(bg.computeLuminance(), greaterThan(0.85));
      expect(bg, isNot(Colors.black));
    });

    test('primary accent is ArchiveMe blue', () {
      expect(AppColors.accentPrimary, const Color(0xFF2563EB));
      expect(AppTheme.light().colorScheme.primary, AppColors.accentPrimary);
    });

    test('secondary loop accent is teal', () {
      expect(AppColors.accentSecondary, const Color(0xFF0F766E));
      expect(AppTheme.light().colorScheme.secondary, AppColors.accentSecondary);
    });

    test('surface cards are white on warm background', () {
      expect(AppColors.backgroundSecondary, const Color(0xFFFFFFFF));
      expect(
        AppTheme.light().colorScheme.surface,
        AppColors.backgroundSecondary,
      );
    });

    test('text contrast remains readable on light surfaces', () {
      final bgLuminance = AppColors.backgroundPrimary.computeLuminance();
      final textLuminance = AppColors.textPrimary.computeLuminance();
      expect(textLuminance, lessThan(bgLuminance));
      expect(AppColors.textSecondary.computeLuminance(), lessThan(bgLuminance));
    });

    test('dark theme uses dark color scheme', () {
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
    });
  });
}
