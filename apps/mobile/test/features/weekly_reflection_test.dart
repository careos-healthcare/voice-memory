import 'package:archiveme_mobile/core/database/database_provider.dart';
import 'package:archiveme_mobile/features/insights/services/local_recap_generator.dart';
import 'package:archiveme_mobile/features/insights/views/weekly_recap_view.dart';
import 'package:archiveme_mobile/features/settings/services/notification_service.dart';
import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
  int durationSeconds = 120,
  List<String> themes = const [],
  String mood = '',
  String? place,
  String? audioPath,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: durationSeconds,
    localAudioPath: audioPath,
    reflection: Reflection(
      mood: mood,
      emotionalIntensity: 0,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    display: JournalDisplayMetadata(locationLabel: place),
  );
}

void main() {
  test('a week counts days and minutes, and cites one line per theme', () {
    final now = DateTime(2026, 9, 26, 12);
    final recap = const LocalRecapGenerator().build(
      [
        _entry(
          id: 'a',
          createdAt: DateTime(2026, 9, 24, 9),
          transcript: 'The river was loud this morning.',
          durationSeconds: 90,
          themes: ['river'],
          mood: 'calm',
          place: 'River cafe',
          audioPath: '/tmp/a.m4a',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 9, 25, 18),
          transcript: 'The river was quieter on the walk home tonight.',
          durationSeconds: 30,
          themes: ['river'],
          mood: 'calm',
          audioPath: '/tmp/b.m4a',
        ),
        _entry(
          id: 'old',
          createdAt: DateTime(2026, 8, 1, 9),
          transcript: 'An older note that is not this week.',
          durationSeconds: 600,
        ),
      ],
      now: now,
    );

    expect(recap.daysRecorded, 2);
    expect(recap.totalMinutes, 2);
    expect(recap.themes.single.label, 'river');
    expect(recap.themes.single.entryId, 'b');
    expect(recap.themes.single.quote, contains('quieter'));
    expect(recap.moods, ['calm']);
    expect(recap.places, ['River cafe']);
    expect(recap.listenBack.map((clip) => clip.entryId), ['b', 'a']);
    expect(recap.entries.map((entry) => entry.id), ['a', 'b']);
  });

  test(
    'then vs now pairs this week with a match older than seven days',
    () async {
      final built = const LocalRecapGenerator().build(
        [
          _entry(
            id: 'now',
            createdAt: DateTime(2026, 9, 26, 8),
            transcript: 'I kept circling the same work decision.',
          ),
        ],
        now: DateTime(2026, 9, 26, 12),
      );
      final recap = await const LocalRecapGenerator().withEarlierMatch(
        built,
        earlierMatch: (prominent) async {
          expect(prominent.id, 'now');
          return SimilarEntry(
            id: 'then',
            createdAt: DateTime(2026, 8, 1),
            transcript: 'Work was already the thing I kept naming.',
            cosineSimilarity: 0.8,
          );
        },
      );

      expect(recap.thenVsNow?.thisWeekEntryId, 'now');
      expect(recap.thenVsNow?.earlierEntryId, 'then');
      expect(recap.thenVsNow?.earlierQuote, contains('already'));
    },
  );

  test('Sunday evening notification uses the week title', () {
    expect(
      WeeklyRecapNotificationService.title,
      'Your week in your own words',
    );
    expect(
      WeeklyRecapNotificationService.nextSundayEvening(
        DateTime(2026, 9, 25, 12),
      ),
      DateTime(2026, 9, 27, 18),
    );
    WeeklyRecapNotificationService.rememberTap('weekly-recap');
    expect(WeeklyRecapNotificationService.takePending(), isTrue);
    expect(WeeklyRecapNotificationService.takePending(), isFalse);
  });

  testWidgets('the recap shows citations, an AI summary, and share', (
    tester,
  ) async {
    final shared = <String>[];
    final entry = _entry(
      id: 'a',
      createdAt: DateTime(2026, 9, 24, 9),
      transcript: 'The river was loud this morning.',
      themes: ['river'],
      mood: 'calm',
      place: 'River cafe',
      audioPath: '/tmp/a.m4a',
    );
    final recap = const LocalRecapGenerator()
        .build(
          [entry],
          now: DateTime(2026, 9, 26, 12),
        )
        .copyWith(
          thenVsNow: const ThenVsNow(
            thisWeekQuote: 'The river was loud this morning.',
            thisWeekEntryId: 'a',
            earlierQuote: 'The river was a whisper in August.',
            earlierEntryId: 'old',
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyRecapView(
          entries: [entry],
          recap: recap,
          cloudSummary: const WeeklyRecap(
            weekKey: '2026-09-27',
            summary:
                'You returned to the river. The river was loud this morning. A line with no source.',
            keyThemes: ['river'],
            verbatimCitations: [
              VerbatimCitation(
                text: 'The river was loud this morning.',
                entryId: 'a',
                timestamp: '2026-09-24T09:00:00Z',
              ),
            ],
          ),
          onShare: (value) async => shared.add(value.entries.single.id),
        ),
      ),
    );

    expect(find.textContaining('streak'), findsNothing);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('River cafe'), findsOneWidget);
    expect(find.byKey(const Key('weekly_play_a')), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Written by AI from your entries'),
      200,
    );
    expect(find.text('Written by AI from your entries'), findsOneWidget);
    expect(find.text('The river was loud this morning.'), findsWidgets);
    expect(find.text('You returned to the river.'), findsNothing);
    expect(find.text('A line with no source.'), findsNothing);
    expect(find.text('· View evidence'), findsWidgets);

    await tester.tap(find.byKey(const Key('weekly_recap_share')));
    await tester.pump();
    expect(shared, ['a']);
  });
}
