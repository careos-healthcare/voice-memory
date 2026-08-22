import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Workspace ladder stage from usable entry count.
enum ArchiveWorkspaceStage { empty, one, two, evidenceReady, reviewReady }

/// One grouped section in the Archive/Patterns workspace.
class ArchiveWorkspaceSectionLayout {
  const ArchiveWorkspaceSectionLayout({required this.show, this.heading});

  final bool show;
  final String? heading;
}

/// Visibility plan for Archive/Patterns cards and sections.
class ArchiveWorkspaceLayout {
  const ArchiveWorkspaceLayout({
    required this.stage,
    required this.eligibleCount,
    required this.needsAttention,
    required this.evidenceQuality,
    required this.reviewHistory,
    required this.controls,
    required this.showActionPlan,
    required this.showAttentionFilters,
    required this.showArchiveHealth,
    required this.showContextInsights,
    required this.showEvidenceMap,
    required this.showBeliefHistory,
    required this.showWeeklyReview,
    required this.showInsightQualityLink,
    required this.showStandaloneShareProof,
  });

  final ArchiveWorkspaceStage stage;
  final int eligibleCount;
  final ArchiveWorkspaceSectionLayout needsAttention;
  final ArchiveWorkspaceSectionLayout evidenceQuality;
  final ArchiveWorkspaceSectionLayout reviewHistory;
  final ArchiveWorkspaceSectionLayout controls;
  final bool showActionPlan;
  final bool showAttentionFilters;
  final bool showArchiveHealth;
  final bool showContextInsights;
  final bool showEvidenceMap;
  final bool showBeliefHistory;
  final bool showWeeklyReview;
  final bool showInsightQualityLink;
  final bool showStandaloneShareProof;

  bool get includesReviewHistoryInWorkspace =>
      showBeliefHistory || showWeeklyReview;

  bool get includesStandaloneShareProofInWorkspace => showStandaloneShareProof;
}

/// Groups Archive/Patterns surfaces and gates low-priority cards by entry count.
abstract final class ArchiveWorkspaceLayoutEngine {
  ArchiveWorkspaceLayoutEngine._();

  static ArchiveWorkspaceLayout build({
    required List<JournalEntry> entries,
    required ArchiveHomeSummary archiveHome,
    required EvidenceAttentionFilters attentionFilters,
    required ArchiveHealthActionPlan actionPlan,
    required ArchiveHealthScore archiveHealth,
    required ContextInsights contextInsights,
    required ArchiveEvidenceMap evidenceMap,
    BeliefHistoryTimeline? beliefHistory,
    WeeklyArchiveReview? weeklyReview,
    ShareableArchiveProof? shareProof,
  }) {
    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);
    final stage = _stageForCount(eligibleCount);

    final showActionPlan = actionPlan.showCard && eligibleCount >= 2;
    final showAttentionFilters =
        attentionFilters.showCard && eligibleCount >= 2;

    final needsAttentionHeading =
        showAttentionFilters || (showActionPlan && eligibleCount >= 2)
        ? VisibleArchiveProofCopy.archiveWorkspaceNeedsAttentionHeading
        : null;

    final needsAttention = ArchiveWorkspaceSectionLayout(
      show: showActionPlan || showAttentionFilters,
      heading: needsAttentionHeading,
    );

    final showArchiveHealth = archiveHealth.showCard && eligibleCount >= 3;
    final showContextInsights = contextInsights.showCard && eligibleCount >= 3;
    final showEvidenceMap = evidenceMap.showCard && eligibleCount >= 3;

    final evidenceQuality = ArchiveWorkspaceSectionLayout(
      show: showArchiveHealth || showContextInsights || showEvidenceMap,
      heading: (showArchiveHealth || showContextInsights || showEvidenceMap)
          ? VisibleArchiveProofCopy.archiveWorkspaceEvidenceQualityHeading
          : null,
    );

    final showBeliefHistory = eligibleCount >= 5 && beliefHistory != null;
    final showWeeklyReview =
        eligibleCount >= 5 && (weeklyReview?.hasEnoughEvidence ?? false);

    final reviewHistory = ArchiveWorkspaceSectionLayout(
      show: showBeliefHistory || showWeeklyReview,
      heading: (showBeliefHistory || showWeeklyReview)
          ? VisibleArchiveProofCopy.archiveWorkspaceReviewHistoryHeading
          : null,
    );

    final showInsightQualityLink =
        eligibleCount >= 2 || ArchiveInsightFeedbackStore.hasAnyFeedback();
    final showStandaloneShareProof =
        !archiveHome.showShareProof &&
        eligibleCount >= 5 &&
        (shareProof?.hasProof ?? false);

    final controls = ArchiveWorkspaceSectionLayout(
      show: showInsightQualityLink || showStandaloneShareProof,
      heading: (showInsightQualityLink || showStandaloneShareProof)
          ? VisibleArchiveProofCopy.archiveWorkspaceControlsHeading
          : null,
    );

    return ArchiveWorkspaceLayout(
      stage: stage,
      eligibleCount: eligibleCount,
      needsAttention: needsAttention,
      evidenceQuality: evidenceQuality,
      reviewHistory: reviewHistory,
      controls: controls,
      showActionPlan: showActionPlan,
      showAttentionFilters: showAttentionFilters,
      showArchiveHealth: showArchiveHealth,
      showContextInsights: showContextInsights,
      showEvidenceMap: showEvidenceMap,
      showBeliefHistory: showBeliefHistory,
      showWeeklyReview: showWeeklyReview,
      showInsightQualityLink: showInsightQualityLink,
      showStandaloneShareProof: showStandaloneShareProof,
    );
  }

  static ArchiveWorkspaceStage _stageForCount(int eligibleCount) {
    if (eligibleCount <= 0) return ArchiveWorkspaceStage.empty;
    if (eligibleCount == 1) return ArchiveWorkspaceStage.one;
    if (eligibleCount == 2) return ArchiveWorkspaceStage.two;
    if (eligibleCount <= 4) return ArchiveWorkspaceStage.evidenceReady;
    return ArchiveWorkspaceStage.reviewReady;
  }
}