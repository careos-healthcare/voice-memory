import '../record/record_empty_archive_gates.dart';

/// Which archive proof / guidance cards may appear below the recorder on Record.
class RecordProofStackDecision {
  const RecordProofStackDecision({
    required this.showEarlyRepeatProgress,
    required this.showEarlyFirstSignalCard,
    required this.showEarlyEvidenceTimeline,
    required this.showPatternChanged,
    required this.showArchiveSummary,
    required this.showDailyReturnReason,
    required this.showWeeklyArchiveWeekReview,
    required this.showPrivateArchiveReport,
    required this.showConfirmedRepeatWhyMatters,
    required this.showConfirmedRepeatThoughtMap,
    required this.showPositiveReinforcement,
    required this.showHelpfulActionAppeared,
    required this.showChangeProof,
    required this.showFirstWeekLoop,
    required this.showProBridge,
    required this.showArchiveCurrentBelief,
    required this.proofCardCount,
  });

  final bool showEarlyRepeatProgress;
  final bool showEarlyFirstSignalCard;
  final bool showEarlyEvidenceTimeline;
  final bool showPatternChanged;
  final bool showArchiveSummary;
  final bool showArchiveCurrentBelief;
  final bool showDailyReturnReason;
  final bool showWeeklyArchiveWeekReview;
  final bool showPrivateArchiveReport;
  final bool showConfirmedRepeatWhyMatters;
  final bool showConfirmedRepeatThoughtMap;
  final bool showPositiveReinforcement;
  final bool showHelpfulActionAppeared;
  final bool showChangeProof;
  final bool showFirstWeekLoop;
  final bool showProBridge;

  /// Proof / guidance cards rendered below the recorder (excludes beta feedback).
  final int proofCardCount;

  static const empty = RecordProofStackDecision(
    showEarlyRepeatProgress: false,
    showEarlyFirstSignalCard: false,
    showEarlyEvidenceTimeline: false,
    showPatternChanged: false,
    showArchiveSummary: false,
    showDailyReturnReason: false,
    showWeeklyArchiveWeekReview: false,
    showPrivateArchiveReport: false,
    showConfirmedRepeatWhyMatters: false,
    showConfirmedRepeatThoughtMap: false,
    showPositiveReinforcement: false,
    showHelpfulActionAppeared: false,
    showChangeProof: false,
    showFirstWeekLoop: false,
    showProBridge: false,
    showArchiveCurrentBelief: false,
    proofCardCount: 0,
  );
}

/// Capture-first Record ready-state card limits.
abstract final class RecordProofStackPolicy {
  RecordProofStackPolicy._();

  static const maxProofCardsAtThreePlus = 3;
  static const maxProofCardsEarly = 1;

