import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/screens/key_moments_screen.dart';

KeyMoment _moment(String id, DateTime date,
        {String title = 'Moment from today',
        String text = 'a moment',
        String? resultHint,
        String? patternTitle,
        List<String> tags = const []}) =>
    KeyMoment(
      id: id,
      date: date,
      title: title,
      originalText: text,
      shortSummary: text,
      resultHint: resultHint,
      patternTitle: patternTitle,
      tags: tags,
    );

Future<void> _pump(WidgetTester tester, List<KeyMoment> moments) async {
  await tester.pumpWidget(
    MaterialApp(
      home: KeyMomentsScreen(
        loader: () async => moments,
        firstLoopClosed: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the four filters and the title', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Key moments'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('empty state invites recording a moment', (tester) async {
    await _pump(tester, const []);

    expect(find.textContaining('Record one moment'), findsOneWidget);
  });

  testWidgets('today filter shows today\u2019s moment', (tester) async {
    final now = DateTime.now();
    await _pump(tester, [
      _moment('today', now,
          title: 'Something felt heavier',
          text: 'I said yes before checking.',
          resultHint: 'heavier'),
    ]);

    expect(find.text('Something felt heavier'), findsOneWidget);
    expect(find.text('felt heavier'), findsOneWidget);
    expect(find.text('Open moment'), findsOneWidget);
  });

  testWidgets('this week filter reveals an older moment', (tester) async {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    await _pump(tester, [
      _moment('old', threeDaysAgo, title: 'Something changed'),
    ]);

    // Not visible under Today.
    expect(find.text('Something changed'), findsNothing);

    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();

    expect(find.text('Something changed'), findsOneWidget);
  });

  testWidgets('search filter shows a search field and matches text',
      (tester) async {
    await _pump(tester, [
      _moment('a', DateTime.now().subtract(const Duration(days: 10)),
          title: 'Moment from today',
          text: 'The worry came back when things got quiet.'),
    ]);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'worry');
    await tester.pumpAndSettle();

    expect(find.textContaining('The worry came back'), findsOneWidget);
  });

  testWidgets('tag filter row offers All plus common tags', (tester) async {
    await _pump(tester, const []);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Pressure'), findsOneWidget);
    expect(find.text('Worry'), findsOneWidget);
    expect(find.text('Tired'), findsOneWidget);
    expect(find.text('Lighter'), findsOneWidget);
  });

  testWidgets('selecting a tag narrows the visible moments', (tester) async {
    final now = DateTime.now();
    await _pump(tester, [
      _moment('w', now,
          title: 'A work moment', text: 'meeting ran over', tags: const ['work']),
      _moment('f', now,
          title: 'A family moment', text: 'called mum', tags: const ['family']),
    ]);

    expect(find.text('A work moment'), findsOneWidget);
    expect(find.text('A family moment'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('A work moment'), findsOneWidget);
    expect(find.text('A family moment'), findsNothing);
  });
}
