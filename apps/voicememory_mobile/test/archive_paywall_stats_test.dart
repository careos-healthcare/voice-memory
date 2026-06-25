import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_intelligence_proof.dart';
import 'package:voicememory_mobile/billing/archive_paywall_copy.dart';
import 'package:voicememory_mobile/billing/archive_paywall_stats.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(String id, DateTime at, List<String> themes) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: 'Reflection about work and priorities on this day.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: 'Work delivery pressure dominated my week.',
      repeatedSignal: '',
    ),
  );
}

ArchiveV1View _viewWithTheory(List<JournalEntry> entries) {
  return ArchiveV1View(
    hasMinimumEvidence: true,
    belief: null,
    theoryRanking: null,
    theory: const ArchiveCurrentTheory(
      statement: 'Work delivery pressure dominates my week.',
      confidencePercent: 81,
      evidenceCount: 34,
      counterEvidenceCount: 2,
      lastUpdated: null,
      isConfident: true,
      missingEvidenceMessage: '',
      strengthenEvidenceLines: [],
    ),
    thenNow: null,
    contradictions: const [
      ArchiveV1Contradiction(
        id: 'c1',
        youSay: 'I want balance',
        but: 'I keep working late',
        confidenceScore: 70,
        entryIds: ['e1'],
      ),
    ],
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
  test('default variant is B', () {
    expect(ArchivePaywallVariantConfig.defaultVariant, ArchivePaywallVariant.b);
  });

  test('variant B subheadline uses change-over-time copy', () {
    final stats = ArchivePaywallStats.fromEntries(
      entries: List.generate(
        10,
        (i) => _entry('e$i', DateTime.utc(2026, 1, i + 1), const ['work']),
      ),
    );
    final text = stats.subheadlineFor(ArchivePaywallVariant.b);
    expect(text, contains('patterns keep returning'));
    expect(text, contains('Pro keeps key moments'));
  });

  test('variant B pre-cta lists patterns theories contradictions', () {
    final entries = List.generate(
      127,
      (i) => _entry(
        'e$i',
        DateTime.utc(2025, 12, 1).add(Duration(days: i)),
        const ['work', 'stress'],
      ),
    );
    final stats = ArchivePaywallStats.fromEntries(
      entries: entries,
      archiveV1: _viewWithTheory(entries),
    );

    expect(stats.hasTheoryPreview, isTrue);
    expect(stats.recordingCount, 127);
    expect(stats.contradictionCount, 1);
    expect(stats.activeTheoryCount, greaterThanOrEqualTo(1));

    expect(stats.changeCount, greaterThanOrEqualTo(0));

    final pre = stats.preCtaFor(ArchivePaywallVariant.b);
    expect(pre, contains('recurring pattern'));
    expect(pre, contains('recurring theme'));
  });

  test('intelligence proof view lists only non-zero counts', () {
    final entries = List.generate(
      12,
      (i) =>
          _entry('e$i', DateTime.utc(2026, 1, i + 1), const ['work', 'stress']),
    );
    final stats = ArchivePaywallStats.fromEntries(
      entries: entries,
      archiveV1: _viewWithTheory(entries),
    );
    final proof = ArchiveIntelligenceProofView.fromStats(stats);

    expect(proof.useFallback, isFalse);
    expect(proof.bullets.length, greaterThanOrEqualTo(2));
    expect(proof.bodyText, contains('recurring theme'));
    expect(proof.bodyText, contains('recurring theme'));
    expect(proof.bodyText, isNot(contains('• 0 ')));
  });

  test('hero lines for variant B', () {
    final entries = List.generate(
      50,
      (i) => _entry(
        'e$i',
        DateTime.utc(2025, 1, 1).add(Duration(days: i * 4)),
        const ['work'],
      ),
    );
    final stats = ArchivePaywallStats.fromEntries(entries: entries);
    expect(stats.heroRecordingLine(), contains('50 recordings'));
    expect(stats.heroSpanLine(), isNotEmpty);
  });

  test('uses fallback pre-cta when few recordings', () {
    final stats = ArchivePaywallStats.fromEntries(
      entries: [
        _entry('e1', DateTime.utc(2026, 1, 1), const ['work']),
      ],
    );
    expect(
      stats.preCtaFor(ArchivePaywallVariant.b),
      ArchivePaywallCopy.preCtaFallback,
    );
  });

  test('proof fallback when no themes theories or changes', () {
    final stats = ArchivePaywallStats.fromEntries(
      entries: [_entry('e1', DateTime.utc(2026, 1, 1), const [])],
    );
    final proof = ArchiveIntelligenceProofView.fromStats(stats);
    expect(proof.useFallback, isTrue);
    expect(proof.bullets, isEmpty);
  });

  test('change count from change feed when baseline exists', () {
    final entries = List.generate(
      5,
      (i) => _entry('e$i', DateTime.utc(2026, 1, i + 1), const ['work']),
    );
    final v1 = ArchiveV1View(
      hasMinimumEvidence: true,
      belief: null,
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
      changeFeed: ArchiveChangeFeedView(
        hasBaseline: true,
        reviewedAt: DateTime(2026, 4, 1),
        newReflectionCount: 2,
        beliefsStrengthened: const [],
        beliefsWeakened: const [],
        contradictionsAppeared: const [],
        contradictionsResolved: const [],
        themesIncreasing: const [
          ArchiveChangeThemeRow(
            label: 'stress',
            mentionSeries: [1, 2, 3],
            mentionsAtReview: 2,
            mentionsNow: 3,
            newMentionsSinceReview: 1,
          ),
        ],
        themesDecreasing: const [],
      ),
      surprises: ArchiveSurprisesView.empty,
      eligibleEntries: entries,
    );
    final stats = ArchivePaywallStats.fromEntries(
      entries: entries,
      archiveV1: v1,
    );
    expect(stats.changeCount, greaterThan(0));
    final proof = ArchiveIntelligenceProofView.fromStats(stats);
    expect(proof.bodyText, contains('change'));
  });
}
