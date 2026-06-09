import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/language/localized_copy.dart';
import 'package:voicememory_mobile/widgets/record/kinder_angle_card.dart';

const _selfBlame =
    'After the meeting I felt stupid and useless, like it was my fault.';

Future<void> _pump(
  WidgetTester tester, {
  String reflectionText = _selfBlame,
  String languageCode = 'en',
  bool compact = false,
  Future<void> Function(String)? onCreateCheckIn,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: KinderAngleCard(
            reflectionText: reflectionText,
            patternTitle: 'Carrying it alone',
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
  testWidgets('shows the kinder read, labels, caution and buttons',
      (tester) async {
    await _pump(tester);

    expect(find.text('A kinder angle'), findsOneWidget);
    expect(
      find.text(
          'This may be a hard moment, not proof that something is wrong with you.'),
      findsOneWidget,
    );
    expect(find.text('Why this helps'), findsOneWidget);
    expect(find.text('Next check'), findsOneWidget);
    expect(find.text('Use what fits. Leave what does not.'), findsOneWidget);
    expect(find.text('Use this check'), findsOneWidget);
    expect(find.text('Show another angle'), findsOneWidget);
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

    expect(created, 'What happened right before you judged yourself?');
    expect(find.text(localized('tomorrowCheckSet', 'en')), findsOneWidget);
  });

  testWidgets('Show another angle steps back to the broader read once',
      (tester) async {
    await _pump(tester);
    expect(
      find.text(
          'This may be a hard moment, not proof that something is wrong with you.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Show another angle'));
    await tester.pump();

    expect(
      find.text('This may be one hard moment, not the whole story.'),
      findsOneWidget,
    );
    // No duplicate angle: the broader read replaces the previous one and the
    // control is now disabled.
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Show another angle'),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('vague input surfaces the Early read label', (tester) async {
    await _pump(tester, reflectionText: 'I felt so stupid.');
    expect(find.text('Early read'), findsOneWidget);
  });

  testWidgets('compact variant keeps the action but drops the why line',
      (tester) async {
    await _pump(tester, compact: true);
    expect(find.text('A kinder angle'), findsOneWidget);
    expect(find.text('Use this check'), findsOneWidget);
    expect(find.text('Show another angle'), findsOneWidget);
    expect(find.text('Why this helps'), findsNothing);
  });

  testWidgets('localizes labels and buttons in Spanish', (tester) async {
    await _pump(tester, languageCode: 'es');
    expect(find.text('Una mirada más amable'), findsOneWidget);
    expect(find.text('Usar esta revisión'), findsOneWidget);
    expect(find.text('Mostrar otra mirada'), findsOneWidget);
    expect(find.text('A kinder angle'), findsNothing);
  });
}
