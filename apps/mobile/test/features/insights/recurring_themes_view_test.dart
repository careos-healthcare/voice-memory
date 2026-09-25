import 'package:archiveme_mobile/features/insights/recurring_themes_view.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 6, 12),
    transcript: transcript,
    durationSeconds: 4,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
  );
}

void main() {
  test('theme labels drop scores and percentages', () {
    expect(plainThemeLabel('work (80% match)'), 'work');
    expect(plainThemeLabel('Score: 9/10'), isEmpty);
    expect(plainThemeLabel('confidence: 72%'), isEmpty);
  });

  testWidgets('a theme opens the verbatim entries that produced it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecurringThemesView(
            entries: [
              _entry(
                id: 'a',
                transcript: 'I kept circling the same work decision.',
                themes: ['work (80% match)', 'Score: 9/10'],
              ),
              _entry(
                id: 'b',
                transcript: 'Work came up again on the walk home.',
                themes: ['work'],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('work'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('Score'), findsNothing);
    await tester.tap(find.byKey(const Key('recurring_theme_sentence_work')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('theme_verbatim_a')),
      findsOneWidget,
    );
    expect(find.text('Work came up again on the walk home.'), findsOneWidget);
  });
}
