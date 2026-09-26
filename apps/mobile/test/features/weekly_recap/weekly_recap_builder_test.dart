import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_builder.dart';
import 'package:archiveme_mobile/features/weekly_recap/weekly_recap_screen.dart';
import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:archiveme_mobile/models/journal_display_metadata.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/archive/archive_weekly_recap_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime createdAt,
  required String transcript,
  int durationSeconds = 60,
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
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    display: JournalDisplayMetadata(locationLabel: place),
  );
}

void main() {
  final sunday = DateTime(2026, 9, 27, 12);

  setUp(WeeklyRecapCache.clear);

  test('an empty week has no themes, pair, or listen-back', () {
    final recap = WeeklyRecapBuilder.build(
      [
        _entry(
          id: 'old',
          createdAt: DateTime(2026, 8, 1, 9),
          transcript: 'A note from August.',
        ),
      ],
      now: sunday,
    );
    expect(recap.hasEntries, isFalse);
    expect(recap.daysRecorded, 0);
    expect(recap.totalMinutes, 0);
    expect(recap.themes, isEmpty);
    expect(recap.thenAndNow, isNull);
    expect(recap.listenBack, isEmpty);
    expect(recap.moods, isEmpty);
    expect(recap.places, isEmpty);
  });

  test('one entry counts one day and one quoted sentence', () {
    final recap = WeeklyRecapBuilder.build(
      [
        _entry(
          id: 'only',
          createdAt: DateTime(2026, 9, 25, 9),
          transcript: 'The river was quiet on Friday.',
          durationSeconds: 120,
          mood: 'calm',
          place: 'River cafe',
          audioPath: '/tmp/only.m4a',
        ),
      ],
      now: sunday,
      wordTimestamps: (_) => const [(word: 'river', startSeconds: 4)],
    );
    expect(recap.daysRecorded, 1);
    expect(recap.totalMinutes, 2);
    expect(recap.themes, hasLength(1));
    expect(recap.themes.single.sentence, contains('river'));
    expect(recap.themes.single.startSeconds, 4);
    expect(recap.listenBack.single.startSeconds, 4);
    expect(recap.listenBack.single.clipSeconds, 15);
    expect(recap.moods, ['calm']);
    expect(recap.places, ['River cafe']);
    expect(recap.thenAndNow, isNull);
  });

  test('seven entries count seven days and at most three themes', () {
    final recap = WeeklyRecapBuilder.build(
      [
        for (var day = 21; day <= 27; day++)
          _entry(
            id: 'd$day',
            createdAt: DateTime(2026, 9, day, 8),
            transcript: 'Day $day was its own walk along a different street.',
            durationSeconds: 60,
            audioPath: '/tmp/$day.m4a',
          ),
      ],
      now: sunday,
    );
    expect(recap.daysRecorded, 7);
    expect(recap.totalMinutes, 7);
    expect(recap.themes.length, inInclusiveRange(1, 3));
    expect(recap.listenBack.length, lessThanOrEqualTo(3));
  });

  test('then and now is omitted when nothing is three weeks older', () {
    final recap = WeeklyRecapBuilder.build(
      [
        _entry(
          id: 'now',
          createdAt: DateTime(2026, 9, 26, 9),
          transcript: 'The river was quiet on Saturday.',
        ),
        _entry(
          id: 'recent',
          createdAt: DateTime(2026, 9, 10, 9),
          transcript: 'The river was quiet on Saturday.',
        ),
      ],
      now: sunday,
    );
    expect(recap.thenAndNow, isNull);
  });

  test('then and now pairs this week with a matching line from three weeks ago', () {
    final recap = WeeklyRecapBuilder.build(
      [
        _entry(
          id: 'now',
          createdAt: DateTime(2026, 9, 26, 9),
          transcript: 'The river was quiet on Saturday.',
        ),
        _entry(
          id: 'then',
          createdAt: DateTime(2026, 8, 1, 9),
          transcript: 'The river was quiet on Saturday.',
        ),
      ],
      now: sunday,
    );
    expect(recap.thenAndNow?.now.entryId, 'now');
    expect(recap.thenAndNow?.then.entryId, 'then');
  });

  test('summary sentences without a real entry citation are dropped', () {
    final kept = WeeklyRecapBuilder.citedSentences(
      summary:
          'You returned to the river. The river was quiet on Saturday. A line with no source.',
      citations: const [
        (text: 'The river was quiet on Saturday.', entryId: 'now'),
      ],
      validEntryIds: {'now'},
    );
    expect(kept, ['The river was quiet on Saturday.']);
  });

  testWidgets('the banner shows Sunday through Tuesday when the week has an entry', (
    tester,
  ) async {
    final entry = _entry(
      id: 'week',
      createdAt: DateTime(2026, 9, 25, 9),
      transcript: 'Friday by the river.',
    );

    Future<void> pump(DateTime now) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveWeeklyRecapBanner(entries: [entry], now: now),
          ),
        ),
      );
    }

    await pump(DateTime(2026, 9, 27, 0, 1));
    expect(find.byKey(const Key('archive_weekly_recap')), findsOneWidget);

    await pump(DateTime(2026, 9, 28, 12));
    expect(find.byKey(const Key('archive_weekly_recap')), findsOneWidget);

    await pump(DateTime(2026, 9, 29, 23, 59));
    expect(find.byKey(const Key('archive_weekly_recap')), findsOneWidget);

    await pump(DateTime(2026, 9, 30, 0, 1));
    expect(find.byKey(const Key('archive_weekly_recap')), findsNothing);
  });

  testWidgets('the banner stays hidden when that week has no entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveWeeklyRecapBanner(
            entries: [
              _entry(
                id: 'old',
                createdAt: DateTime(2026, 8, 1),
                transcript: 'August only.',
              ),
            ],
            now: DateTime(2026, 9, 27, 18),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('archive_weekly_recap')), findsNothing);
  });

  testWidgets('cloud off shows no written summary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WeeklyRecapScreen(
          entries: [
            _entry(
              id: 'only',
              createdAt: DateTime(2026, 9, 25, 9),
              transcript: 'The river was quiet on Friday.',
            ),
          ],
          now: sunday,
          cloudEnabled: false,
          cloudSummary: const WeeklyRecap(
            weekKey: '2026-09-27',
            summary: 'The river was quiet on Friday.',
            keyThemes: const [],
            verbatimCitations: [
              VerbatimCitation(
                text: 'The river was quiet on Friday.',
                entryId: 'only',
                timestamp: '2026-09-25T09:00:00Z',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Your week in your own words'), findsWidgets);
    expect(find.text('1 of 7 days'), findsOneWidget);
    expect(find.text('Written by AI from your entries'), findsNothing);
    expect(find.text('Share as image'), findsOneWidget);
    expect(find.text('Save as PDF'), findsOneWidget);
    expect(find.textContaining('emotional'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
