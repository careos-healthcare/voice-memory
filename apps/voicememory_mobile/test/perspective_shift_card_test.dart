import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';
import 'package:voicememory_mobile/widgets/record/perspective_shift_card.dart';

const _grounded = 'I said yes before checking what I needed today.';

Future<void> _pump(
  WidgetTester tester, {
  String resultHint = 'same',
  String reflectionText = _grounded,
  String languageCode = 'en',
  bool compact = false,
  Future<void> Function(String)? onCreateCheckIn,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PerspectiveShiftCard(
            reflectionText: reflectionText,
            resultHint: resultHint,
            checkInQuestion: 'Did this pattern show up again?',
            patternTitle: 'Saying yes too fast',
            languageCode: languageCode,
            compact: compact,
            onCreateCheckIn: onCreateCheckIn ?? (_) async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the perspective with labels and buttons', (tester) async {
    await _pump(tester);

    expect(find.text('Another perspective'), findsOneWidget);
    expect(find.text('One pattern to notice'), findsOneWidget);
    expect(find.text('Why this is useful'), findsOneWidget);
    expect(find.text('Next check'), findsOneWidget);
    expect(find.text('Show another perspective'), findsOneWidget);
    expect(find.text('Use this check'), findsOneWidget);
  });

  testWidgets('Show another perspective cycles to a different angle',
      (tester) async {
    await _pump(tester);
    expect(find.text('One pattern to notice'), findsOneWidget);

    await tester.tap(find.text('Show another perspective'));
    await tester.pump();

    expect(find.text('One pattern to notice'), findsNothing);
  });

  testWidgets('Use this check creates the check-in and confirms',
      (tester) async {
    String? created;
    await _pump(
      tester,
      onCreateCheckIn: (question) async => created = question,
    );

    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();

    expect(created, 'What happens right before this shows up?');
    expect(find.text(localized('tomorrowCheckSet', 'en')), findsOneWidget);
  });

  testWidgets('vague reflection surfaces the Early read label', (tester) async {
    await _pump(tester, reflectionText: 'Today was stressful.');
    expect(find.text('Early read'), findsOneWidget);
  });

  testWidgets('compact variant shows the short "Show another" control',
      (tester) async {
    await _pump(tester, compact: true);
    expect(find.text('Another perspective'), findsOneWidget);
    expect(find.text('Use this check'), findsOneWidget);
    expect(find.text('Show another'), findsOneWidget);
  });

  testWidgets('localizes labels and buttons in Spanish', (tester) async {
    await _pump(tester, languageCode: 'es');
    expect(find.text('Otra perspectiva'), findsOneWidget);
    expect(find.text('Usar esta revisión'), findsOneWidget);
    expect(find.text('Mostrar otra perspectiva'), findsOneWidget);
    expect(find.text('Another perspective'), findsNothing);
  });
}
