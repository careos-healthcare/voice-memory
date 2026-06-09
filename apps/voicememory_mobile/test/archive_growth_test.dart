import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_growth/archive_confidence_engine.dart';
import 'package:voicememory_mobile/features/archive_growth/archive_growth_maturity.dart';
import 'package:voicememory_mobile/features/archive_growth/archive_journey_engine.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_engine.dart';
import 'package:voicememory_mobile/features/archive_discovery_share/archive_discovery_share_types.dart';
import 'package:voicememory_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:voicememory_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:voicememory_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:voicememory_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:voicememory_mobile/features/belief_evolution/belief_evolution_models.dart';
import 'package:voicememory_mobile/features/belief_lifecycle/belief_lifecycle_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry(
  String id,
  DateTime at, {
  String observation = 'I am uncertain about this decision.',
  List<String> themes = const ['work'],
}) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: 'Reflection text for testing.',
    durationSeconds: 20,
    reflection: Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: observation,
      repeatedSignal: 'pressure',
    ),
  );
}

ArchiveV1View _minimalV1({
  ArchiveChangeFeedView? changeFeed,
  List<ArchiveV1Contradiction> contradictions = const [],
}) {
  return ArchiveV1View(
    hasMinimumEvidence: true,
    belief: null,
    theory: const ArchiveCurrentTheory(
      statement: 'Work dominates my week.',
      confidencePercent: 55,
      evidenceCount: 8,
      counterEvidenceCount: 1,
      lastUpdated: null,
      isConfident: true,
      missingEvidenceMessage: '',
      strengthenEvidenceLines: [],
    ),
    theoryRanking: null,
    thenNow: null,
    contradictions: contradictions,
    blindSpots: const [],
    evolutionTimeline: const BeliefEvolutionTimeline(
      blocks: [],
      firstBelief: null,
      currentBelief: null,
    ),
    lifecycle: const BeliefLifecycleView(current: null, retired: []),
    changeFeed: changeFeed ?? ArchiveChangeFeedView.empty,
    surprises: ArchiveSurprisesView.empty,
    eligibleEntries: const [],
  );
}

void main() {
  group('ArchiveGrowthMaturity', () {
    test('maps recording counts to levels', () {
      expect(
        ArchiveGrowthMaturity.fromRecordingCount(0).level,
        ArchiveGrowthLevel.seed,
      );
      expect(
        ArchiveGrowthMaturity.fromRecordingCount(9).level,
        ArchiveGrowthLevel.seed,
      );
      expect(
        ArchiveGrowthMaturity.fromRecordingCount(10).level,
        ArchiveGrowthLevel.growing,
      );
      expect(
        ArchiveGrowthMaturity.fromRecordingCount(17).recordingsUntilNext,
        33,
      );
      expect(
        ArchiveGrowthMaturity.fromRecordingCount(50).level,
        ArchiveGrowthLevel.established,
      );
      expect(
        ArchiveGrowthMaturity.fromRecordingCount(200).nextLevel,
        isNull,
      );
    });
  });

  group('ArchiveConfidenceEngine', () {
    test('low count uses gathering evidence copy', () {
      final view = ArchiveConfidenceEngine.build(
        entries: [_entry('e1', DateTime(2026, 1, 1))],
      );
      expect(view.score, greaterThanOrEqualTo(0));
      expect(view.explanation, contains('gathering evidence'));
      expect(view.maturity.label, 'Seed');
    });

    test('higher theory confidence raises score', () {
      final entries = List.generate(
        12,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final low = ArchiveConfidenceEngine.build(entries: entries);
      final high = ArchiveConfidenceEngine.build(
        entries: entries,
        archiveV1: _minimalV1(),
      );
      expect(high.score, greaterThan(low.score));
    });
  });

  group('ArchiveJourneyEngine', () {
    test('day 1 unlocks with observation', () {
      final journey = ArchiveJourneyEngine.build(
        entries: [_entry('e1', DateTime.now())],
      );
      expect(journey.steps.first.isUnlocked, isTrue);
      expect(journey.steps.first.reward, contains('archive noticed'));
    });

    test('day 3 surfaces recurring theme', () {
      final entries = [
        _entry('e1', DateTime(2026, 1, 1), themes: ['burnout']),
        _entry('e2', DateTime(2026, 1, 2), themes: ['burnout']),
        _entry('e3', DateTime(2026, 1, 3), themes: ['burnout']),
      ];
      final journey = ArchiveJourneyEngine.build(entries: entries);
      expect(journey.steps[1].reward, contains('burnout'));
    });

    test('day 7 uses change feed when available', () {
      final v1 = _minimalV1(
        changeFeed: ArchiveChangeFeedView(
          hasBaseline: true,
          reviewedAt: DateTime(2026, 5, 1),
          newReflectionCount: 2,
          beliefsStrengthened: const [],
          beliefsWeakened: const [],
          contradictionsAppeared: const [],
          contradictionsResolved: const [],
          themesIncreasing: const [],
          themesDecreasing: const [
            ArchiveChangeThemeRow(
              label: 'anxiety',
              mentionSeries: [3, 2, 1],
              mentionsAtReview: 2,
              mentionsNow: 1,
              newMentionsSinceReview: 0,
            ),
          ],
        ),
      );
      final entries = List.generate(
        7,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final journey = ArchiveJourneyEngine.build(entries: entries, archiveV1: v1);
      expect(journey.steps[2].reward, contains('less often'));
    });
  });

  group('ArchiveDiscoveryShareEngine', () {
    test('includes contradiction card with V1 format', () {
      final entries = List.generate(
        5,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final discoveries = ArchiveDiscoveryShareEngine.build(
        entries: entries,
        archiveV1: _minimalV1(
          contradictions: const [
            ArchiveV1Contradiction(
              id: 'c1',
              youSay: 'I want balance',
              but: 'I work late',
              confidenceScore: 70,
              entryIds: ['e1'],
            ),
          ],
        ),
      );
      expect(
        discoveries.any((d) => d.type == ArchiveDiscoveryShareCardType.contradiction),
        isTrue,
      );
      final card = discoveries.firstWhere(
        (d) => d.type == ArchiveDiscoveryShareCardType.contradiction,
      );
      expect(card.introLine, 'My archive noticed:');
      expect(card.footer, 'ArchiveMe');
      expect(card.insight, contains('balance'));
      expect(card.evidenceRecordingCount, 1);
    });
  });
}
