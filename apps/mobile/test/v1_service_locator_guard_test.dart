import 'dart:io';

import 'package:archiveme_mobile/core/di/v1_critical_path_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 critical paths do not access AppServices.instance', () {
    final mobileRoot = File('lib/core/di/v1_critical_path_files.dart').existsSync()
        ? Directory.current
        : Directory('apps/mobile');

    final violations = <String>[];

    for (final relativePath in V1CriticalPathFiles.noServiceLocatorAccess) {
      final file = File('${mobileRoot.path}/$relativePath');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'critical path file missing: $relativePath',
      );
      final content = file.readAsStringSync();
      if (content.contains('AppServices.instance')) {
        violations.add(relativePath);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'AppServices.instance found on V1 critical paths:\n'
          '${violations.join('\n')}\n'
          'Inject V1AccountDependencies instead.',
    );
  });
}