#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:archiveme_mobile/router/production_billing_import_gate.dart';

void main() {
  final root = _findMobileRoot();
  final failures = ProductionBillingImportGate.validateConsumerProductionGraph(
    root,
  );
  if (failures.isEmpty) {
    print('validate_production_billing_absence: PASS');
    exit(0);
  }
  print(
    'validate_production_billing_absence: FAIL (${failures.length} issue(s))',
  );
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
