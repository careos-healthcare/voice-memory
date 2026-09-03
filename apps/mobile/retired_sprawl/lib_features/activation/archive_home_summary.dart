import 'package:archiveme_mobile/features/activation/belief_update_payoff.dart';
import 'package:archiveme_mobile/features/activation/context_aware_archive_copy.dart';
import 'package:archiveme_mobile/features/activation/next_moment_prompt.dart';
import 'package:archiveme_mobile/features/activation/third_entry_belief_payoff.dart';
import 'package:archiveme_mobile/features/activation/weekly_archive_review.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_threshold.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/archive_tab/archive_tab_four_state_copy.dart';
import 'package:archiveme_mobile/features/archive_tab/archive_tab_four_state_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Ladder stage for the Archive Home command center.
enum ArchiveHomeStage { empty, one, two, three, four, fivePlus }

/// Primary navigation action for Archive Home CTAs.
enum ArchiveHomeAction {
  none,
  record,
  typeInstead,
  addMoment,
  viewArchive,
  viewEvidence,
  viewReview,
}

/// User-facing copy constants for Archive Home.
abstract final class ArchiveHomeSummaryCopy {
  static const String emptyTitle =
      VisibleArchiveProofCopy.archiveHomeEmptyTitle;

  static const String emptyBody = VisibleArchiveProofCopy.archiveHomeEmptyBody;

  static const String recordCta = VisibleArchiveProofCopy.archiveHomeRecordCta;

  static const String typeInsteadCta =
      VisibleArchiveProofCopy.archiveHomeTypeInsteadCta;

  static const String oneTitle = VisibleArchiveProofCopy.archiveHomeOneTitle;

  static const String beliefLabel =
      VisibleArchiveProofCopy.archiveHomeBeliefLabel;

  static const String whatChangedLabel =
      VisibleArchiveProofCopy.archiveHomeWhatChangedLabel;

  static const String evidenceLabel =
      VisibleArchiveProofCopy.archiveHomeEvidenceLabel;

  static const String nextActionLabel =
      VisibleArchiveProofCopy.archiveHomeNextActionLabel;

  static const String viewReviewCta =
      VisibleArchiveProofCopy.archiveHomeViewReviewCta;
}

/// Central Archive Home summary — adapts by usable entry count.
class ArchiveHomeSummary {
  const ArchiveHomeSummary({
    required this.stage,
    required this.title,
    required this.body,
    this.subtitle,
    this.footnoteLine,
    this.contextAwareSummaryLine,
    this.contextAwareDetailLine,
    this.currentBeliefLine,
    this.whatChangedLine,
    this.evidenceRows = const [],
    this.sourceEntryIds = const [],
    this.nextActionLine,
    this.primaryCta,
    this.secondaryCta,
    this.primaryAction = ArchiveHomeAction.none,
    this.secondaryAction = ArchiveHomeAction.none,
    this.suppressDuplicatePayoffCards = false,
    this.showShareProof = false,
  });

  final ArchiveHomeStage stage;
  final String title;
  final String body;
  final String? subtitle;
  final String? footnoteLine;
  final String? contextAwareSummaryLine;
  final String? contextAwareDetailLine;
  final String? currentBeliefLine;
  final String? whatChangedLine;
  final List<String> evidenceRows;
  final List<String> sourceEntryIds;
  final String? nextActionLine;
  final String? primaryCta;
  final String? secondaryCta;
  final ArchiveHomeAction primaryAction;
  final ArchiveHomeAction secondaryAction;
  final bool suppressDuplicatePayoffCards;
  final bool showShareProof;
}

/// Builds Archive Home from eligible entry count and existing engines.
abstract final class ArchiveHomeSummaryEngine {
  ArchiveHomeSummaryEngine._();

  static String? _nextActionLine(List<JournalEntry> entries) =>
      NextMomentPromptEngine.build(entries: entries)?.nextActionSummary;

