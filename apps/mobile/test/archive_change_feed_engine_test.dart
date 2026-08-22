import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_engine.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required DateTime at,
  required String transcript,
  List<String> themes = const [],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'anxious',
      emotionalIntensity: 4,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: themes.isNotEmpty ? themes.first : '',
    ),
  );
}

ArchiveStateSnapshot _baselineAt(DateTime at) {
  return ArchiveStateSnapshot(
    belief: 'Prior belief',
    confidence: 60,
    reputation: 'developing',
    evidenceCount: 4,
    lifeAreas: const [],
    timestamp: at.toUtc().toIso8601String(),
  );
}

void main() {
  const engine = ArchiveChangeFeedEngine();

  test('no baseline returns empty message', () {
    final feed = engine.build(
      entries: List.generate(
        5,
        (i) => _entry(
          id: 'e$i',
          at: DateTime.utc(2026, 3, i + 1),
          transcript: 'Work anxiety and stress at the office keep coming up.',
          themes: const ['career'],
        ),
      ),
    );
    expect(feed.hasBaseline, isFalse);
    expect(feed.hasChanges, isFalse);
  });

  test('themes increasing shows mention trend series', () {
    final reviewAt = DateTime.utc(2026, 1, 15);
    final entries = <JournalEntry>[
      for (var i = 0; i < 4; i++)
        _entry(
          id: 'old$i',
          at: DateTime.utc(2026, 1, 5 + i),
          transcript: 'Work anxiety at the office is overwhelming my week.',
          themes: const ['career'],
        ),
      for (var i = 0; i < 9; i++)
        _entry(
          id: 'mid$i',
          at: DateTime.utc(2026, 2, 5 + (i % 20)),
          transcript:
              'Work anxiety keeps showing up in every standup and email.',
          themes: const ['career'],
        ),
      for (var i = 0; i < 6; i++)
        _entry(
          id: 'new$i',
          at: DateTime.utc(2026, 3, 10 + i),
          transcript: 'Work anxiety is constant before I open my laptop.',
          themes: const ['career'],
        ),
    ];

    final feed = engine.build(
      entries: entries,
      baseline: _baselineAt(reviewAt),
    );

    expect(feed.hasBaseline, isTrue);
    expect(feed.newReflectionCount, greaterThan(0));
    final career = feed.themesIncreasing
        .where((t) => t.label == 'Career')
        .toList();
    expect(career, isNotEmpty);
    expect(career.first.mentionSeries.length, greaterThanOrEqualTo(2));
    expect(
      career.first.mentionsNow,
      greaterThan(career.first.mentionsAtReview),
    );
  });

  test('confidence concerns theme can decrease', () {
    final reviewAt = DateTime.utc(2026, 2);
    final entries = <JournalEntry>[
      for (var i = 0; i < 11; i++)
        _entry(
          id: 'c$i',
          at: DateTime.utc(2026, 1, 10 + i),
          transcript:
              'My confidence is shaky and I doubt my judgment at work today.',
          themes: const ['confidence'],
        ),
      for (var i = 0; i < 7; i++)
        _entry(
          id: 'm$i',
          at: DateTime.utc(2026, 2, 5 + i),
          transcript:
              'My confidence is shaky and I doubt my judgment at work today.',
          themes: const ['confidence'],
        ),
      for (var i = 0; i < 3; i++)
        _entry(
          id: 'l$i',
          at: DateTime.utc(2026, 3, 5 + i),
          transcript:
              'My confidence is shaky and I doubt my judgment at work today.',
          themes: const ['confidence'],
        ),
    ];

    final feed = engine.build(
      entries: entries,
      baseline: _baselineAt(reviewAt),
    );

    final conf = feed.themesDecreasing
        .where((t) => t.label == 'Confidence')
        .toList();
    expect(conf, isNotEmpty);
    expect(conf.first.mentionSeries, [11, 7, 3]);
    expect(conf.first.mentionsNow, lessThan(conf.first.mentionsAtReview));
  });
}