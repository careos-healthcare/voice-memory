import 'dart:io';

import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArchiveMe light theme', () {
    test('app entry follows system theme mode with light and dark themes', () {
      final app = File('lib/app.dart').readAsStringSync();
      expect(app, contains('ThemeMode.system'));
      expect(app, contains('AppTheme.light()'));
      expect(app, contains('AppTheme.dark()'));
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

    test('dark() provides a dark color scheme', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor.computeLuminance(), lessThan(0.2));
    });
  });
}