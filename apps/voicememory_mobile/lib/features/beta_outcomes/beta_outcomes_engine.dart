import '../../models/journal_entry.dart';
import '../archive_depth/archive_depth_engine.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../beta_feedback/beta_feedback_models.dart';
import '../beta_invite/beta_invite_engine.dart';
import '../beta_invite/beta_invite_models.dart';
import '../demo/sample_archive_mode.dart';
import '../pro_interest/pro_interest_copy.dart';
import '../pro_interest/pro_interest_engine.dart';
import '../pro_interest/pro_interest_models.dart';
import '../first_week_path/first_week_path_engine.dart';
import '../first_week_path/first_week_path_models.dart';
import '../pressure_retention/shareable_archive_proof_engine.dart';
import '../archive_clarity/archive_clarity_engine.dart';
import '../archive_clarity/archive_clarity_models.dart';
import '../then_now/then_now_copy.dart';
import '../then_now/then_now_engine.dart';
import '../archive_calendar/archive_calendar_copy.dart';
import '../archive_calendar/archive_calendar_engine.dart';
import 'beta_outcomes_copy.dart';
import 'beta_outcomes_models.dart';

/// Deterministic beta outcomes builder — read-only local signals.
class BetaOutcomesEngine {
  const BetaOutcomesEngine({
    this.firstWeekPathEngine = const FirstWeekPathEngine(),
    this.archiveClarityEngine = const ArchiveClarityEngine(),
    this.thenNowEngine = const ThenNowEngine(),
    this.archiveCalendarEngine = const ArchiveCalendarEngine(),
  });

  final FirstWeekPathEngine firstWeekPathEngine;
  final ArchiveClarityEngine archiveClarityEngine;
  final ThenNowEngine thenNowEngine;
  final ArchiveCalendarEngine archiveCalendarEngine;

  BetaOutcomesSnapshot buildFromJournal({
    required List<JournalEntry> entries,
    required int watchThemesCount,
    required bool returnRitualSet,
    required BetaFeedbackState feedbackState,
    required ProInterestState proInterestState,
    BetaInviteCopyStats betaInviteCopyStats = BetaInviteCopyStats.empty,
    ShareableArchiveProofEngine proofEngine =
        const ShareableArchiveProofEngine(),
    bool hasWatchTheme = false,
    bool hasWeeklyReviewAvailable = false,
  }) {
    final realEntries = _realEntries(entries);
    final depth = const ArchiveDepthEngine().build(entries: realEntries);
    final usableCount = ArchiveEvidenceGuard.eligibleReflectionCount(realEntries);
    final shareProofReady =
        proofEngine.buildFromJournal(entries: realEntries).hasProof;
    final firstWeekPath = firstWeekPathEngine.build(
      FirstWeekPathInput(
        realSavedMomentCount: realEntries.length,
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: feedbackState.hasResponse,
        hasWeeklyReviewAvailable: hasWeeklyReviewAvailable,
      ),
    );
    final clarity = archiveClarityEngine.build(
      ArchiveClarityInput(
        realSavedMomentCount: realEntries.length,
        usableEvidenceCount: usableCount,
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: feedbackState.hasResponse,
        weeklyReviewAvailable: hasWeeklyReviewAvailable,
      ),
    );
    final thenNow = thenNowEngine.buildFromJournal(entries: realEntries);
    final archiveCalendar =
        archiveCalendarEngine.buildFromJournal(entries: realEntries);

    return build(
      BetaOutcomesInput(
        savedMomentCount: realEntries.length,
        usableEvidenceCount: usableCount,
        depthLevelLabel: depth.levelLabel,
        watchThemesCount: watchThemesCount,
        returnRitualSet: returnRitualSet,
        feedbackState: feedbackState,
        shareProofReady: shareProofReady,
        proInterestState: proInterestState,
        betaInviteCopyStats: betaInviteCopyStats,
        firstWeekPathProgressLabel: firstWeekPath.progressLabel,
        archiveClarityStageLabel: clarity.stageLabel,
        thenVsNowAvailableLabel: thenNow.hasCard
            ? ThenNowCopy.betaOutcomesYes
            : ThenNowCopy.betaOutcomesNo,
        archiveCalendarAvailableLabel: archiveCalendar.hasCard
            ? ArchiveCalendarCopy.betaOutcomesYes
            : ArchiveCalendarCopy.betaOutcomesNo,
      ),
    );
  }

