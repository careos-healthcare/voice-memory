import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry(String id, String transcript, DateTime at) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: transcript,
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  const engine = ArchiveTheoryEngine();

  test('returns null for placeholder statement', () {
    final entries = List.generate(
      5,
      (i) => _entry(
        'e$i',
        'This is a long enough transcript about work stress today.',
        DateTime.utc(2026, 1, i + 1),
      ),
    );
    expect(
      engine.build(
        entries: entries,
        statement: 'Your archive is still gathering evidence from your recordings.',
      ),
      isNull,
    );
  });

  test('builds theory with evidence and counter counts', () {
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
      for (var i = 0; i < 8; i++)
        _entry(
          'u$i',
          'Unrelated topic about cooking and weekend plans entirely different words.',
          DateTime.utc(2026, 3, i + 1),
        ),
    ];

    final theory = engine.build(
      entries: entries,
      statement: 'I avoid difficult conversations at work and home.',
    );

    expect(theory, isNotNull);
    expect(theory!.evidenceCount, greaterThanOrEqualTo(2));
    expect(theory.counterEvidenceCount, greaterThanOrEqualTo(0));
    expect(theory.confidencePercent, inInclusiveRange(0, 100));
  });

  test('isConfident false below threshold shows strengthening copy', () {
    final entries = [
      _entry(
        'only',
        'I avoid difficult conversations once at work today only mention.',
        DateTime.utc(2026, 1, 1),
      ),
      for (var i = 0; i < 12; i++)
        _entry(
          'x$i',
          'Completely different transcript about weather sports music travel food.',
          DateTime.utc(2026, 2, i + 1),
        ),
    ];

    final theory = engine.build(
      entries: entries,
      statement: 'I avoid difficult conversations at work and home.',
      maxContradictionScore: 75,
    );

    expect(theory, isNotNull);
    if (theory!.confidencePercent < ArchiveTheoryEngine.confidentThreshold) {
      expect(theory.isConfident, isFalse);
      expect(theory.missingEvidenceMessage, isNotEmpty);
      expect(theory.strengthenEvidenceLines, isNotEmpty);
    }
  });

  test('confident threshold is 60', () {
    expect(ArchiveTheoryEngine.confidentThreshold, 60);
  });

  test('low support yields not confident with strengthen lines', () {
    final entries = [
      _entry(
        'one',
        'I avoid difficult conversations at work once in January only.',
        DateTime.utc(2026, 1, 1),
      ),
      for (var i = 0; i < 15; i++)
        _entry(
          'o$i',
          'Other unrelated notes about travel food music sports weather plans.',
          DateTime.utc(2026, 3, i + 1),
        ),
    ];

    final theory = engine.build(
      entries: entries,
      statement: 'I avoid difficult conversations at work and home.',
    );

    expect(theory, isNotNull);
    expect(theory!.isConfident, isFalse);
    expect(theory.confidencePercent, lessThan(60));
    expect(theory.missingEvidenceMessage, isNotEmpty);
    expect(theory.strengthenEvidenceLines.length, greaterThanOrEqualTo(1));
  });
}
