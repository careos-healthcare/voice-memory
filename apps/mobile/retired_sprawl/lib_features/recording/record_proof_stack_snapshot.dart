import 'package:archiveme_mobile/features/recording/recording_dependencies.dart';

/// Outputs of the archive-proof-stack phase of RecordSurfaceResolver.resolve.
final class RecordProofStackSnapshot {
  const RecordProofStackSnapshot({
    required this.earlyEvidenceTimeline,
    required this.showEarlyEvidenceTimeline,
    required this.suppressEarlyRepeatPayoffCompetitors,
    required this.earlyFirstSignalOnRecord,
    required this.returnTomorrowCueReady,
    required this.returnDayFlowCandidate,
    required this.showReturnDayFlow,
    required this.showReturnTomorrowCueReady,
    required this.firstWeekProgressReady,
    required this.showFirstWeekProgressReady,
    required this.showEarlyReturnReminder,
    required this.viewingConfirmedRepeatOnRecord,
    required this.suppressConfirmedRepeatInlineFeedback,
    required this.showConfirmedRepeatBetaFeedback,
    required this.repeatReturnChangeProof,
    required this.patternChangedCandidate,
    required this.patternChangedDismissed,
    required this.confirmedRepeatThoughtMap,
    required this.positivePattern,
    required this.helpfulActionAppearedCandidate,
    required this.showHelpfulActionAppearedEligible,
    required this.positiveReinforcement,
    required this.archiveSummaryCandidate,
    required this.archiveBeliefSurfaceCandidate,
    required this.patternNamePrompt,
    required this.showArchiveCurrentBeliefEligible,
    required this.dailyReturnReasonCandidate,
    required this.hasChangeOverTimeProof,
    required this.postProofArchiveProof,
    required this.archiveSummaryVisibleForProGate,
    required this.weeklyArchiveReviewVisibleForProGate,
    required this.hasConfirmedRepeatForProGate,
    required this.privateArchiveReportForProGate,
    required this.privateArchiveReportPreviewForProGate,
    required this.patternChangedForProGate,
    required this.hasReturnCheckAnsweredForProGate,
    required this.showPostProofProBridge,
    required this.proofSurfaceLayout,
    required this.showArchiveSummary,
    required this.archiveSummary,
    required this.showDailyReturnReason,
    required this.dailyReturnReason,
    required this.archiveWatchingCandidate,
    required this.archiveWatching,
    required this.weeklyArchiveReview,
    required this.showWeeklyArchiveReview,
    required this.privateArchiveReportCandidate,
    required this.showPrivateArchiveReport,
    required this.showConfirmedRepeatWhyMatters,
    required this.showConfirmedRepeatThoughtMap,
    required this.showPositiveReinforcement,
    required this.firstWeekLoopCandidate,
    required this.firstWeekLoopProGated,
    required this.recordProofStack,
    required this.showPatternChanged,
    required this.showArchiveCurrentBeliefOnRecord,
    required this.showEarlyEvidenceTimelineOnRecord,
    required this.showWeeklyArchiveReviewOnRecord,
    required this.showPrivateArchiveReportOnRecord,
    required this.showDailyReturnReasonOnRecord,
    required this.showPostProofProBridgeOnRecord,
  });

  final EarlyEvidenceTimeline? earlyEvidenceTimeline;
  final bool showEarlyEvidenceTimeline;
  final bool suppressEarlyRepeatPayoffCompetitors;
  final EarlyFirstSignalModel? earlyFirstSignalOnRecord;
  final ReturnTomorrowCue? returnTomorrowCueReady;
  final ReturnDayFlow? returnDayFlowCandidate;
  final bool showReturnDayFlow;
  final bool showReturnTomorrowCueReady;
  final FirstWeekProgress? firstWeekProgressReady;
  final bool showFirstWeekProgressReady;
  final bool showEarlyReturnReminder;
  final bool viewingConfirmedRepeatOnRecord;
  final bool suppressConfirmedRepeatInlineFeedback;
  final bool showConfirmedRepeatBetaFeedback;
  final RepeatReturnCheckChangeProof? repeatReturnChangeProof;
  final PatternChangedResult? patternChangedCandidate;
  final bool patternChangedDismissed;
  final ThoughtMapResult? confirmedRepeatThoughtMap;
  final PositivePatternResult? positivePattern;
  final HelpfulActionAppeared? helpfulActionAppearedCandidate;
  final bool showHelpfulActionAppearedEligible;
  final PositiveReinforcementResult? positiveReinforcement;
  final ArchiveSummaryResult? archiveSummaryCandidate;
  final ArchiveBeliefSurface archiveBeliefSurfaceCandidate;
  final PatternNamePrompt? patternNamePrompt;
  final bool showArchiveCurrentBeliefEligible;
  final DailyReturnReasonResult? dailyReturnReasonCandidate;
  final bool hasChangeOverTimeProof;
  final bool postProofArchiveProof;
  final bool archiveSummaryVisibleForProGate;
  final bool weeklyArchiveReviewVisibleForProGate;
  final bool hasConfirmedRepeatForProGate;
  final PrivateArchiveReport? privateArchiveReportForProGate;
  final bool privateArchiveReportPreviewForProGate;
  final bool patternChangedForProGate;
  final bool hasReturnCheckAnsweredForProGate;
  final bool showPostProofProBridge;
  final ArchiveProofSurfaceLayout proofSurfaceLayout;
  final bool showArchiveSummary;
  final ArchiveSummaryResult? archiveSummary;
  final bool showDailyReturnReason;
  final DailyReturnReasonResult? dailyReturnReason;
  final ArchiveWatchingResult? archiveWatchingCandidate;
  final ArchiveWatchingResult? archiveWatching;
  final WeeklyArchiveReviewResult? weeklyArchiveReview;
  final bool showWeeklyArchiveReview;
  final PrivateArchiveReport? privateArchiveReportCandidate;
  final bool showPrivateArchiveReport;
  final bool showConfirmedRepeatWhyMatters;
  final bool showConfirmedRepeatThoughtMap;
  final bool showPositiveReinforcement;
  final FirstWeekLoop? firstWeekLoopCandidate;
  final bool firstWeekLoopProGated;
  final RecordProofStackDecision recordProofStack;
  final bool showPatternChanged;
  final bool showArchiveCurrentBeliefOnRecord;
  final bool showEarlyEvidenceTimelineOnRecord;
  final bool showWeeklyArchiveReviewOnRecord;
  final bool showPrivateArchiveReportOnRecord;
  final bool showDailyReturnReasonOnRecord;
  final bool showPostProofProBridgeOnRecord;
}
