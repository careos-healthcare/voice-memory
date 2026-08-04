import '../../core/config/v1_feature_flags.dart';
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_proof/visible_archive_proof_copy.dart';
import '../pressure_retention/shareable_archive_proof_model.dart';
import 'archive_evidence_map.dart';
import 'archive_home_summary.dart';
import 'archive_insight_feedback.dart';
import 'archive_workspace_layout.dart';
import 'insight_quality_dashboard.dart';
import 'weekly_archive_review.dart';

/// Quick action kinds for the Archive/Patterns workspace.
enum ArchiveWorkspaceQuickActionKind {
  tagUntagged,
  reviewCorrections,
  viewWeeklyReview,
  viewEvidenceMap,
  addMoment,
  shareProofSafely,
}

/// Navigation target for a workspace quick action.
enum ArchiveWorkspaceQuickActionDestination {
  record,
  untaggedDrilldown,
  insightQuality,
  archiveBelief,
  weeklyReview,
  shareProof,
}

/// One compact quick action in the Archive workspace.
class ArchiveWorkspaceQuickAction {
  const ArchiveWorkspaceQuickAction({
    required this.kind,
    required this.label,
    required this.destination,
  });

  final ArchiveWorkspaceQuickActionKind kind;
  final String label;
  final ArchiveWorkspaceQuickActionDestination destination;

  String? resolveRoute() {
    switch (destination) {
      case ArchiveWorkspaceQuickActionDestination.record:
        return '/record';
      case ArchiveWorkspaceQuickActionDestination.untaggedDrilldown:
        return ArchiveEvidenceMapNavigation.contextPath(
          ArchiveEvidenceMapRowIds.untagged,
        );
      case ArchiveWorkspaceQuickActionDestination.insightQuality:
        return InsightQualityNavigation.route;
      case ArchiveWorkspaceQuickActionDestination.archiveBelief:
        return '/archive-belief';
      case ArchiveWorkspaceQuickActionDestination.weeklyReview:
        return WeeklyArchiveReviewNavigation.route;
      case ArchiveWorkspaceQuickActionDestination.shareProof:
        return null;
    }
  }
}

/// Compact next-step actions for Archive/Patterns.
class ArchiveWorkspaceQuickActions {
  const ArchiveWorkspaceQuickActions({
    required this.showCard,
    required this.title,
    this.actions = const [],
  });

  final bool showCard;
  final String title;
  final List<ArchiveWorkspaceQuickAction> actions;

  factory ArchiveWorkspaceQuickActions.hidden() =>
      const ArchiveWorkspaceQuickActions(
        showCard: false,
        title: VisibleArchiveProofCopy.archiveWorkspaceQuickActionsTitle,
      );
}

/// Builds deterministic quick actions from archive state.
abstract final class ArchiveWorkspaceQuickActionsEngine {
  ArchiveWorkspaceQuickActionsEngine._();

  static const maxVisibleActions = 3;

  static const _priorityOrder = <ArchiveWorkspaceQuickActionKind>[
    ArchiveWorkspaceQuickActionKind.tagUntagged,
    ArchiveWorkspaceQuickActionKind.reviewCorrections,
    ArchiveWorkspaceQuickActionKind.viewWeeklyReview,
    ArchiveWorkspaceQuickActionKind.viewEvidenceMap,
    ArchiveWorkspaceQuickActionKind.addMoment,
    ArchiveWorkspaceQuickActionKind.shareProofSafely,
  ];

  static ArchiveWorkspaceQuickActions build({
    required List<JournalEntry> entries,
    required ArchiveHomeSummary archiveHome,
    required ArchiveWorkspaceLayout workspaceLayout,
    required bool evidenceMapVisible,
    WeeklyArchiveReview? weeklyReview,
    ShareableArchiveProof? shareProof,
  }) {
    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);
    if (eligibleCount <= 0) {
      return ArchiveWorkspaceQuickActions.hidden();
    }

    final untaggedCount = _untaggedCount(entries);
    final hasCorrections = _hasCorrections();
    final actions = <ArchiveWorkspaceQuickAction>[];

    for (final kind in _priorityOrder) {
      if (!_isEligible(
        kind: kind,
        eligibleCount: eligibleCount,
        untaggedCount: untaggedCount,
        hasCorrections: hasCorrections,
        evidenceMapVisible: evidenceMapVisible,
        weeklyReview: weeklyReview,
        archiveHome: archiveHome,
        workspaceLayout: workspaceLayout,
        shareProof: shareProof,
      )) {
        continue;
      }
      actions.add(_actionFor(kind));
      if (actions.length >= maxVisibleActions) break;
    }

    if (actions.isEmpty) {
      return ArchiveWorkspaceQuickActions.hidden();
    }

