import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_pump.dart';

/// Expands the Record screen advanced save options section in widget tests.
Future<void> expandAdvancedSaveOptions(WidgetTester tester) async {
  final tile = find.byKey(const Key('entry_options_expansion'));
  if (tile.evaluate().isEmpty) return;
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await pumpUntilFound(
    tester,
    find.byKey(const Key('entry_memory_scope_picker')),
  );
}
