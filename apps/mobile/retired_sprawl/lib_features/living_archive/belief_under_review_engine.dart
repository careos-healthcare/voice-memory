import 'package:archiveme_mobile/design/archive_confidence_display.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_explanations/belief_timeline_engine.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_copy.dart';
import 'package:archiveme_mobile/features/living_archive/living_archive_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Working belief with confidence trend for review (not a final verdict).
class BeliefUnderReviewEngine {
  const BeliefUnderReviewEngine({
    this.timelineEngine = const BeliefTimelineEngine(),
  });

  final BeliefTimelineEngine timelineEngine;

  BeliefUnderReview? build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    final belief = state?.belief?.trim();
    if (belief == null || belief.isEmpty) return null;
    if (!ArchiveEvidenceGuard.canSurfaceBelief(entries)) return null;

    final timeline = timelineEngine.build(entries: entries, beliefText: belief);
    final percent = timeline.points.isNotEmpty
        ? timeline.currentPercent
        : archiveConfidencePercent(
            health: state!.health,
            evidenceReflectionCount: state.evidenceReflectionCount,
          );

    final trend = switch (timeline.trend) {
      BeliefTimelineTrend.strengthening => BeliefConfidenceTrend.rising,
      BeliefTimelineTrend.weakening => BeliefConfidenceTrend.falling,
      BeliefTimelineTrend.stable => BeliefConfidenceTrend.stable,
      BeliefTimelineTrend.unknown => BeliefConfidenceTrend.stable,
    };

    final trendLabel = LivingArchiveCopy.beliefTrendLabel(trend);

    final evidence = archiveEligibleEvidenceEntries(
      entries,
    ).reversed.take(4).map((e) => e.id).toList();

    return BeliefUnderReview(
      belief: belief,
      confidencePercent: percent,
      trend: trend,
      trendLabel: trendLabel,
      evidenceIds: evidence,
    );
  }
}