  BetaOutcomesSnapshot build(BetaOutcomesInput input) {
    final feedbackStatus = BetaOutcomesCopy.feedbackStatusFor(input.feedbackState);
    final proInterest = input.proInterestState;
    final proInterestInterpretations =
        const ProInterestEngine().interpretations(proInterest);
    final inviteSummary =
        const BetaInviteEngine().outcomesSummary(input.betaInviteCopyStats);
    return BetaOutcomesSnapshot(
      savedMomentCount: input.savedMomentCount,
      usableEvidenceCount: input.usableEvidenceCount,
      depthLevelLabel: input.depthLevelLabel,
      watchThemesCount: input.watchThemesCount,
      returnRitualSet: input.returnRitualSet,
      feedbackStatusLabel: feedbackStatus,
      optionalNotePresent: input.feedbackState.note?.trim().isNotEmpty == true,
      testimonialCopied: input.feedbackState.testimonialCopied,
      shareProofReady: input.shareProofReady,
      interpretations: [
        ..._interpretations(input),
        ...proInterestInterpretations,
      ],
      feedbackState: input.feedbackState,
      proInterestCaptured: proInterest.hasCapture,
      selectedProValueCount: proInterest.selectedValueIds.length,
      proInterestPricingLabel:
          ProInterestCopy.labelForPricing(proInterest.pricingIntentId),
      proInterestNotePresent: proInterest.optionalNotePresent,
      proInterestInterpretations: proInterestInterpretations,
      proInterestState: proInterest,
      betaInviteCopiedCount: inviteSummary.totalCopiedCount,
      betaInviteLastVariantLabel: inviteSummary.lastVariantLabel,
      betaInviteTaskCopied: inviteSummary.testerTaskCopied,
      firstWeekPathProgressLabel: input.firstWeekPathProgressLabel,
      archiveClarityStageLabel: input.archiveClarityStageLabel,
      thenVsNowAvailableLabel: input.thenVsNowAvailableLabel,
      archiveCalendarAvailableLabel: input.archiveCalendarAvailableLabel,
    );
  }

  static List<String> _interpretations(BetaOutcomesInput input) {
    final lines = <String>[];
    final count = input.savedMomentCount;
    final feedback = input.feedbackState;

    if (count <= 2) {
      lines.add(BetaOutcomesCopy.interpretationNotEnoughEvidence);
    } else {
      if (!feedback.hasResponse) {
        lines.add(BetaOutcomesCopy.interpretationReadyForFeedback);
      }
      if (feedback.usefulness == BetaFeedbackUsefulness.useful ||
          feedback.clarity == BetaFeedbackClarity.understood) {
        lines.add(BetaOutcomesCopy.interpretationEarlyValue);
      }
      if (feedback.usefulness == BetaFeedbackUsefulness.notYet ||
          feedback.clarity == BetaFeedbackClarity.confused) {
        lines.add(BetaOutcomesCopy.interpretationClarityRisk);
      }
    }

    if (count >= 5) {
      lines.add(BetaOutcomesCopy.interpretationArchiveLoop);
    }
    if (count >= 10) {
      lines.add(BetaOutcomesCopy.interpretationLongTerm);
    }

    return lines;
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) =>
      SampleArchiveMode.excludeSampleEntries(entries)
          .where(
            (e) =>
                e.transcript.trim().isNotEmpty &&
                !e.transcript.startsWith('[draft]'),
          )
          .toList();
}
