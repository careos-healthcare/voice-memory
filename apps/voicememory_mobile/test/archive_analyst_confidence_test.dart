import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_analyst/archive_analyst_confidence_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry(
  String id,
  String transcript,
  DateTime at, {
  List<String> themes = const [],
  String tension = '',
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
      concreteObservation: transcript,
      repeatedSignal: themes.isNotEmpty ? themes.first : '',
      tensionOrContradiction: tension.isEmpty ? null : tension,
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  const engine = ArchiveAnalystConfidenceEngine();

  test('higher support than heavy counter', () {
    final strong = engine.score(
      supportingCount: 20,
      counterCount: 2,
      recencyRatio: 0.5,
      consistencyRatio: 0.9,
      maxContradictionScore: 0,
      stale: false,
    );
    final weak = engine.score(
      supportingCount: 20,
      counterCount: 15,
      recencyRatio: 0.5,
      consistencyRatio: 0.4,
      maxContradictionScore: 80,
      stale: false,
    );
    expect(strong, greaterThan(weak));
  });

  test('stale belief scores lower than recent', () {
    final fresh = engine.score(
      supportingCount: 10,
      counterCount: 1,
      recencyRatio: 0.8,
      consistencyRatio: 0.85,
      maxContradictionScore: 0,
      stale: false,
    );
    final stale = engine.score(
      supportingCount: 10,
      counterCount: 1,
      recencyRatio: 0.8,
      consistencyRatio: 0.85,
      maxContradictionScore: 0,
      stale: true,
    );
    expect(fresh, greaterThan(stale));
  });

  test('splitEntries finds support and counter', () {
    final entries = [
      _entry(
        'a',
        'I avoid difficult conversations at work because conflict feels overwhelming.',
        DateTime.utc(2026, 1, 5),
      ),
      _entry(
        'b',
        'I avoid difficult conversations again when tension rises at home.',
        DateTime.utc(2026, 2, 5),
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
    final split = engine.splitEntries(
      beliefText: 'I avoid difficult conversations at work',
      eligible: entries,
    );
    expect(split.supporting.length, greaterThanOrEqualTo(2));
    expect(split.counter, isNotEmpty);
  });
}