    return ArchiveWorkspaceQuickActions(
      showCard: true,
      title: VisibleArchiveProofCopy.archiveWorkspaceQuickActionsTitle,
      actions: actions,
    );
  }

  static bool _isEligible({
    required ArchiveWorkspaceQuickActionKind kind,
    required int eligibleCount,
    required int untaggedCount,
    required bool hasCorrections,
    required bool evidenceMapVisible,
    required WeeklyArchiveReview? weeklyReview,
    required ArchiveHomeSummary archiveHome,
    required ArchiveWorkspaceLayout workspaceLayout,
    required ShareableArchiveProof? shareProof,
  }) {
    switch (kind) {
      case ArchiveWorkspaceQuickActionKind.tagUntagged:
        return eligibleCount >= 2 && untaggedCount > 0;
      case ArchiveWorkspaceQuickActionKind.reviewCorrections:
        return V1FeatureFlags.enableCustomReports &&
            eligibleCount >= 3 &&
            hasCorrections;
      case ArchiveWorkspaceQuickActionKind.viewWeeklyReview:
        return V1FeatureFlags.enableCustomReports &&
            eligibleCount >= 5 &&
            (weeklyReview?.hasEnoughEvidence ?? false);
      case ArchiveWorkspaceQuickActionKind.viewEvidenceMap:
        return eligibleCount >= 3 && evidenceMapVisible;
      case ArchiveWorkspaceQuickActionKind.addMoment:
        if (eligibleCount < 2 || eligibleCount > 4) return false;
        return !_homeAlreadyPromptsAddMoment(archiveHome);
      case ArchiveWorkspaceQuickActionKind.shareProofSafely:
        return eligibleCount >= 5 &&
            (shareProof?.hasProof ?? false) &&
            !archiveHome.showShareProof &&
            !workspaceLayout.showStandaloneShareProof;
    }
  }

  static ArchiveWorkspaceQuickAction _actionFor(
    ArchiveWorkspaceQuickActionKind kind,
  ) {
    switch (kind) {
      case ArchiveWorkspaceQuickActionKind.tagUntagged:
        return const ArchiveWorkspaceQuickAction(
          kind: ArchiveWorkspaceQuickActionKind.tagUntagged,
          label: VisibleArchiveProofCopy.archiveWorkspaceQuickActionTagUntagged,
          destination: ArchiveWorkspaceQuickActionDestination.untaggedDrilldown,
        );
      case ArchiveWorkspaceQuickActionKind.reviewCorrections:
        return const ArchiveWorkspaceQuickAction(
          kind: ArchiveWorkspaceQuickActionKind.reviewCorrections,
          label: VisibleArchiveProofCopy
              .archiveWorkspaceQuickActionReviewCorrections,
          destination: ArchiveWorkspaceQuickActionDestination.insightQuality,
        );
      case ArchiveWorkspaceQuickActionKind.viewWeeklyReview:
        return const ArchiveWorkspaceQuickAction(
          kind: ArchiveWorkspaceQuickActionKind.viewWeeklyReview,
          label: VisibleArchiveProofCopy
              .archiveWorkspaceQuickActionViewWeeklyReview,
          destination: ArchiveWorkspaceQuickActionDestination.weeklyReview,
        );
      case ArchiveWorkspaceQuickActionKind.viewEvidenceMap:
        return const ArchiveWorkspaceQuickAction(
          kind: ArchiveWorkspaceQuickActionKind.viewEvidenceMap,
          label: VisibleArchiveProofCopy
              .archiveWorkspaceQuickActionViewEvidenceMap,
          destination: ArchiveWorkspaceQuickActionDestination.archiveBelief,
        );
      case ArchiveWorkspaceQuickActionKind.addMoment:
        return const ArchiveWorkspaceQuickAction(
          kind: ArchiveWorkspaceQuickActionKind.addMoment,
          label: VisibleArchiveProofCopy.archiveWorkspaceQuickActionAddMoment,
          destination: ArchiveWorkspaceQuickActionDestination.record,
        );
      case ArchiveWorkspaceQuickActionKind.shareProofSafely:
        return const ArchiveWorkspaceQuickAction(
          kind: ArchiveWorkspaceQuickActionKind.shareProofSafely,
          label: VisibleArchiveProofCopy
              .archiveWorkspaceQuickActionShareProofSafely,
          destination: ArchiveWorkspaceQuickActionDestination.shareProof,
        );
    }
  }

  static int _untaggedCount(List<JournalEntry> entries) {
    var count = 0;
    for (final entry in ArchiveEvidenceGuard.eligibleEntries(entries)) {
      final tag = entry.captureContextTag;
      if (tag == null || tag.isEmpty) count++;
    }
    return count;
  }

  static bool _hasCorrections() =>
      ArchiveInsightFeedbackStore.totalNotQuiteCount() > 0 ||
      ArchiveInsightFeedbackStore.correctionNoteCount() > 0;

  static bool _homeAlreadyPromptsAddMoment(ArchiveHomeSummary archiveHome) {
    const addLabel = VisibleArchiveProofCopy.firstSavePrimaryCta;
    if (archiveHome.primaryAction == ArchiveHomeAction.addMoment &&
        archiveHome.primaryCta == addLabel) {
      return true;
    }
    if (archiveHome.secondaryAction == ArchiveHomeAction.addMoment &&
        archiveHome.secondaryCta == addLabel) {
      return true;
    }
    return false;
  }
}
