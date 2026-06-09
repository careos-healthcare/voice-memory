import '../../models/journal_entry.dart';
import '../archive_theory/archive_theory_models.dart';
import '../belief_evolution/belief_evolution_models.dart';
import '../archive_change_feed/archive_change_feed_models.dart';
import '../archive_surprises/archive_surprises_models.dart';
import '../belief_lifecycle/belief_lifecycle_models.dart';
import '../archive_analyst/archive_belief_visibility.dart';
import '../archive_theory/theory_ranking_models.dart';

/// Aggregated Archive V1 view — built from existing engines only.
class ArchiveV1View {
  const ArchiveV1View({
    required this.hasMinimumEvidence,
    required this.belief,
    required this.theory,
    required this.theoryRanking,
    required this.thenNow,
    required this.contradictions,
    required this.blindSpots,
    required this.evolutionTimeline,
    required this.lifecycle,
    required this.changeFeed,
    required this.surprises,
    required this.eligibleEntries,
  });

  final bool hasMinimumEvidence;
  final ArchiveV1Belief? belief;
  final ArchiveCurrentTheory? theory;
  final TheoryRankingResult? theoryRanking;
  final BeliefLifecycleView lifecycle;
  final ArchiveChangeFeedView changeFeed;
  final ArchiveSurprisesView surprises;
  final ArchiveV1ThenNow? thenNow;
  final List<ArchiveV1Contradiction> contradictions;
  final List<ArchiveV1BlindSpot> blindSpots;
  final BeliefEvolutionTimeline evolutionTimeline;
  final List<JournalEntry> eligibleEntries;

  bool get showTheoryHero =>
      hasMinimumEvidence &&
      theory != null &&
      ArchiveBeliefVisibility.isVisibleTheory(theory!);

  /// Deep Dive and legacy paths still use [belief].
  bool get showBeliefHero => showTheoryHero && belief != null;
}

class ArchiveV1Belief {
  const ArchiveV1Belief({
    required this.statement,
    required this.confidencePercent,
    required this.evidenceCount,
    required this.lastUpdated,
    required this.supportingEntries,
  });

  final String statement;
  final int confidencePercent;
  final int evidenceCount;
  final DateTime? lastUpdated;
  final List<JournalEntry> supportingEntries;
}

class ArchiveV1ThenNow {
  const ArchiveV1ThenNow({
    required this.thenBelief,
    required this.nowBelief,
    required this.firstEvidenceAt,
    required this.latestEvidenceAt,
    required this.supportingEvidenceCount,
    required this.hasDistinctEvolution,
  });

  final String thenBelief;
  final String nowBelief;
  final DateTime? firstEvidenceAt;
  final DateTime? latestEvidenceAt;
  final int supportingEvidenceCount;
  final bool hasDistinctEvolution;
}

class ArchiveV1Contradiction {
  const ArchiveV1Contradiction({
    required this.id,
    required this.youSay,
    required this.but,
    required this.confidenceScore,
    required this.entryIds,
    this.kind = ArchiveV1ContradictionKind.statementPair,
  });

  final String id;
  final String youSay;
  final String but;
  final int confidenceScore;
  final List<String> entryIds;
  final ArchiveV1ContradictionKind kind;
}

enum ArchiveV1ContradictionKind { statementPair, themeGap }

class ArchiveV1BlindSpot {
  const ArchiveV1BlindSpot({
    required this.id,
    required this.headline,
    required this.observation,
    required this.confidence,
    required this.evidenceCount,
    required this.entryIds,
  });

  final String id;
  final String headline;
  final String observation;
  final int confidence;
  final int evidenceCount;
  final List<String> entryIds;
}
