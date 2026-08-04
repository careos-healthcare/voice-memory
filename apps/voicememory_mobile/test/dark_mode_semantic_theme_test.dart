import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/theme/archive_semantic_colors.dart';
import 'package:voicememory_mobile/theme/system_overlay_style_resolver.dart';

/// Dark mode is treated as a correctness property, not a coat of paint. The
/// guard below is the part that keeps it true: a retained surface that reaches
/// for a light-only literal fails the build rather than the user's eyes.
void main() {
  group('semantic tokens', () {
    test('both themes publish the full V1 token set', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final tokens = theme.extension<ArchiveSemanticColors>();
        expect(
          tokens,
          isNotNull,
          reason: '${theme.brightness} theme must publish semantic colours',
        );
      }
    });

    test('dark tokens differ from light tokens on every surface role', () {
      final light = AppTheme.light().extension<ArchiveSemanticColors>()!;
      final dark = AppTheme.dark().extension<ArchiveSemanticColors>()!;

      expect(dark.background, isNot(light.background));
      expect(dark.surface, isNot(light.surface));
      expect(dark.elevatedSurface, isNot(light.elevatedSurface));
      expect(dark.primaryText, isNot(light.primaryText));
      expect(dark.secondaryText, isNot(light.secondaryText));
    });

    test('dark surfaces keep readable contrast', () {
      final dark = AppTheme.dark().extension<ArchiveSemanticColors>()!;

      expect(
        _contrast(dark.primaryText, dark.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(dark.secondaryText, dark.background),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrast(dark.evidenceQuote, dark.evidenceQuoteSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('Then and Now are distinguishable in both brightnesses', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final tokens = theme.extension<ArchiveSemanticColors>()!;
        expect(tokens.thenEvidence, isNot(tokens.nowEvidence));
      }
    });

    testWidgets('a widget resolves tokens from the active theme', (
      tester,
    ) async {
      late ArchiveSemanticColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              resolved = ArchiveSemanticColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        resolved.background,
        AppTheme.dark().extension<ArchiveSemanticColors>()!.background,
      );
    });

    testWidgets('an unthemed context still resolves rather than crashing', (
      tester,
    ) async {
      late ArchiveSemanticColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              resolved = ArchiveSemanticColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved.background, isNotNull);
    });
  });

  group('system overlays', () {
    test('the launch overlay follows platform brightness', () {
      final light = SystemOverlayStyleResolver.forBrightness(Brightness.light);
      final dark = SystemOverlayStyleResolver.forBrightness(Brightness.dark);

      expect(
        light.systemNavigationBarColor,
        isNot(dark.systemNavigationBarColor),
      );
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      expect(light.systemNavigationBarIconBrightness, Brightness.dark);
      expect(
        dark.systemNavigationBarColor,
        AppTheme.dark().scaffoldBackgroundColor,
      );
    });

    test('the app bar overlay follows the theme brightness', () {
      final darkOverlay = AppTheme.dark().appBarTheme.systemOverlayStyle;
      final lightOverlay = AppTheme.light().appBarTheme.systemOverlayStyle;

      expect(darkOverlay?.systemNavigationBarIconBrightness, Brightness.light);
      expect(lightOverlay?.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });

  group('dialogs, sheets and fields use the active theme', () {
    test('dark surfaces are not light literals', () {
      final dark = AppTheme.dark();
      final light = AppTheme.light();

      expect(
        dark.dialogTheme.backgroundColor,
        isNot(light.dialogTheme.backgroundColor),
      );
      expect(
        dark.bottomSheetTheme.backgroundColor,
        isNot(light.bottomSheetTheme.backgroundColor),
      );
      expect(
        dark.inputDecorationTheme.fillColor,
        isNot(light.inputDecorationTheme.fillColor),
      );
      expect(dark.navigationBarTheme.backgroundColor, isNotNull);
    });
  });

  group('architecture guard', () {
    test('retained surfaces do not hard-code light-only colours', () {
      final offenders = <String>[];
      for (final path in _retainedSurfacePaths()) {
        final source = File(path).readAsStringSync();
        for (final entry in source.split('\n').asMap().entries) {
          final line = entry.value;
          if (_isExempt(line)) continue;
          if (_lightOnlyReference.hasMatch(line)) {
            offenders.add(
              '${_relative(path)}:${entry.key + 1} '
              '${line.trim()}',
            );
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Retained screens and widgets must name a semantic role via '
            'ArchiveSemanticColors or Theme.of(context), not a light-only '
            'literal:\n${offenders.join('\n')}',
      );
    });

    test('the guard actually inspects the retained surfaces', () {
      // A guard that silently scans nothing is worse than no guard.
      expect(_retainedSurfacePaths().length, greaterThan(20));
    });
  });
}

/// Screens and widgets that ship in V1. Theme definitions are excluded — they
/// are where literal colours are supposed to live.
List<String> _retainedSurfacePaths() {
  final roots = [Directory('lib/screens'), Directory('lib/widgets')];
  final paths = <String>[];
  for (final root in roots) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      paths.add(entity.path);
    }
  }
  paths.sort();
  return paths;
}

String _relative(String path) => path.replaceFirst(RegExp(r'^.*?lib/'), 'lib/');

/// `AppColors` and `VoiceMemoryColors` are the light-only palettes. A raw ARGB
/// literal is equally opaque to the theme system.
final RegExp _lightOnlyReference = RegExp(
  r'\b(?:AppColors|VoiceMemoryColors)\.|'
  r'\bColor\(0x[0-9a-fA-F]{8}\)',
);

/// Narrow exemptions: brand assets and comments only.
bool _isExempt(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//') || trimmed.startsWith('///')) return true;
  if (trimmed.startsWith('import ')) return true;
  return line.contains('brand-asset-exempt');
}

/// WCAG relative-luminance contrast ratio.
double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground) + 0.05;
  final b = _luminance(background) + 0.05;
  return a > b ? a / b : b / a;
}

double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : pow((value + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
