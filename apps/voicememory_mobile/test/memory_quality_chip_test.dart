import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_memory/memory_quality_model.dart';
import 'package:voicememory_mobile/widgets/patterns/memory_quality_chip.dart';

const _quality = MemoryQuality(
  level: MemoryQualityLevel.clearPattern,
  label: 'Clear pattern',
  helperText: 'This pattern is clear enough to check tomorrow.',
  momentCount: 8,
  checkInCount: 8,
  weekCount: 3,
  hasChangedRecently: false,
);

Future<void> _pump(WidgetTester tester, {VoidCallback? onTap}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MemoryQualityChip(quality: _quality, onTap: onTap),
      ),
    ),
  );
}

void main() {
  testWidgets('renders label', (tester) async {
    await _pump(tester);
    expect(find.text('Clear pattern'), findsOneWidget);
    expect(find.textContaining('confidence'), findsNothing);
  });

  testWidgets('expands helper text on tap', (tester) async {
    await _pump(tester);
    expect(
      find.text('This pattern is clear enough to check tomorrow.'),
      findsNothing,
    );
    await tester.tap(find.text('Clear pattern'));
    await tester.pump();
    expect(
      find.text('This pattern is clear enough to check tomorrow.'),
      findsOneWidget,
    );
  });

  testWidgets('onTap callback fires when tapped', (tester) async {
    var tapped = false;
    await _pump(tester, onTap: () => tapped = true);
    await tester.tap(find.text('Clear pattern'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('hides when shouldShow is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MemoryQualityChip(quality: MemoryQuality.hidden)),
      ),
    );
    expect(find.text('Early read'), findsNothing);
  });
}
