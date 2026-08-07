import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/di/v1_critical_path_files.dart';

void main() {
  test('V1 critical paths do not access AppServices.instance', () {
    final mobileRoot = Directory.current.path.endsWith('voicememory_mobile')
        ? Directory.current
        : Directory('apps/voicememory_mobile');

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
