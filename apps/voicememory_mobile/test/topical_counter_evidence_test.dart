import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_confidence_engine.dart';
import 'package:voicememory_mobile/features/archive_analyst/topical_counter_evidence.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry(
  String id,
  String transcript,
  DateTime at, {
  List<String> themes = const [],
  String tension = '',
  String observation = '',
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: observation.isEmpty ? transcript : observation,
      repeatedSignal: themes.isNotEmpty ? themes.first : '',
      tensionOrContradiction: tension.isEmpty ? null : tension,
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  const topical = TopicalCounterEvidence();
  const engine = ArchiveAnalystConfidenceEngine();

  test('excludes cross-theme transcript without opposition link', () {
    final entries = [
      _entry(
        's1',
        'I avoid difficult conversations at work because conflict feels overwhelming at the office.',
        DateTime.utc(2026, 1, 5),
        themes: const ['career'],
      ),
      _entry(
        's2',
        'I avoid difficult conversations again when tension rises at work with my manager.',
        DateTime.utc(2026, 2, 5),
        themes: const ['career'],
      ),
      _entry(
        'x',
        'My partner and I had a wonderful evening and I feel deeply connected and grateful.',
        DateTime.utc(2026, 3, 5),
        themes: const ['relationships'],
      ),
    ];
    final split = engine.splitEntries(
      beliefText: 'I avoid difficult conversations at work',
      eligible: entries,
    );
    expect(split.supporting.length, greaterThanOrEqualTo(2));
    expect(split.counter.map((e) => e.id), isNot(contains('x')));
  });

  test('includes topical opposing sentiment on same theme', () {
    final entries = [
      _entry(
        's1',
        'I feel exhausted before the workday starts and weekends do not refill me at work.',
        DateTime.utc(2026, 1, 5),
        themes: const ['health', 'career'],
      ),
      _entry(
        's2',
        'I feel exhausted before the workday starts again when the manager adds more work.',
        DateTime.utc(2026, 2, 5),
        themes: const ['health', 'career'],
      ),
      _entry(
        'c1',
        'I genuinely love this team and the mission we are building together every day at work.',
        DateTime.utc(2026, 3, 5),
        themes: const ['career'],
      ),
    ];
    final split = engine.splitEntries(
      beliefText:
          'I feel exhausted before the workday starts and weekends do not refill me',
      eligible: entries,
    );
    expect(split.counter.map((e) => e.id), contains('c1'));
  });

  test('caps counter at twice supporting count', () {
    final entries = <JournalEntry>[];
    for (var i = 0; i < 4; i++) {
      entries.add(
        _entry(
          's$i',
          'I avoid difficult conversations at work when stakes feel personal and tense.',
          DateTime.utc(2026, 1, i + 1),
          themes: const ['career'],
        ),
      );
    }
    for (var i = 0; i < 12; i++) {
      entries.add(
        _entry(
          'c$i',
          'I feel energized and speak directly at work when tension rises with my manager.',
          DateTime.utc(2026, 2, i + 1),
          themes: const ['career'],
          tension:
              'I no longer avoid difficult conversations when stakes feel personal at work.',
        ),
      );
    }
    final split = engine.splitEntries(
      beliefText: 'I avoid difficult conversations at work',
      eligible: entries,
    );
    expect(split.supporting.length, greaterThanOrEqualTo(2));
    expect(
      split.counter.length,
      lessThanOrEqualTo(split.supporting.length * 2),
    );
    expect(split.rawCounterCount, greaterThan(split.counter.length));
    expect(split.counterExceedsSupportTwice, isTrue);
  });

  test('isRelevantCounterQuote matches engine rules', () {
    expect(
      topical.isRelevantCounterQuote(
        beliefText:
            'I avoid bringing up needs with my partner until resentment builds',
        counterQuote:
            'I told my partner everything is fine and I do not need more support right now.',
      ),
      isTrue,
    );
    expect(
      topical.isRelevantCounterQuote(
        beliefText:
            'I avoid difficult conversations with my cofounder when stakes feel personal',
        counterQuote:
            'I trust my gut on product bets and move fast when customers pull us.',
      ),
      isFalse,
    );
  });

  test('every pickRaw counter passes isRelevantCounterQuote', () {
    final entries = [
      _entry(
        's1',
        'I avoid difficult conversations at work because conflict feels overwhelming.',
        DateTime.utc(2026, 1, 5),
        themes: const ['career'],
      ),
      _entry(
        's2',
        'I avoid difficult conversations again when tension rises at work with my manager.',
        DateTime.utc(2026, 2, 5),
        themes: const ['career'],
      ),
      _entry(
        'c0',
        'I feel energized and speak directly at work when tension rises with my manager.',
        DateTime.utc(2026, 3, 1),
        themes: const ['career'],
        tension:
            'I no longer avoid difficult conversations when stakes feel personal at work.',
      ),
    ];
    const belief = 'I avoid difficult conversations at work';
    final support = entries.take(2).toList();
    final raw = topical.pickRaw(
      beliefText: belief,
      eligible: entries,
      supporting: support,
    );
    for (final e in raw) {
      expect(
        topical.isRelevantCounterQuote(
          beliefText: belief,
          counterQuote: e.transcript,
        ),
        isTrue,
      );
    }
  });

  test('pickRaw returns empty when no topical opposition', () {
    final entries = [
      _entry(
        'only',
        'Quarterly roadmap planning with the manager about delivery goals.',
        DateTime.utc(2026, 1, 1),
        themes: const ['career'],
      ),
    ];
    final raw = topical.pickRaw(
      beliefText:
          'I avoid bringing up needs with my partner until resentment builds',
      eligible: entries,
      supporting: const [],
    );
    expect(raw, isEmpty);
  });
}
