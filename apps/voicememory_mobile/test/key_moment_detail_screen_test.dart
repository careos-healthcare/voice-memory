import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/screens/key_moment_detail_screen.dart';

KeyMoment _moment({String? nextCheck}) => KeyMoment(
      id: 'm1',
      date: DateTime(2026, 6, 5),
      title: 'Something felt heavier',
      originalText: 'I said yes before checking what I needed.',
      shortSummary: 'I said yes before checking what I needed.',
      patternTitle: 'Taking on too much',
      resultHint: 'heavier',
      nextCheck: nextCheck,
    );

void main() {
  testWidgets('shows the original text, pattern, result and next check',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KeyMomentDetailScreen(
          moment: _moment(nextCheck: 'What happened right before you said yes?'),
          onUseCheck: (_) async {},
        ),
      ),
    );

    expect(
      find.text('I said yes before checking what I needed.'),
      findsOneWidget,
    );
    expect(find.text('Something felt heavier'), findsOneWidget);
    expect(find.text('Taking on too much'), findsOneWidget);
    expect(find.text('This felt heavier.'), findsOneWidget);
    expect(
      find.text('What happened right before you said yes?'),
      findsOneWidget,
    );
    expect(find.text('Use this check'), findsOneWidget);
  });

  testWidgets('Use this check fires the callback and confirms', (tester) async {
    String? used;
    await tester.pumpWidget(
      MaterialApp(
        home: KeyMomentDetailScreen(
          moment: _moment(nextCheck: 'What made it heavier?'),
          onUseCheck: (q) async => used = q,
        ),
      ),
    );

    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();

    expect(used, 'What made it heavier?');
    expect(find.textContaining('check is set'), findsOneWidget);
  });

  testWidgets('no Use this check button when there is no next check',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KeyMomentDetailScreen(
          moment: _moment(),
          onUseCheck: (_) async {},
        ),
      ),
    );

    expect(find.text('Use this check'), findsNothing);
  });
}
