import 'package:archiveme_mobile/features/activation/archive_evidence_map.dart';
import 'package:archiveme_mobile/features/activation/archive_health_action_plan.dart';
import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_home_summary.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_layout.dart';
import 'package:archiveme_mobile/features/activation/archive_workspace_quick_actions.dart';
import 'package:archiveme_mobile/features/activation/belief_history_timeline.dart';
import 'package:archiveme_mobile/features/activation/context_insights.dart';
import 'package:archiveme_mobile/features/activation/evidence_attention_filters.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/archive/archive_evidence_map_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_health_action_plan_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_health_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_home_summary_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_workspace_quick_actions_card.dart';
import 'package:archiveme_mobile/widgets/archive/archive_workspace_section_heading.dart';
import 'package:archiveme_mobile/widgets/archive/belief_history_timeline_card.dart';
import 'package:archiveme_mobile/widgets/archive/context_insights_card.dart';
import 'package:archiveme_mobile/widgets/archive/evidence_attention_filters_card.dart';
import 'package:archiveme_mobile/widgets/archive/weekly_archive_review_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Builds Archive Home workspace cards from in-memory sample entries only.
abstract final class SampleArchiveWorkspace {
  SampleArchiveWorkspace._();

  static void _showExampleOnly(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(SampleArchiveCopy.exampleOnlySnackbar)),
    );
  }

  static List<Widget> build(
    BuildContext context,
    List<JournalEntry> entries, {
    GlobalKey? evidenceMapKey,
    void Function(String tagId)? onEvidenceMapRowTap,
  }) {
    final summary = ArchiveHomeSummaryEngine.build(entries: entries);
    final layout = _layout(entries, summary);
    final actionPlan = ArchiveHealthActionPlanEngine.build(entries: entries);
    final attentionFilters = EvidenceAttentionFiltersEngine.build(
      entries: entries,
      omitKinds: const {EvidenceAttentionFilterKind.sameContext},
    );
    final archiveHealth = ArchiveHealthScoreEngine.build(entries: entries);
    final contextInsights = ContextInsightsEngine.build(entries: entries);
    final evidenceMap = ArchiveEvidenceMapEngine.build(entries: entries);
    final beliefHistory =
        ArchiveEvidenceGuard.eligibleReflectionCount(entries) >= 5
        ? BeliefHistoryTimelineEngine.build(entries: entries)
        : null;
    final weeklyReview =
        ArchiveEvidenceGuard.eligibleReflectionCount(entries) >= 5
        ? WeeklyArchiveReviewEngine.build(entries: entries)
        : null;
    final quickActions = ArchiveWorkspaceQuickActionsEngine.build(
      entries: entries,
      archiveHome: summary,
      workspaceLayout: layout,
      evidenceMapVisible: evidenceMap.showCard,
      weeklyReview: weeklyReview,
    );

    final widgets = <Widget>[
      ArchiveHomeSummaryCard(
        summary: summary,
        onPrimary: () =>
            _handleArchiveHomeAction(context, summary.primaryAction),
        onSecondary: summary.secondaryAction != ArchiveHomeAction.none
            ? () => _handleArchiveHomeAction(context, summary.secondaryAction)
            : null,
      ),
    ];

    if (quickActions.showCard) {
      widgets.add(const SizedBox(height: AppSpacing.md));
      widgets.add(
        ArchiveWorkspaceQuickActionsCard(
          quickActions: quickActions,
          onActionTap: (action) => _onQuickAction(context, action),
        ),
      );
    }

    if (layout.needsAttention.show) {
      widgets.addAll(_sectionSpacer());
      if (layout.needsAttention.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'needs_attention',
            title: heading,
          ),
        );
      }
      if (layout.showAttentionFilters) {
        widgets.add(
          EvidenceAttentionFiltersCard(
            filters: attentionFilters,
            hideTitle: layout.needsAttention.heading != null,
            onFilterTap: (_) => _showExampleOnly(context),
          ),
        );
        if (layout.showActionPlan) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
      }
      if (layout.showActionPlan) {
        widgets.add(
          ArchiveHealthActionPlanCard(
            plan: actionPlan,
            onPrimary: () => context.go('/record'),
            onSecondary:
                actionPlan.secondaryAction ==
                    ArchiveHealthActionPlanCta.viewEvidence
                ? () => _showExampleOnly(context)
                : null,
          ),
        );
      }
    }

    if (layout.evidenceQuality.show) {
      widgets.addAll(_sectionSpacer());
      if (layout.evidenceQuality.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'evidence_quality',
            title: heading,
          ),
        );
      }
      var addedQualityCard = false;
      void addQualityCard(Widget card) {
        if (addedQualityCard) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
        widgets.add(card);
        addedQualityCard = true;
      }

      if (layout.showArchiveHealth) {
        addQualityCard(ArchiveHealthCard(score: archiveHealth));
      }
      if (layout.showContextInsights) {
        addQualityCard(ContextInsightsCard(insights: contextInsights));
      }
      if (layout.showEvidenceMap) {
        addQualityCard(
          KeyedSubtree(
            key: evidenceMapKey,
            child: ArchiveEvidenceMapCard(
              map: evidenceMap,
              onRowTap: onEvidenceMapRowTap ?? (_) => _showExampleOnly(context),
            ),
          ),
        );
      }
    }

    if (layout.reviewHistory.show) {
      widgets.addAll(_sectionSpacer());
      if (layout.reviewHistory.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(
            sectionId: 'review_history',
            title: heading,
          ),
        );
      }
      if (layout.showBeliefHistory && beliefHistory != null) {
        widgets.add(BeliefHistoryTimelineCard(timeline: beliefHistory));
      }
      if (layout.showWeeklyReview && weeklyReview != null) {
        if (layout.showBeliefHistory) {
          widgets.add(const SizedBox(height: AppSpacing.md));
        }
        widgets.add(
          WeeklyArchiveReviewCard(
            review: weeklyReview,
            compact: true,
            onViewFullReview: () => _showExampleOnly(context),
            onAddAnother: () => context.go('/record'),
          ),
        );
      }
    }

    if (layout.controls.show && layout.showInsightQualityLink) {
      widgets.addAll(_sectionSpacer());
      if (layout.controls.heading case final heading?) {
        widgets.add(
          ArchiveWorkspaceSectionHeading(sectionId: 'controls', title: heading),
        );
      }
      widgets.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('sample_archive_insight_quality_link'),
            onPressed: () => _showExampleOnly(context),
            child: const Text(VisibleArchiveProofCopy.insightQualityArchiveLink),
          ),
        ),
      );
    }

    widgets.add(const SizedBox(height: AppSpacing.lg));
    return widgets;
  }

  static ArchiveWorkspaceLayout _layout(
    List<JournalEntry> entries,
    ArchiveHomeSummary summary,
  ) {
    final beliefHistory =
        ArchiveEvidenceGuard.eligibleReflectionCount(entries) >= 5
        ? BeliefHistoryTimelineEngine.build(entries: entries)
        : null;
    final weeklyReview =
        ArchiveEvidenceGuard.eligibleReflectionCount(entries) >= 5
        ? WeeklyArchiveReviewEngine.build(entries: entries)
        : null;

    return ArchiveWorkspaceLayoutEngine.build(
      entries: entries,
      archiveHome: summary,
      attentionFilters: EvidenceAttentionFiltersEngine.build(
        entries: entries,
        omitKinds: const {EvidenceAttentionFilterKind.sameContext},
      ),
      actionPlan: ArchiveHealthActionPlanEngine.build(entries: entries),
      archiveHealth: ArchiveHealthScoreEngine.build(entries: entries),
      contextInsights: ContextInsightsEngine.build(entries: entries),
      evidenceMap: ArchiveEvidenceMapEngine.build(entries: entries),
      beliefHistory: beliefHistory,
      weeklyReview: weeklyReview,
    );
  }

  static List<Widget> _sectionSpacer() => const [
    SizedBox(height: AppSpacing.lg),
  ];

  static void _handleArchiveHomeAction(
    BuildContext context,
    ArchiveHomeAction action,
  ) {
    switch (action) {
      case ArchiveHomeAction.record:
      case ArchiveHomeAction.addMoment:
        context.go('/record');
      case ArchiveHomeAction.typeInstead:
        unawaited(context.push('/quick-capture'));
      case ArchiveHomeAction.viewArchive:
      case ArchiveHomeAction.viewEvidence:
      case ArchiveHomeAction.viewReview:
        _showExampleOnly(context);
      case ArchiveHomeAction.none:
        break;
    }
  }

  static void _onQuickAction(
    BuildContext context,
    ArchiveWorkspaceQuickAction action,
  ) {
    switch (action.destination) {
      case ArchiveWorkspaceQuickActionDestination.record:
        context.go('/record');
      case ArchiveWorkspaceQuickActionDestination.shareProof:
      case ArchiveWorkspaceQuickActionDestination.untaggedDrilldown:
      case ArchiveWorkspaceQuickActionDestination.insightQuality:
      case ArchiveWorkspaceQuickActionDestination.archiveBelief:
      case ArchiveWorkspaceQuickActionDestination.weeklyReview:
        _showExampleOnly(context);
    }
  }
}