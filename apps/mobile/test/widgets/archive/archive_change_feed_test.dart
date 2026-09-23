import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/archive/archive_change_feed.dart';
import 'package:archiveme_mobile/widgets/archive/archive_change_feed_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArchiveChangeFeedTimeline', () {
    test('sorts months newest first and keeps voice apart from text', () {
      final sections = ArchiveChangeFeedTimeline.sections(
        entries: [
          _entry(
            id: 'text-old',
            at: DateTime.utc(2025, 6, 15, 12),
            transcript: 'A typed note from last June.',
          ),
          _entry(
            id: 'voice-new',
            at: DateTime.utc(2026, 9, 4, 12),
            transcript: 'A voice memory from this September.',
            durationSeconds: 84,
            localAudioPath: '/tmp/september.m4a',
          ),
          _entry(
            id: 'text-new',
            at: DateTime.utc(2026, 9, 2, 12),
            transcript: 'A typed note from this September.',
          ),
        ],
      );

      expect(sections.map((section) => section.label), [
        'September 2026',
        'June 2025',
      ]);
      expect(sections.first.voiceCount, 1);
      expect(sections.first.textCount, 1);
      expect(sections.first.entries.map((entry) => entry.id), [
        'voice-new',
        'text-new',
      ]);
      expect(
        ArchiveChangeFeedTimeline.sections(
          entries: sections.expand((section) => section.entries).toList(),
          year: 2025,
        ).single.label,
        'June 2025',
      );
      expect(ArchiveChangeFeedTimeline.formatDuration(84), '1:24');
    });
  });

  testWidgets('filters by year and month and collapses a timeframe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArchiveChangeFeed(
              entries: [
                _entry(
                  id: 'voice',
                  at: DateTime.utc(2026, 9, 4, 12),
                  transcript: 'Walked home and talked the whole way.',
                  durationSeconds: 84,
                  localAudioPath: '/tmp/walk.m4a',
                ),
                _entry(
                  id: 'text',
                  at: DateTime.utc(2026, 9, 2, 12),
                  transcript: 'Wrote down the grocery list before dinner.',
                ),
                _entry(
                  id: 'older',
                  at: DateTime.utc(2025, 6, 15, 12),
                  transcript: 'Called one friend after lunch last year.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Change feed'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('June 2025'), findsOneWidget);
    expect(find.text('1 voice · 1 text'), findsOneWidget);
    expect(
      find.byKey(const Key('archive_change_feed_voice_voice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('archive_change_feed_text_text')),
      findsOneWidget,
    );
    expect(find.text('Voice memory'), findsOneWidget);
    expect(find.text('Text log'), findsWidgets);
    expect(find.text('1:24'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('September 2026')).dy,
      lessThan(tester.getTopLeft(find.text('June 2025')).dy),
    );

    await tester.tap(find.byKey(const Key('archive_change_feed_year_2026')));
    await tester.pump();
    expect(find.text('June 2025'), findsNothing);
    expect(find.text('Called one friend after lunch last year.'), findsNothing);

    await tester.tap(find.text('September'));
    await tester.pump();
    expect(find.text('Walked home and talked the whole way.'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('archive_change_feed_section_2026-9')),
    );
    await tester.pump();
    expect(find.text('Walked home and talked the whole way.'), findsNothing);
    expect(find.text('September 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive_change_feed_all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('archive_change_feed_year_2025')));
    await tester.pump();
    await tester.tap(find.text('June'));
    await tester.pump();
    expect(
      find.text('Called one friend after lunch last year.'),
      findsOneWidget,
    );
    expect(find.text('Walked home and talked the whole way.'), findsNothing);
  });
}

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  int durationSeconds = 0,
  String? localAudioPath,
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: durationSeconds,
    localAudioPath: localAudioPath,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}
