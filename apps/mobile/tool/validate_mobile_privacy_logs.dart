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
  final coverage = _ScanCoverage.measure(root);

  for (final missing in coverage.missingRoots) {
    print(
      'validate_mobile_privacy_logs: WARN scan root "$missing" does not '
      'exist and was skipped',
    );
  }

  // `validateProductionGraph` skips a scan root that no longer exists, so a
  // rename of every root would return zero failures and read as a pass. An
  // empty scan set is a broken gate, not a clean one.
  if (coverage.fileCount == 0) {
    print(
      'validate_mobile_privacy_logs: FAIL scanned 0 files — the gate is '
      'not enforcing anything',
    );
    print(
      '  - checked ${PrivacyLogValidator.scanRoots.length} scan root(s) '
      'under $root',
    );
    for (final scanRoot in PrivacyLogValidator.scanRoots) {
      print('  - $scanRoot');
    }
    exit(1);
  }

  final failures = PrivacyLogValidator.validateProductionGraph(root);

  if (failures.isEmpty) {
    print(
      'validate_mobile_privacy_logs: PASS '
      '(${coverage.fileCount} files across '
      '${coverage.presentRootCount} scan roots)',
    );
    exit(0);
  }

  print(
    'validate_mobile_privacy_logs: FAIL (${failures.length} issue(s) '
    'across ${coverage.fileCount} scanned files)',
  );
  for (final failure in failures) {
    print('  - $failure');
  }
  exit(1);
}

/// Mirrors the file selection in [PrivacyLogValidator.validateProductionGraph]
/// so the guard measures the set that is actually scanned.
class _ScanCoverage {
  const _ScanCoverage({
    required this.fileCount,
    required this.presentRootCount,
    required this.missingRoots,
  });

  final int fileCount;
  final int presentRootCount;
  final List<String> missingRoots;

  static _ScanCoverage measure(String root) {
    var fileCount = 0;
    var presentRootCount = 0;
    final missingRoots = <String>[];

    for (final scanRoot in PrivacyLogValidator.scanRoots) {
      final dir = Directory('$root/$scanRoot');
      if (!dir.existsSync()) {
        missingRoots.add(scanRoot);
        continue;
      }
      presentRootCount++;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        if (path.contains('/test/')) continue;
        if (PrivacyLogValidator.approvedLogWrappers.any(path.endsWith)) {
          continue;
        }
        fileCount++;
      }
    }

    return _ScanCoverage(
      fileCount: fileCount,
      presentRootCount: presentRootCount,
      missingRoots: missingRoots,
    );
  }
}

String _findMobileRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not find pubspec.yaml from ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}
