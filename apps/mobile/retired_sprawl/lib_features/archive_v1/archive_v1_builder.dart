import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_engine.dart';
import 'package:archiveme_mobile/features/archive_change_feed/archive_change_feed_models.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_state_delta/archive_state_snapshot.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_engine.dart';
import 'package:archiveme_mobile/features/archive_surprises/archive_surprises_models.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_engine.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_ranking_engine.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_theme_gap_engine.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_service.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_engine.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_lifecycle_models.dart';
import 'package:archiveme_mobile/features/discover/belief_engine.dart';
import 'package:archiveme_mobile/features/discover/blind_spot_engine.dart';
import 'package:archiveme_mobile/features/discover/contradiction_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Composes Archive V1 from existing on-device engines.
class ArchiveV1Builder {
  const ArchiveV1Builder({
    this.beliefEngine = const DiscoverBeliefEngine(),
    this.theoryEngine = const ArchiveTheoryEngine(),
    this.lifecycleEngine = const BeliefLifecycleEngine(),
    this.changeFeedEngine = const ArchiveChangeFeedEngine(),
    this.surprisesEngine = const ArchiveSurprisesEngine(),
    this.contradictionEngine = const DiscoverContradictionEngine(),
    this.blindSpotEngine = const DiscoverBlindSpotEngine(),
    this.themeGapEngine = const ArchiveThemeGapEngine(),
    this.theoryRankingEngine = const TheoryRankingEngine(),
    this.minContradictionConfidence = 60,
    this.minBlindSpotConfidence = 60,
  });

  final DiscoverBeliefEngine beliefEngine;
  final ArchiveTheoryEngine theoryEngine;
  final TheoryRankingEngine theoryRankingEngine;
  final BeliefLifecycleEngine lifecycleEngine;
  final ArchiveChangeFeedEngine changeFeedEngine;
  final ArchiveSurprisesEngine surprisesEngine;
  final DiscoverContradictionEngine contradictionEngine;
  final DiscoverBlindSpotEngine blindSpotEngine;
  final ArchiveThemeGapEngine themeGapEngine;
  final int minContradictionConfidence;
  final int minBlindSpotConfidence;

  Future<ArchiveV1View> build({
    required List<JournalEntry> entries,
    required BeliefEvolutionService evolutionService, ArchiveStateObjectV3? state,
    ArchiveStateSnapshot? baseline,
  }) async {
    final hasMin = archiveHasMinimumEvidence(entries);
    final eligible = archiveEligibleEvidenceEntries(entries);

    if (!hasMin) {
      return ArchiveV1View(
        hasMinimumEvidence: false,
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
        changeFeed: ArchiveChangeFeedView.empty,
        surprises: ArchiveSurprisesView.empty,
        eligibleEntries: eligible,
      );
    }

    final evoState = await evolutionService.refreshFromEntries(
      entries: entries,
      legacySnapshot: baseline,
    );
    final timeline = evolutionService.buildTimeline(
      state: evoState,
      entries: entries,
    );

    final statementContradictions = contradictionEngine
        .build(entries: entries, state: state)
        .where((c) => c.confidenceScore >= minContradictionConfidence)
        .map(
          (c) => ArchiveV1Contradiction(
            id: 'stmt:${c.entryIdA}:${c.entryIdB}',
            youSay: _truncate(c.statementA, 140),
            but: _truncate(c.statementB, 140),
            confidenceScore: c.confidenceScore,
            entryIds: [c.entryIdA, c.entryIdB],
          ),
        );

    final gapContradictions = themeGapEngine.build(entries);
    final contradictions = [...statementContradictions, ...gapContradictions]
      ..sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    final topContradictions = contradictions.take(5).toList();

    final maxCtr = topContradictions.isEmpty
        ? 0
        : topContradictions
              .map((c) => c.confidenceScore)
              .reduce((a, b) => a > b ? a : b);

    final contradictionEntryIds = topContradictions
        .expand((c) => c.entryIds)
        .toSet();

    final surprises = surprisesEngine.build(entries: entries);

    final theoryRanking = theoryRankingEngine.rank(
      entries: entries,
      eligible: eligible,
      state: state,
      evolution: evoState,
      contradictions: topContradictions,
      surprises: surprises.observations,
    );

    final primary = theoryRanking.primaryTheory;
    final theory = primary == null
        ? null
        : theoryEngine.build(
            entries: entries,
            statement: primary.statement,
            maxContradictionScore: maxCtr,
            lastUpdated: primary.lastUpdated,
            contradictionEntryIds: contradictionEntryIds,
          );

    final belief = theory == null || primary == null
        ? null
        : ArchiveV1Belief(
            statement: theory.statement,
            confidencePercent: theory.confidencePercent,
            evidenceCount: theory.evidenceCount,
            lastUpdated: theory.lastUpdated,
            supportingEntries: primary.supportingEntries,
          );

    final thenNow = _buildThenNow(
      timeline,
      eligible,
      theory?.statement,
      primary?.supportingEntries.length,
    );

    final blindSpots = blindSpotEngine
        .build(entries)
        .where((b) => b.confidence >= minBlindSpotConfidence)
        .map(
          (b) => ArchiveV1BlindSpot(
            id: b.id,
            headline: b.headline,
            observation: b.observation,
            confidence: b.confidence,
            evidenceCount: b.evidenceCount,
            entryIds: b.entryIds,
          ),
        )
        .take(4)
        .toList();

    final lifecycle = lifecycleEngine.build(
      entries: entries,
      activeStatement: theory?.statement,
      evolution: evoState,
    );

    final changeFeed = changeFeedEngine.build(
      entries: entries,
      baseline: baseline,
      state: state,
    );

    return ArchiveV1View(
      hasMinimumEvidence: true,
      belief: belief,
      theory: theory,
      theoryRanking: theoryRanking,
      thenNow: thenNow,
      contradictions: topContradictions,
      blindSpots: blindSpots,
      evolutionTimeline: timeline,
      lifecycle: lifecycle,
      changeFeed: changeFeed,
      surprises: surprises,
      eligibleEntries: eligible,
    );
  }

  ArchiveV1ThenNow? _buildThenNow(
    BeliefEvolutionTimeline timeline,
    List<JournalEntry> eligible,
    String? primaryBelief,
    int? primarySupportCount,
  ) {
    final first = timeline.firstBelief;
    final nowText = primaryBelief?.trim() ?? '';
    if (nowText.isEmpty) return null;

    final thenText = first?.beliefText.trim() ?? nowText;
    final firstAt = eligible.isNotEmpty ? eligible.first.createdAt : null;
    final latestAt = eligible.isNotEmpty ? eligible.last.createdAt : null;
    final supportCount =
        primarySupportCount ??
        first?.supportingEntryIds.length ??
        eligible.length;

    return ArchiveV1ThenNow(
      thenBelief: thenText,
      nowBelief: nowText,
      firstEvidenceAt: firstAt,
      latestEvidenceAt: latestAt,
      supportingEvidenceCount: supportCount,
      hasDistinctEvolution: timeline.hasEvolution,
    );
  }

  String _truncate(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max).trim()}…';
  }
}