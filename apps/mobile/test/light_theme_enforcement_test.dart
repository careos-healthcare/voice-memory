import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scans live consumer UI layers for forbidden dark backgrounds.
void main() {
  const scanRoots = [
    'lib/screens',
    'lib/widgets',
    'lib/router',
    'lib/features/capture_flow/ui',
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

  test('default app theme is light only', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('AppTheme.light()'));
    expect(app, contains('ThemeMode.light'));
  });

  test('consumer routes use warm light scaffold background', () {
    for (final path in [
      'lib/features/capture_flow/ui/capture_screen.dart',
      'lib/features/capture_flow/ui/capture_screen_host.dart',
      'lib/features/capture_flow/ui/capture_flow_panels.dart',
      'lib/screens/archive_belief_screen.dart',
      'lib/screens/account_screen.dart',
      'lib/screens/settings_screen.dart',
      'lib/screens/paywall_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        src.contains('AppColors.backgroundPrimary') ||
            src.contains('PushedScreenShell') ||
            src.contains('AppTheme.background') ||
            src.contains('ScreenshotMode.enabled'),
        isTrue,
        reason: '$path should use light background',
      );
    }
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
