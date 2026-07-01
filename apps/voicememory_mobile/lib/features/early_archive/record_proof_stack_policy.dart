import '../record/record_empty_archive_gates.dart';

/// Which archive proof / guidance cards may appear below the recorder on Record.
class RecordProofStackDecision {
  const RecordProofStackDecision({
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
    required this.showChangeProof,
    required this.showProBridge,
    required this.proofCardCount,
  });

  final bool showEarlyFirstSignalCard;
  final bool showEarlyEvidenceTimeline;
  final bool showPatternChanged;
  final bool showArchiveSummary;
  final bool showDailyReturnReason;
  final bool showWeeklyArchiveWeekReview;
  final bool showPrivateArchiveReport;
  final bool showConfirmedRepeatWhyMatters;
  final bool showConfirmedRepeatThoughtMap;
  final bool showPositiveReinforcement;
  final bool showChangeProof;
  final bool showProBridge;

  /// Proof / guidance cards rendered below the recorder (excludes beta feedback).
  final int proofCardCount;

  static const empty = RecordProofStackDecision(
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
    showChangeProof: false,
    showProBridge: false,
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
    required bool changeProofEligible,
    required bool proBridgeEligible,
  }) {
    if (!loaded || !isReady || isRecording || isPostSave) {
      return RecordProofStackDecision.empty;
    }

    final useSummaryOverview = archiveSummaryVisible && entryCount >= 3;

    // Entry 1–2: one early proof card only.
    if (entryCount >= 1 && entryCount <= 2) {
      final showEarlyFirstSignal = hasEarlyFirstSignal &&
          RecordEmptyArchiveGates.showEarlyFirstSignalCard(
            loaded: loaded,
            entryCount: entryCount,
            isPostSave: isPostSave,
          );
      return RecordProofStackDecision(
        showEarlyFirstSignalCard: showEarlyFirstSignal,
        showEarlyEvidenceTimeline: false,
        showPatternChanged: false,
        showArchiveSummary: false,
        showDailyReturnReason: false,
        showWeeklyArchiveWeekReview: false,
        showPrivateArchiveReport: false,
        showConfirmedRepeatWhyMatters: false,
        showConfirmedRepeatThoughtMap: false,
        showPositiveReinforcement: false,
        showChangeProof: false,
        showProBridge: false,
        proofCardCount: showEarlyFirstSignal ? 1 : 0,
      );
    }

    if (entryCount < 3) {
      return RecordProofStackDecision.empty;
    }

    // Entry 3+: Archive Summary is the main overview; fold supporting cards.
    var showPatternChanged = patternChangedVisible;
    var showArchiveSummary = useSummaryOverview;
    var showDailyReturnReason =
        dailyReturnReasonEligible && !useSummaryOverview;
    var showProBridge = proBridgeEligible;

    if (useSummaryOverview) {
      showDailyReturnReason = false;
    }

    var count = 0;
    if (showPatternChanged) count++;
    if (showArchiveSummary) count++;
    if (showDailyReturnReason) count++;
    if (showProBridge) count++;

    // Never more than three proof cards below the recorder.
    while (count > maxProofCardsAtThreePlus) {
      if (showProBridge) {
        showProBridge = false;
      } else if (showDailyReturnReason) {
        showDailyReturnReason = false;
      } else if (showPatternChanged && showArchiveSummary) {
        showPatternChanged = false;
      } else {
        break;
      }
      count = _countVisible(
        showPatternChanged: showPatternChanged,
        showArchiveSummary: showArchiveSummary,
        showDailyReturnReason: showDailyReturnReason,
        showProBridge: showProBridge,
      );
    }

    return RecordProofStackDecision(
      showEarlyFirstSignalCard: false,
      showEarlyEvidenceTimeline:
          hasEarlyEvidenceTimeline && !useSummaryOverview,
      showPatternChanged: showPatternChanged,
      showArchiveSummary: showArchiveSummary,
      showDailyReturnReason: showDailyReturnReason,
      showWeeklyArchiveWeekReview:
          weeklyReviewEligible && !useSummaryOverview,
      showPrivateArchiveReport:
          privateReportEligible && !useSummaryOverview,
      showConfirmedRepeatWhyMatters:
          whyMattersEligible && !useSummaryOverview,
      showConfirmedRepeatThoughtMap:
          thoughtMapEligible && !useSummaryOverview,
      showPositiveReinforcement:
          positiveReinforcementEligible && !useSummaryOverview,
      showChangeProof: changeProofEligible &&
          !useSummaryOverview &&
          !showPatternChanged,
      showProBridge: showProBridge,
      proofCardCount: count,
    );
  }

  static int _countVisible({
    required bool showPatternChanged,
    required bool showArchiveSummary,
    required bool showDailyReturnReason,
    required bool showProBridge,
  }) =>
      (showPatternChanged ? 1 : 0) +
      (showArchiveSummary ? 1 : 0) +
      (showDailyReturnReason ? 1 : 0) +
      (showProBridge ? 1 : 0);
}
