import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ensures the strangler capture path does not import legacy recording barrel
/// or experimental post-save engines.
void main() {
  test('capture_flow module avoids recording_dependencies barrel', () {
    final root = File('lib/features/capture_flow/capture_flow_controller.dart')
            .existsSync()
        ? Directory.current
        : Directory('apps/mobile');
    final captureDir = Directory('${root.path}/lib/features/capture_flow');
    expect(captureDir.existsSync(), isTrue);

    final forbiddenImports = [
      'recording_dependencies.dart',
      'recording_build_context_assembler.dart',
      'pattern_hypothesis_engine.dart',
      'daily_discovery_engine.dart',
      'curiosity_hook_coordinator.dart',
      'pattern_memory_coordinator.dart',
      'first_three_journey_engine.dart',
    ];

    final violations = <String>[];
    for (final entity in captureDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('capture_screen_host.dart')) continue;
      final content = entity.readAsStringSync();
      for (final forbidden in forbiddenImports) {
        if (content.contains(forbidden)) {
          violations.add('${entity.path}: $forbidden');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Strangler capture path must not transitively depend on legacy engines:\n'
          '${violations.join('\n')}',
    );
  });

  test('capture_flow production files stay under UI line budget', () {
    final root = File('lib/features/capture_flow/ui/capture_screen.dart')
            .existsSync()
        ? Directory.current
        : Directory('apps/mobile');
    final screen = File('${root.path}/lib/features/capture_flow/ui/capture_screen.dart');
    final lines = screen.readAsLinesSync().length;
    expect(lines, lessThan(300));
  });
}