  static RecordProofStackDecision decide({
    required bool loaded,
    required int entryCount,
    required bool isReady,
    required bool isPostSave,
    required bool isRecording,
    required bool archiveSummaryVisible,
    required bool hasEarlyFirstSignal,
    required bool hasEarlyEvidenceTimeline,
    required bool patternChangedVisible,
    required bool dailyReturnReasonEligible,
    required bool weeklyReviewEligible,
    required bool privateReportEligible,
    required bool whyMattersEligible,
    required bool thoughtMapEligible,
    required bool positiveReinforcementEligible,
    bool helpfulActionAppearedEligible = false,
    required bool changeProofEligible,
    required bool firstWeekLoopEligible,
    required bool proBridgeEligible,
    bool archiveCurrentBeliefEligible = false,
  }) {
    if (!loaded || !isReady || isRecording || isPostSave) {
      return RecordProofStackDecision.empty;
    }

    final useSummaryOverview = archiveSummaryVisible && entryCount >= 3;

    // Entry 1–2: one early progress card only — not the legacy receipt card.
    if (entryCount >= 1 && entryCount <= 2) {
      final showProgress = RecordEmptyArchiveGates.showEarlyFirstSignalCard(
        loaded: loaded,
        entryCount: entryCount,
        isPostSave: isPostSave,
      );
      return RecordProofStackDecision(
        showEarlyRepeatProgress: showProgress,
        showEarlyFirstSignalCard: false,
        showEarlyEvidenceTimeline: false,
        showPatternChanged: false,
        showArchiveSummary: false,
        showDailyReturnReason: false,
        showWeeklyArchiveWeekReview: false,
        showPrivateArchiveReport: false,
        showConfirmedRepeatWhyMatters: false,
        showConfirmedRepeatThoughtMap: false,
        showPositiveReinforcement: false,
        showHelpfulActionAppeared: false,
        showChangeProof: false,
        showFirstWeekLoop: false,
        showProBridge: false,
        showArchiveCurrentBelief: false,
        proofCardCount: showProgress ? 1 : 0,
      );
    }

    if (entryCount < 3) {
      return RecordProofStackDecision.empty;
    }

    // Entry 3+: current belief or Archive Summary is the main overview.
    var showPatternChanged = patternChangedVisible;
    var showHelpfulActionAppeared = helpfulActionAppearedEligible;
    var showPositiveReinforcement =
        positiveReinforcementEligible && !showHelpfulActionAppeared;
    var showArchiveCurrentBelief = archiveCurrentBeliefEligible;
    var showArchiveSummary = useSummaryOverview && !showArchiveCurrentBelief;
    var showDailyReturnReason =
        dailyReturnReasonEligible && !useSummaryOverview;
    var showFirstWeekLoop = firstWeekLoopEligible;
    var showProBridge = proBridgeEligible;
    var dailyReturnCompetesForCap = dailyReturnReasonEligible &&
        useSummaryOverview &&
        firstWeekLoopEligible;

    if (useSummaryOverview) {
      showDailyReturnReason = false;
    }

    var count = 0;
    if (showPatternChanged) count++;
    if (showHelpfulActionAppeared) count++;
    if (showArchiveSummary) count++;
    if (showArchiveCurrentBelief) count++;
    if (showDailyReturnReason) count++;
    if (dailyReturnCompetesForCap) count++;
    if (showFirstWeekLoop) count++;
    if (showProBridge) count++;
    if (showPositiveReinforcement) count++;

    // Never more than three proof cards below the recorder.
    while (count > maxProofCardsAtThreePlus) {
      if (showProBridge) {
        showProBridge = false;
        count--;
      } else if (showArchiveSummary && showPatternChanged) {
        showArchiveSummary = false;
        count--;
      } else if (showArchiveSummary && showHelpfulActionAppeared) {
        showArchiveSummary = false;
        count--;
      } else if (showFirstWeekLoop && showPatternChanged) {
        showFirstWeekLoop = false;
        count--;
      } else if (showDailyReturnReason) {
        showDailyReturnReason = false;
        count--;
      } else if (dailyReturnCompetesForCap) {
        dailyReturnCompetesForCap = false;
        count--;
      } else if (showFirstWeekLoop) {
        showFirstWeekLoop = false;
        count--;
      } else {
        break;
      }
    }

    return RecordProofStackDecision(
      showEarlyRepeatProgress: false,
      showEarlyFirstSignalCard:
          entryCount == 3 && hasEarlyFirstSignal && !useSummaryOverview,
      showEarlyEvidenceTimeline:
          hasEarlyEvidenceTimeline && !useSummaryOverview,
      showPatternChanged: showPatternChanged,
      showArchiveSummary: showArchiveSummary,
      showArchiveCurrentBelief: showArchiveCurrentBelief,
      showDailyReturnReason: showDailyReturnReason,
      showWeeklyArchiveWeekReview:
          weeklyReviewEligible && !useSummaryOverview,
      showPrivateArchiveReport:
          privateReportEligible && !useSummaryOverview,
      showConfirmedRepeatWhyMatters:
          whyMattersEligible && !useSummaryOverview,
      showConfirmedRepeatThoughtMap:
          thoughtMapEligible && !useSummaryOverview,
      showPositiveReinforcement: showPositiveReinforcement && !useSummaryOverview,
      showHelpfulActionAppeared:
          showHelpfulActionAppeared && !useSummaryOverview,
      showChangeProof: changeProofEligible &&
          !useSummaryOverview &&
          !showPatternChanged,
      showFirstWeekLoop: showFirstWeekLoop,
      showProBridge: showProBridge,
      proofCardCount: _countVisible(
        showPatternChanged: showPatternChanged,
        showArchiveSummary: showArchiveSummary,
        showArchiveCurrentBelief: showArchiveCurrentBelief,
        showDailyReturnReason: showDailyReturnReason,
        showHelpfulActionAppeared: showHelpfulActionAppeared && !useSummaryOverview,
        showPositiveReinforcement: showPositiveReinforcement && !useSummaryOverview,
        showFirstWeekLoop: showFirstWeekLoop,
        showProBridge: showProBridge,
      ),
    );
  }

  static int _countVisible({
    required bool showPatternChanged,
    required bool showArchiveSummary,
    required bool showArchiveCurrentBelief,
    required bool showDailyReturnReason,
    required bool showHelpfulActionAppeared,
    required bool showPositiveReinforcement,
    required bool showFirstWeekLoop,
    required bool showProBridge,
  }) =>
      (showPatternChanged ? 1 : 0) +
      (showArchiveSummary ? 1 : 0) +
      (showArchiveCurrentBelief ? 1 : 0) +
      (showDailyReturnReason ? 1 : 0) +
      (showHelpfulActionAppeared ? 1 : 0) +
      (showPositiveReinforcement ? 1 : 0) +
      (showFirstWeekLoop ? 1 : 0) +
      (showProBridge ? 1 : 0);
}
