import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_hash.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_pack_builder.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 3, 1),
    transcript: transcript,
    durationSeconds: 40,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: const ['work'],
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: '',
    ),
  );
}

ArchiveV1View _minimalView(List<JournalEntry> entries) {
  return ArchiveV1View(
    hasMinimumEvidence: true,
    belief: null,
    theoryRanking: null,
    theory: const ArchiveCurrentTheory(
      statement: 'You tend to avoid conflict at work.',
      confidencePercent: 65,
      evidenceCount: 8,
      counterEvidenceCount: 2,
      lastUpdated: null,
      isConfident: true,
      missingEvidenceMessage: '',
      strengthenEvidenceLines: [],
    ),
    thenNow: null,
    contradictions: const [],
    blindSpots: const [],
    evolutionTimeline: const BeliefEvolutionTimeline(
      blocks: [],
      firstBelief: null,
      currentBelief: null,
    ),
    lifecycle: const BeliefLifecycleView(current: null, retired: []),
    changeFeed: ArchiveChangeFeedView.empty,
    surprises: ArchiveSurprisesView.empty,
    eligibleEntries: entries,
  );
}

void main() {
  test('pack hash is stable for same inputs', () {
    final entries = List.generate(
      55,
      (i) => _entry(
        'e$i',
        'Reflection about work stress and priorities number $i today at the office.',
      ),
    );
    final view = _minimalView(entries);
    final h1 = ArchiveSynthesisPackBuilder.hashForView(
      view: view,
      monthKey: '2026-05',
      milestonesReached: {50},
    );
    final h2 = ArchiveSynthesisPackBuilder.hashForView(
      view: view,
      monthKey: '2026-05',
      milestonesReached: {50},
    );
    expect(h1, h2);
    expect(h1.length, 32);
  });

  test('pack hash changes when transcript changes', () {
    final entriesA = List.generate(
      55,
      (i) => _entry(
        'e$i',
        'Version A reflection about work priorities number $i today.',
      ),
    );
    final entriesB = List.generate(
      55,
      (i) => _entry(
        'e$i',
        'Version B reflection about career change number $i today.',
      ),
    );
    final hA = ArchiveSynthesisPackBuilder.hashForView(
      view: _minimalView(entriesA),
      monthKey: '2026-05',
      milestonesReached: {50},
    );
    final hB = ArchiveSynthesisPackBuilder.hashForView(
      view: _minimalView(entriesB),
      monthKey: '2026-05',
      milestonesReached: {50},
    );
    expect(hA, isNot(hB));
  });

  test('pack includes theory and reflection index', () {
    final entries = List.generate(
      50,
      (i) => _entry(
        'e$i',
        'Work reflection about deadlines and stress number $i today.',
      ),
    );
    final pack = ArchiveSynthesisPackBuilder.build(
      view: _minimalView(entries),
      monthKey: '2026-05',
      milestonesReached: {50},
    );
    expect(pack['packVersion'], 2);
    expect(pack['eligibleCount'], 50);
    expect(pack['theory'], isNotNull);
    expect(pack['primaryTheory'], isNotNull);
    expect(pack['reflectionIndex'], hasLength(50));
    final hash = computeArchiveHashFromPack(pack);
    expect(hash, isNotEmpty);
  });
}
