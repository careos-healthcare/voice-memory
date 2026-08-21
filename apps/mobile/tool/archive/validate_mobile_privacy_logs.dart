#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:archiveme_mobile/security/privacy_log_validator.dart';

/// Validates release-safe logging on the focused beta mobile production graph.
///
/// Run from apps/mobile:
///   dart run tool/validate_mobile_privacy_logs.dart
void main() {
  final root = _findMobileRoot();
  final failures = PrivacyLogValidator.validateProductionGraph(root);

  if (failures.isEmpty) {
    print('validate_mobile_privacy_logs: PASS');
    exit(0);
  }

  print('validate_mobile_privacy_logs: FAIL (${failures.length} issue(s))');
  for (final failure in failures) {
    print('  - $failure');
  }
  exit(1);
}

String _findMobileRoot() {
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
