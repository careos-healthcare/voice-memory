import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/feedback/archive_feedback_model.dart';
import 'package:voicememory_mobile/widgets/feedback/archive_feedback_chips.dart';

Future<void> _pump(
  WidgetTester tester, {
  void Function(ArchiveFeedback)? onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArchiveFeedbackChips(
            targetType: ArchiveFeedbackTargetType.checkInResult,
            targetId: 'c1',
            onSubmit: onSubmit == null
                ? null
                : (f) async => onSubmit(f),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the prompt and all five chips', (tester) async {
    await _pump(tester, onSubmit: (_) {});

    expect(find.text('Was this useful?'), findsOneWidget);
    expect(find.text('Useful'), findsOneWidget);
    expect(find.text('Too generic'), findsOneWidget);
    expect(find.text('Not me'), findsOneWidget);
    expect(find.text('Already knew'), findsOneWidget);
    expect(find.text('More specific'), findsOneWidget);
  });

  testWidgets('tapping a chip shows Got it and reports the feedback',
      (tester) async {
    ArchiveFeedback? captured;
    await _pump(tester, onSubmit: (f) => captured = f);

    await tester.tap(find.text('Too generic'));
    await tester.pumpAndSettle();

    expect(find.text('Got it.'), findsOneWidget);
    expect(find.text('Was this useful?'), findsNothing);
    expect(captured?.type, ArchiveFeedbackType.tooGeneric);
    expect(captured?.targetId, 'c1');
  });

  testWidgets('only one chip can be selected', (tester) async {
    var calls = 0;
    await _pump(tester, onSubmit: (_) => calls++);

    await tester.tap(find.text('Useful'));
    await tester.pumpAndSettle();
    // The chips are gone, so a second tap is impossible; "Got it." stays.
    expect(find.text('Got it.'), findsOneWidget);
    expect(calls, 1);
  });
}
