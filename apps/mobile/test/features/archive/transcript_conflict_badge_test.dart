import 'package:archiveme_mobile/features/archive/widgets/transcript_conflict_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the badge opens a side-by-side choice', (tester) async {
    String? kept;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TranscriptConflictBadge(
            deviceA: 'the river was high',
            deviceB: 'the river fell overnight',
            onResolved: (text) => kept = text,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transcript_conflict_badge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transcript_conflict_device_a')), findsOneWidget);
    expect(find.byKey(const Key('transcript_conflict_device_b')), findsOneWidget);

    await tester.tap(find.byKey(const Key('transcript_combine_both')));
    await tester.pumpAndSettle();
    expect(kept, 'the river was high\n\nthe river fell overnight');
  });
}
