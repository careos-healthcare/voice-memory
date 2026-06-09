import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_theory/theory_ranking_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

import 'support/archive_quality_personas.dart';

void main() {
  const engine = TheoryRankingEngine();

  test('relationship persona picks partner belief not work delivery', () {
    final entries = buildPersonaArchive(
      ArchiveQualityPersona.relationshipFocused,
      count: 100,
    );
    final eligible = entries
        .where((e) => e.transcript.trim().length >= 24)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final result = engine.rank(entries: entries, eligible: eligible);
    final primary = result.primaryTheory;
    expect(primary, isNotNull);
    final lower = primary!.statement.toLowerCase();
    expect(lower, contains('partner'));
    expect(lower, isNot(contains('work delivery pressure dominates')));
    expect(primary.evidenceCount, greaterThanOrEqualTo(3));
    expect(primary.confidencePercent, greaterThanOrEqualTo(15));
  });

  test('rejects trait templates and low-evidence statements', () {
    final entries = [
      JournalEntry(
        id: '1',
        createdAt: DateTime.utc(2026, 1, 1),
        transcript:
            'Work delivery pressure dominates my week and the roadmap never ends.',
        durationSeconds: 30,
        reflection: Reflection(
          mood: 'thoughtful',
          emotionalIntensity: 2,
          recurringThemes: const ['career'],
          exactLanguagePattern: '',
          concreteObservation: 'Work delivery pressure dominates my week.',
          repeatedSignal: '',
        ),
        syncStatus: SyncStatus.localOnly,
      ),
    ];
    final result = engine.rank(entries: entries, eligible: entries);
    expect(result.primaryTheory, isNull);
    expect(result.rejectedCandidates, greaterThan(0));
  });
}
