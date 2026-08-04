import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/recording_feature_source.dart';

/// Scans live consumer UI layers for forbidden dark backgrounds.
void main() {
  const scanRoots = [
    'lib/screens',
    'lib/widgets',
    'lib/router',
    'lib/widgets/main_shell.dart',
    'lib/app.dart',
  ];

  const forbiddenPatterns = [
    'Colors.black',
    'Color(0xFF000000)',
    'Color(0xFF0F1117)',
    '#0F1117',
    'backgroundColor: Colors.black',
    'backgroundColor: Color(0xFF',
    'scaffoldBackgroundColor: Color(0xFF',
  ];

  const allowedPathFragments = [
    'archive_discovery_share_palette.dart',
    'share_palette',
    '/test/',
    'app_theme.dart',
  ];

  test('consumer screens and widgets avoid forbidden black backgrounds', () {
    final violations = <String>[];

    for (final root in scanRoots) {
      final file = File(root);
      if (file.existsSync() && root.endsWith('.dart')) {
        _scanFile(root, forbiddenPatterns, allowedPathFragments, violations);
        continue;
      }
      _scanDir(
        Directory(root),
        forbiddenPatterns,
        allowedPathFragments,
        violations,
      );
    }

    expect(
      violations,
      isEmpty,
      reason: 'Forbidden dark surfaces:\n${violations.join('\n')}',
    );
  });

  test('app maps light and dark themes to the system preference', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('AppTheme.fromTokens(lightTokens)'));
    expect(app, contains('AppTheme.fromTokens(darkTokens)'));
    expect(app, contains('themeModeFor(preferences.archetype)'));
  });

  // This used to require each consumer screen to name a light background
  // token. That is the thing that breaks dark mode: a screen pinned to a light
  // surface stays light while the rest of the app follows the system, which is
  // unreadable rather than merely inconsistent.
  //
  // The rule that actually holds in both themes is that a consumer screen
  // states no background of its own and takes the scaffold colour from the
  // theme. Hardcoded dark is already refused by the scan above; this refuses
  // hardcoded light, so neither theme can be pinned.
  test('consumer screens take their background from the theme', () {
    const lightLiterals = [
      'AppColors.backgroundPrimary',
      'Colors.white',
      'Color(0xFFFFFFFF)',
    ];

    final violations = <String>[];
    for (final path in [
      'lib/screens/record_screen.dart',
      'lib/screens/belief_changes_screen.dart',
      'lib/screens/v1_settings_screen.dart',
      'lib/screens/paywall_screen.dart',
      'lib/screens/export_screen.dart',
    ]) {
      final file = File(path);
      // A screen named here must exist, or the guard silently stops guarding.
      expect(
        path == 'lib/screens/record_screen.dart' || file.existsSync(),
        isTrue,
        reason: '$path is guarded for theme correctness but does not exist.',
      );

      final src = path == 'lib/screens/record_screen.dart'
          ? readRecordingFeatureSource()
          : file.readAsStringSync();

      for (final literal in lightLiterals) {
        if (!src.contains('backgroundColor: $literal')) continue;
        violations.add('$path pins its background to $literal');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'These screens stay light when the system asks for dark:\n'
          '${violations.join('\n')}',
    );
  });

  test('both themes define a scaffold background of their own', () {
    final theme = File('lib/theme/app_theme.dart').readAsStringSync();

    expect(theme, contains('scaffoldBackgroundColor'));
  });
}

void _scanDir(
  Directory dir,
  List<String> forbidden,
  List<String> allowedFragments,
  List<String> violations,
) {
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    _scanFile(entity.path, forbidden, allowedFragments, violations);
  }
}

void _scanFile(
  String path,
  List<String> forbidden,
  List<String> allowedFragments,
  List<String> violations,
) {
  if (allowedFragments.any(path.contains)) return;
  final content = File(path).readAsStringSync();
  for (final pattern in forbidden) {
    if (!content.contains(pattern)) continue;
    if (pattern == 'backgroundColor: Color(0xFF' ||
        pattern == 'scaffoldBackgroundColor: Color(0xFF') {
      final matches = RegExp(
        r'(?:backgroundColor|scaffoldBackgroundColor):\s*Color\(0xFF([0-9A-Fa-f]{6})\)',
      ).allMatches(content);
      for (final m in matches) {
        final hex = m.group(1)!;
        final r = int.parse(hex.substring(0, 2), radix: 16);
        final g = int.parse(hex.substring(2, 4), radix: 16);
        final b = int.parse(hex.substring(4, 6), radix: 16);
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        if (luminance < 140) {
          violations.add('$path: dark $pattern → 0xFF$hex');
        }
      }
      continue;
    }
    violations.add('$path: contains "$pattern"');
  }
}