  static ArchiveHomeSummary build({required List<JournalEntry> entries}) {
    return _applyContextAware(_buildSummary(entries: entries), entries);
  }

  static ArchiveHomeSummary _buildSummary({
    required List<JournalEntry> entries,
  }) {
    final eligibleCount = ArchiveEvidenceGuard.eligibleReflectionCount(entries);

    if (eligibleCount == 0) {
      return const ArchiveHomeSummary(
        stage: ArchiveHomeStage.empty,
        title: '',
        body: ArchiveTabFourStateCopy.emptyBody,
        primaryCta: ArchiveTabFourStateCopy.recordMomentCta,
        primaryAction: ArchiveHomeAction.record,
      );
    }

    if (eligibleCount == 1) {
      return const ArchiveHomeSummary(
        stage: ArchiveHomeStage.one,
        title: '',
        body: ArchiveTabFourStateCopy.oneBody,
        suppressDuplicatePayoffCards: true,
      );
    }

    if (eligibleCount == 2) {
      final fourState = ArchiveTabFourStateEngine.build(entries: entries);
      if (fourState != null) {
        return ArchiveHomeSummary(
          stage: ArchiveHomeStage.two,
          title: '',
          body: fourState.body,
          primaryCta: fourState.primaryCta,
          primaryAction: fourState.primaryAction,
          suppressDuplicatePayoffCards: true,
        );
      }
    }

    if (eligibleCount == 3) {
      final payoff = ThirdEntryBeliefPayoffEngine.build(entries: entries);
      if (payoff == null) {
        return const ArchiveHomeSummary(
          stage: ArchiveHomeStage.three,
          title: ArchiveEvidenceThreshold.formingTitle,
          body: ArchiveEvidenceThreshold.formingBody,
          footnoteLine:
              VisibleArchiveProofCopy.firstRunBeliefsNotConclusionsLine,
          currentBeliefLine:
              VisibleArchiveProofCopy.patternsEmptyPreviewBeliefRow,
          whatChangedLine:
              VisibleArchiveProofCopy.patternsEmptyPreviewChangedRow,
          nextActionLine:
              VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta,
          primaryCta: VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta,
          secondaryCta: VisibleArchiveProofCopy.typeInsteadCta,
          primaryAction: ArchiveHomeAction.addMoment,
          secondaryAction: ArchiveHomeAction.typeInstead,
          suppressDuplicatePayoffCards: true,
        );
      }
      return ArchiveHomeSummary(
        stage: ArchiveHomeStage.three,
        title: payoff.title,
        body: payoff.bodyIntro,
        footnoteLine: payoff.bodySource,
        currentBeliefLine:
            VisibleArchiveProofCopy.threeEntryBeliefCurrentBeliefLine,
        whatChangedLine:
            payoff.thinEvidenceNote ??
            VisibleArchiveProofCopy.threeEntryBeliefEvidenceThin,
        evidenceRows: payoff.evidenceRows,
        sourceEntryIds: payoff.sourceEntryIds,
        nextActionLine:
            _nextActionLine(entries) ??
            payoff.thinEvidenceAction ??
            VisibleArchiveProofCopy.threeEntryBeliefEvidenceThinAction,
        primaryCta: VisibleArchiveProofCopy.threeEntryBeliefPrimaryCta,
        secondaryCta: VisibleArchiveProofCopy.threeEntryBeliefViewArchiveCta,
        primaryAction: ArchiveHomeAction.addMoment,
        secondaryAction: ArchiveHomeAction.viewArchive,
        suppressDuplicatePayoffCards: true,
      );
    }

    if (eligibleCount == 4) {
      final payoff = BeliefUpdatePayoffEngine.build(entries: entries);
      if (payoff == null) {
        return const ArchiveHomeSummary(
          stage: ArchiveHomeStage.four,
          title: ArchiveEvidenceThreshold.formingTitle,
          body: ArchiveEvidenceThreshold.formingBody,
          footnoteLine:
              VisibleArchiveProofCopy.firstRunBeliefsNotConclusionsLine,
          currentBeliefLine:
              VisibleArchiveProofCopy.patternsEmptyPreviewBeliefRow,
          whatChangedLine:
              VisibleArchiveProofCopy.patternsEmptyPreviewChangedRow,
          nextActionLine:
              VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta,
          primaryCta: VisibleArchiveProofCopy.firstSavePrimaryCta,
          secondaryCta: VisibleArchiveProofCopy.typeInsteadCta,
          primaryAction: ArchiveHomeAction.addMoment,
          secondaryAction: ArchiveHomeAction.typeInstead,
          suppressDuplicatePayoffCards: true,
        );
      }
      return ArchiveHomeSummary(
        stage: ArchiveHomeStage.four,
        title: payoff.title,
        body: payoff.body,
        currentBeliefLine: payoff.currentBelief,
        whatChangedLine: payoff.whatChangedLine,
        evidenceRows: payoff.evidenceRows,
        sourceEntryIds: payoff.sourceEntryIds,
        nextActionLine: _nextActionLine(entries) ?? payoff.primaryCta,
        primaryCta: VisibleArchiveProofCopy.firstSavePrimaryCta,
        secondaryCta: VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta,
        primaryAction: ArchiveHomeAction.addMoment,
        secondaryAction: ArchiveHomeAction.viewEvidence,
        suppressDuplicatePayoffCards: true,
      );
    }

    final review = WeeklyArchiveReviewEngine.build(entries: entries);
    final shareProof = const ShareableArchiveProofEngine().buildFromJournal(
      entries: entries,
    );
    return ArchiveHomeSummary(
      stage: ArchiveHomeStage.fivePlus,
      title: review.title,
      subtitle: review.subtitle,
      body:
          review.strongestThreadLine ??
          review.subtitle ??
          VisibleArchiveProofCopy.weeklyArchiveReviewSubtitle,
      footnoteLine: review.notConclusionLine,
      currentBeliefLine: review.strongestThreadLine,
      whatChangedLine: review.whatChangedLine,
      evidenceRows: review.evidenceRows,
      sourceEntryIds: review.sourceEntryIds,
      nextActionLine: _nextActionLine(entries) ?? review.nextActionLine,
      primaryCta: ArchiveHomeSummaryCopy.viewReviewCta,
      secondaryCta: VisibleArchiveProofCopy.firstSavePrimaryCta,
      primaryAction: ArchiveHomeAction.viewReview,
      secondaryAction: ArchiveHomeAction.addMoment,
      suppressDuplicatePayoffCards: true,
      showShareProof: shareProof.hasProof,
    );
  }

  static ArchiveHomeSummary _applyContextAware(
    ArchiveHomeSummary summary,
    List<JournalEntry> entries,
  ) {
    final contextCopy = ContextAwareArchiveCopyEngine.build(entries: entries);
    if (!contextCopy.showLines) return summary;
    return ArchiveHomeSummary(
      stage: summary.stage,
      title: summary.title,
      body: summary.body,
      subtitle: summary.subtitle,
      footnoteLine: summary.footnoteLine,
      contextAwareSummaryLine: contextCopy.summaryLine,
      contextAwareDetailLine: contextCopy.detailLine,
      currentBeliefLine: summary.currentBeliefLine,
      whatChangedLine: summary.whatChangedLine,
      evidenceRows: summary.evidenceRows,
      sourceEntryIds: summary.sourceEntryIds,
      nextActionLine: summary.nextActionLine,
      primaryCta: summary.primaryCta,
      secondaryCta: summary.secondaryCta,
      primaryAction: summary.primaryAction,
      secondaryAction: summary.secondaryAction,
      suppressDuplicatePayoffCards: summary.suppressDuplicatePayoffCards,
      showShareProof: summary.showShareProof,
    );
  }
}
