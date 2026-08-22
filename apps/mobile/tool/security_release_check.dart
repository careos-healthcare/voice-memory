#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Release security gate — exits non-zero when risky config is detected.
///
/// Run from app root:
///   dart run tool/security_release_check.dart
void main(List<String> args) {
  final root = _findProjectRoot();
  final failures = <String>[];

  _checkHttpApiBaseUrl(root, failures);
  _checkSecretPatterns(root, failures);
  _checkDebugFlags(root, failures);
  _checkConsumerBranding(root, failures);
  _checkPipelineLogging(root, failures);
  _checkPlaceholderUrls(root, failures);

  if (failures.isEmpty) {
    print('security_release_check: PASS ($_checksRun checks)');
    exit(0);
  }

  print('security_release_check: FAIL (${failures.length} issue(s))');
  for (final failure in failures) {
    print('  - $failure');
  }
  exit(1);
}

var _checksRun = 0;

String _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find pubspec.yaml from ${Directory.current.path}');
    }
    dir = parent;
  }
}

void _checkHttpApiBaseUrl(String root, List<String> failures) {
  _checksRun++;
  final config = File('$root/lib/config/app_config.dart').readAsStringSync();
  final productionMatch = RegExp(
    r"productionApiBaseUrl\s*=\s*'([^']+)'",
  ).firstMatch(config);
  final url = productionMatch?.group(1) ?? '';
  if (url.startsWith('http://')) {
    failures.add('AppConfig production API base URL uses http ($url)');
  }
}

void _checkSecretPatterns(String root, List<String> failures) {
  _checksRun++;
  const patterns = [
    (r'sk-[A-Za-z0-9]{20,}', 'OpenAI-style API key'),
    (r'rk_live_[A-Za-z0-9]+', 'RevenueCat live key'),
    (r'strpk_live_[A-Za-z0-9]+', 'Stripe live secret key'),
    (r'AIza[0-9A-Za-z\-_]{20,}', 'Google API key'),
  ];

  final scanDirs = ['lib', 'ios', 'android'];
  final envFiles = ['.env', '.env.local', '.env.production'];

  for (final envName in envFiles) {
    final env = File('$root/$envName');
    if (!env.existsSync()) continue;
    final text = env.readAsStringSync();
    for (final (pattern, label) in patterns) {
      if (RegExp(pattern).hasMatch(text)) {
        failures.add('$label pattern found in $envName');
      }
    }
  }

  var filesScanned = 0;
  final missingDirs = <String>[];
  for (final dirName in scanDirs) {
    final dir = Directory('$root/$dirName');
    // `continue` on a missing scan root used to be invisible: every root could
    // vanish and the secret scan would still report PASS having read nothing.
    if (!dir.existsSync()) {
      missingDirs.add(dirName);
      continue;
    }
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (_shouldSkipScanPath(path)) continue;
      if (!_isScannableFile(path)) continue;
      // Decode leniently rather than with readAsStringSync, which throws on any
      // non-UTF-8 byte and aborted the whole gate on the first such file. A
      // secret scanner must still look inside a file it cannot cleanly decode.
      final text = utf8.decode(entity.readAsBytesSync(), allowMalformed: true);
      filesScanned++;
      for (final (pattern, label) in patterns) {
        if (RegExp(pattern).hasMatch(text)) {
          failures.add('$label pattern found in $path');
        }
      }
    }
  }

  if (missingDirs.isNotEmpty) {
    failures.add('secret scan roots missing: ${missingDirs.join(', ')}');
  }
  if (filesScanned == 0) {
    failures.add('secret scan matched 0 files — scan set empty, not a clean pass');
  }
}

bool _shouldSkipScanPath(String path) {
  const skipFragments = [
    '/.symlinks/',
    '/example/',
    '/examples/',
    '/node_modules/',
    '/build/',
    '/.dart_tool/',
  ];
  for (final fragment in skipFragments) {
    if (path.contains(fragment)) return true;
  }
  return false;
}

bool _isScannableFile(String path) {
  return path.endsWith('.dart') ||
      path.endsWith('.plist') ||
      path.endsWith('.gradle') ||
      path.endsWith('.kt') ||
      path.endsWith('.xml') ||
      path.endsWith('.properties');
}

void _checkDebugFlags(String root, List<String> failures) {
  _checksRun++;
  final screenshot = File('$root/lib/config/screenshot_mode.dart').readAsStringSync();
  if (screenshot.contains('defaultValue: true')) {
    failures.add('Screenshot mode dart-define defaults to true');
  }

  final trial = File('$root/lib/config/trial_mode.dart');
  if (trial.existsSync()) {
    final text = trial.readAsStringSync();
    if (text.contains('defaultValue: true') && text.contains('TRIAL')) {
      failures.add('Trial mode may default to enabled in release');
    }
  }
}

void _checkConsumerBranding(String root, List<String> failures) {
  _checksRun++;
  final brandingTest = File('$root/test/consumer_visible_branding_test.dart');
  if (!brandingTest.existsSync()) {
    failures.add('consumer_visible_branding_test.dart missing');
    return;
  }
  // Branding enforcement lives in the test suite — flag if test file is empty.
  if (brandingTest.readAsStringSync().trim().isEmpty) {
    failures.add('consumer_visible_branding_test.dart is empty');
  }
}

void _checkPipelineLogging(String root, List<String> failures) {
  _checksRun++;
  final log = File('$root/lib/services/record_pipeline_log.dart').readAsStringSync();
  const forbidden = [
    'debugPrint(transcript',
    'print(transcript',
    "log('transcript=",
    "log(\"transcript=",
    "log('body=",
    "log('observation=",
    "log('exactLanguage=",
  ];
  for (final token in forbidden) {
    if (log.contains(token)) {
      failures.add('record_pipeline_log may log full private text ($token)');
    }
  }
}

void _checkPlaceholderUrls(String root, List<String> failures) {
  _checksRun++;
  const placeholders = [
    'example.com/api',
    'your-api.example.com',
  ];
  final config = File('$root/lib/config/app_config.dart').readAsStringSync();
  final productionMatch = RegExp(
    r"productionApiBaseUrl\s*=\s*'([^']+)'",
  ).firstMatch(config);
  final productionUrl = productionMatch?.group(1) ?? '';
  for (final placeholder in placeholders) {
    if (productionUrl.contains(placeholder)) {
      failures.add('Placeholder URL in production AppConfig: $placeholder');
    }
  }
}