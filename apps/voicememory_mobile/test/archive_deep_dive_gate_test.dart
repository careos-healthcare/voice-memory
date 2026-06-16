import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_deep_dive/archive_deep_dive_gate.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry(String id, String transcript) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 2, id.hashCode % 20 + 1),
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

ArchiveV1View _view({required bool hasMin, ArchiveV1Belief? belief}) {
  return ArchiveV1View(
    hasMinimumEvidence: hasMin,
    belief: belief,
    theory: null,
    theoryRanking: null,
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
    eligibleEntries: const [],
  );
}

void main() {
  test('canOpenDeepDive false without minimum evidence', () {
    expect(ArchiveDeepDiveGate.canOpenDeepDive(_view(hasMin: false)), isFalse);
  });

  test('canOpenDeepDive false without belief', () {
    expect(
      ArchiveDeepDiveGate.canOpenDeepDive(_view(hasMin: true, belief: null)),
      isFalse,
    );
  });

  test('canOpenDeepDive true with belief and supporting entries', () {
    final entries = List.generate(
      5,
      (i) => _entry(
        'e$i',
        'I avoid difficult conversations at work and home repeatedly today.',
      ),
    );
    final belief = ArchiveV1Belief(
      statement: 'I avoid difficult conversations',
      confidencePercent: 72,
      evidenceCount: 5,
      lastUpdated: DateTime.utc(2026, 2, 10),
      supportingEntries: entries,
    );
    expect(
      ArchiveDeepDiveGate.canOpenDeepDive(_view(hasMin: true, belief: belief)),
      isTrue,
    );
  });
}
