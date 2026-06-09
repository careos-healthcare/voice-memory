import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_pro_gate.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  test('free tier cannot access archive intelligence', () {
    expect(
      ArchiveSynthesisProGate.canAccessArchiveIntelligence(
        PremiumEntitlements.free(),
      ),
      isFalse,
    );
  });

  test('pro tier with pro entitlement id passes entitlement gate', () {
    const pro = PremiumEntitlements(
      tier: BillingTier.pro,
      entitlementIds: ['pro'],
      billingConnected: true,
      source: 'revenuecat',
    );
    expect(ArchiveSynthesisProGate.hasProEntitlement(pro), isTrue);
  });

  test('free archive surfaces are not pro-gated', () {
    expect(
      ArchiveSynthesisProGate.isFreeArchiveSurface(
        ArchiveIntelligenceSurface.theory,
      ),
      isTrue,
    );
    expect(
      ArchiveSynthesisProGate.isFreeArchiveSurface(
        ArchiveIntelligenceSurface.standardDeepDive,
      ),
      isTrue,
    );
    expect(
      ArchiveSynthesisProGate.isProOnlySurface(
        ArchiveIntelligenceSurface.monthlyReview,
      ),
      isTrue,
    );
  });

  test('restore path uses same pro entitlement id as gate', () {
    expect(RevenueCatService.proEntitlementId, 'pro');
  });

  test('archive theory hero remains available on free view', () {
    final view = _minimalView(
      List.generate(
        55,
        (i) => _entry('e$i', 'Work reflection about deadlines $i today.'),
      ),
    );
    expect(view.showTheoryHero, isTrue);
    expect(view.theory, isNotNull);
  });
}

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
      statement: 'Work delivery pressure dominates my week.',
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
