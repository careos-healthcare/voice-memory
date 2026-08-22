import 'package:archiveme_mobile/features/activation/archive_health_score.dart';
import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/activation/context_aware_archive_copy.dart';
import 'package:archiveme_mobile/features/activation/next_moment_prompt.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Navigation action for archive health action plan CTAs.
enum ArchiveHealthActionPlanCta { addMoment, viewEvidence }

/// Local-only action plan derived from archive health status.
class ArchiveHealthActionPlan {
  const ArchiveHealthActionPlan({
    required this.showCard,
    required this.title,
    required this.subtitle,
    required this.actionItems,
    required this.primaryCta,
    required this.primaryAction,
    this.secondaryCta,
    this.secondaryAction,
    this.contextAwareSummaryLine,
    this.contextAwareDetailLine,
  });

  factory ArchiveHealthActionPlan.hidden() => const ArchiveHealthActionPlan(
    showCard: false,
    title: VisibleArchiveProofCopy.archiveHealthActionPlanTitle,
    subtitle: VisibleArchiveProofCopy.archiveHealthActionPlanSubtitle,
    actionItems: [],
    primaryCta: VisibleArchiveProofCopy.firstSavePrimaryCta,
    primaryAction: ArchiveHealthActionPlanCta.addMoment,
  );

  final bool showCard;
  final String title;
  final String subtitle;
  final List<String> actionItems;
  final String primaryCta;
  final ArchiveHealthActionPlanCta primaryAction;
  final String? secondaryCta;
  final ArchiveHealthActionPlanCta? secondaryAction;
  final String? contextAwareSummaryLine;
  final String? contextAwareDetailLine;
}

/// Builds a compact action plan from archive health and local feedback.
abstract final class ArchiveHealthActionPlanEngine {
  ArchiveHealthActionPlanEngine._();

  static const _maxActionItems = 3;

  static ArchiveHealthActionPlan build({required List<JournalEntry> entries}) {
    final health = ArchiveHealthScoreEngine.build(entries: entries);
    if (!health.showCard) {
      return ArchiveHealthActionPlan.hidden();
    }

    final items = <String>[];
    _addStageAction(items, health.stage);

    if (_hasDuplicateIssue(health)) {
      items.add(VisibleArchiveProofCopy.archiveHealthActionDuplicates);
    } else if (CaptureContextTagAnalysis.allTaggedSameContext(entries)) {
      items.add(VisibleArchiveProofCopy.archiveHealthActionDuplicates);
    }
    if (health.excludedEntryCount > 0) {
      items.add(VisibleArchiveProofCopy.archiveHealthActionExcluded);
    }
    if (_hasCorrectionFeedback()) {
      items.add(VisibleArchiveProofCopy.archiveHealthActionCorrection);
    }

    final actionItems = _dedupePreserveOrder(
      items,
    ).take(_maxActionItems).toList();
    final nextPrompt = NextMomentPromptEngine.build(entries: entries);
    final ctas = _ctasFor(
      usableCount: health.usableMomentCount,
      nextPrompt: nextPrompt,
    );
    final contextCopy = ContextAwareArchiveCopyEngine.build(entries: entries);
    final contextLines = _contextSupportLines(
      contextCopy: contextCopy,
      entries: entries,
    );

    return ArchiveHealthActionPlan(
      showCard: actionItems.isNotEmpty,
      title: VisibleArchiveProofCopy.archiveHealthActionPlanTitle,
      subtitle: VisibleArchiveProofCopy.archiveHealthActionPlanSubtitle,
      actionItems: actionItems,
      primaryCta: ctas.$1,
      primaryAction: ArchiveHealthActionPlanCta.addMoment,
      secondaryCta: ctas.$2,
      secondaryAction: ctas.$3,
      contextAwareSummaryLine: contextLines.$1,
      contextAwareDetailLine: contextLines.$2,
    );
  }

  static (String?, String?) _contextSupportLines({
    required ContextAwareArchiveCopy contextCopy,
    required List<JournalEntry> entries,
  }) {
    if (!contextCopy.showLines) return (null, null);
    if (CaptureContextTagAnalysis.allTaggedSameContext(entries)) {
      return (contextCopy.summaryLine, null);
    }
    return (contextCopy.summaryLine, contextCopy.detailLine);
  }

  static void _addStageAction(List<String> items, ArchiveHealthStage stage) {
    switch (stage) {
      case ArchiveHealthStage.hidden:
        break;
      case ArchiveHealthStage.thin:
        items.add(VisibleArchiveProofCopy.archiveHealthActionOneEntry);
      case ArchiveHealthStage.startingToCompare:
        items.add(VisibleArchiveProofCopy.archiveHealthActionTwoEntries);
      case ArchiveHealthStage.firstBeliefReady:
        items.add(VisibleArchiveProofCopy.archiveHealthActionThreeEntries);
      case ArchiveHealthStage.beliefUpdateReady:
        items.add(VisibleArchiveProofCopy.archiveHealthActionFourEntries);
      case ArchiveHealthStage.reviewReady:
        items.add(VisibleArchiveProofCopy.archiveHealthActionFivePlus);
    }
  }

  static bool _hasDuplicateIssue(ArchiveHealthScore health) {
    if (health.duplicateEntryCount > 0) return true;
    return health.needsMoreEvidenceLines.contains(
          VisibleArchiveProofCopy.archiveHealthDuplicateLine,
        ) ||
        health.needsMoreEvidenceLines.contains(
          VisibleArchiveProofCopy.archiveHealthNearDuplicateLine,
        );
  }

  static bool _hasCorrectionFeedback() {
    return ArchiveInsightFeedbackStore.totalNotQuiteCount() > 0 ||
        ArchiveInsightFeedbackStore.correctionNoteCount() > 0;
  }

  static (String, String?, ArchiveHealthActionPlanCta?) _ctasFor({
    required int usableCount,
    required NextMomentPrompt? nextPrompt,
  }) {
    final primary =
        nextPrompt?.primaryCta ??
        VisibleArchiveProofCopy.archiveHealthActionPlanPrimaryCta;
    if (usableCount >= 4) {
      return (
        primary,
        nextPrompt?.secondaryCta ??
            VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta,
        ArchiveHealthActionPlanCta.viewEvidence,
      );
    }
    return (primary, null, null);
  }

  static List<String> _dedupePreserveOrder(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      if (seen.add(item)) out.add(item);
    }
    return out;
  }
}