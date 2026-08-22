import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _forbiddenRuntimeCopy = [
  'Cloud processing pending',
  'Cloud sync is unavailable',
  'Cloud sync unavailable',
  'Saved on this device. Cloud processing pending',
];

/// Internal filter lists may mention lowercase fragments for blocking only.
const _allowlistedPaths = {
  'lib/features/timeline/timeline_entry_display.dart',
  'lib/features/immediate_archive_value/immediate_archive_value_engine.dart',
  'lib/features/first_reflection/first_reflection_insights.dart',
  'lib/product/consumer_copy_guard.dart',
};

void main() {
  test('lib/ has no forbidden cloud-processing runtime copy', () {
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceFirst('${Directory.current.path}/', '');
      if (_allowlistedPaths.contains(path)) continue;

      final source = entity.readAsStringSync();
      for (final forbidden in _forbiddenRuntimeCopy) {
        if (source.contains(forbidden)) {
          violations.add('"$forbidden" in $path');
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}