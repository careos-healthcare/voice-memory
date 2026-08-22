#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:archiveme_mobile/router/production_route_link_gate.dart';

/// Validates active production CTAs resolve to allowlisted routes.
///
/// Run from apps/mobile:
///   dart run tool/validate_production_route_links.dart
void main() {
  final root = _findMobileRoot();
  final failures = ProductionRouteLinkGate.validateActiveProductionGraph(root);

  if (failures.isEmpty) {
    print('validate_production_route_links: PASS');
    exit(0);
  }

  print('validate_production_route_links: FAIL (${failures.length} issue(s))');
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
