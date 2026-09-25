import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:archiveme_mobile/widgets/entry_detail/entry_context_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({required String mood, String? health}) {
  return JournalEntry(
    id: 'moment-1',
    createdAt: DateTime.utc(2026, 6, 12, 10),
    transcript: 'The river was high.',
    durationSeconds: 12,
    reflection: Reflection(
      mood: mood,
      emotionalIntensity: 1,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
      healthStateOfMind: health,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('shows the chosen mood and Apple Health side by side', (
    tester,
  ) async {
    final entry = _entry(mood: 'Calm', health: 'peaceful');

    await _pump(
      tester,
      ListView(
        children: [
          ArchiveEntryCardMeta(entry: entry),
          EntryContextPlaceholders(entry: entry),
        ],
      ),
    );

    expect(find.text('Calm'), findsNWidgets(2));
    expect(find.text('peaceful'), findsNWidgets(2));
    expect(
      find.byKey(const Key('health_state_of_mind_moment-1')),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('entry_mood_moment-1')), findsOneWidget);
    expect(find.byKey(const Key('archive_mood_moment-1')), findsOneWidget);
    expect(entry.reflection.mood, 'Calm');
  });

  testWidgets('shows only the field that is present', (tester) async {
    await _pump(
      tester,
      ArchiveEntryCardMeta(entry: _entry(mood: 'Calm')),
    );
    expect(find.text('Calm'), findsOneWidget);
    expect(find.byKey(const Key('health_state_of_mind_moment-1')), findsNothing);

    await _pump(
      tester,
      ArchiveEntryCardMeta(entry: _entry(mood: 'neutral', health: 'calm')),
    );
    expect(find.byKey(const Key('archive_mood_moment-1')), findsNothing);
    expect(find.text('calm'), findsOneWidget);
  });
}
