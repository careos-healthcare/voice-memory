part of 'recording_screen.dart';

/// Immutable snapshot of gate/engine outputs for one record screen build.
class RecordBuildContext {
  const RecordBuildContext({
    required this.ui,
    required this.policyMic,
    required this.policyUserDenied,
    required this.firstUseSimplifiedRecord,
    required this.error,
    required this.localSaveTitle,
    required this.syncNote,
    required this.stageLabel,
    required this.entriesAfterSave,
    required this.lastCaptureAnalysisSucceeded,
    required this.canRecord,
    required this.showFraming,
    required this.compact,
    required this.stack,
    required this.suppressPostResultNextCheckCompetitors,
    required this.auditPresentation,
    required this.justSavedFirstEntry,
    required this.postSaveEntryCount,
    required this.suppressNoisyFirstSaveCards,
    required this.suppressEarlyPatternClaimCards,
    required this.suppressLatestSaveArchiveInsight,
    required this.secondSessionPayoff,
    required this.thirdEntryBeliefPayoff,
    required this.confirmedRepeatTriggerPayoff,
    required this.confirmedRepeatHelpfulActionPayoff,
    required this.confirmedRepeatChangeNotice,
    required this.repeatReturnCheckOffer,
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
    required this.firstProofPayoffSeenOnRecord,
    required this.isDegradedTranscriptOnRecord,
    required this.currentRelevanceCandidate,
    required this.patternReviewInboxActiveOnRecord,
    required this.showCurrentRelevanceOnRecordReady,
    required this.currentRelevanceQuestionActiveOnRecord,
    required this.correctionMemoryCandidate,
    required this.showCorrectionMemoryOnRecordReady,
    required this.evidenceWeightingCandidate,
    required this.showEvidenceWeightingOnRecordReady,
    required this.proofSpecificityCandidate,
    required this.showProofSpecificityOnRecordReady,
    required this.presentDayRelevanceCandidate,
    required this.showPresentDayRelevanceOnRecordReady,
    required this.showCaptureFreedomLine,
    required this.timelinePositioningCandidate,
    required this.otherEducationCardsOnRecord,
    required this.showTimelinePositioningOnRecordReady,
    required this.patternConfidenceEducationCount,
    required this.patternConfidenceExplanationCandidate,
    required this.showPatternConfidenceExplanationOnRecordReady,
    required this.showProEvidenceValueOnRecordReady,
    required this.showProBridgeVisibilityOnRecordReady,
    required this.showProEvidenceValuePrivateReportOnRecord,
    required this.showConfirmedRepeatWhyMattersOnRecord,
    required this.showConfirmedRepeatThoughtMapOnRecord,
    required this.showPositiveReinforcementOnRecord,
    required this.showHelpfulActionAppearedOnRecord,
    required this.showChangeProofOnRecord,
    required this.showFirstWeekLoopOnRecord,
    required this.firstProofPayoffCandidate,
    required this.showFirstProofPayoff,
    required this.threeDayChallengeCandidate,
    required this.showThreeDayChallengeOnRecord,
    required this.firstProofPatternConfidence,
    required this.firstProofTruthProofKey,
    required this.showFirstProofTruth,
    required this.firstProofTruthAnswer,
    required this.showFirstProofActionLoop,
    required this.firstProofActionLoopContent,
    required this.showFirstProofMoment,
    required this.postSaveHasConfirmedRepeat,
    required this.postSaveHasFirstProof,
    required this.postSaveDegraded,
    required this.showCoreValueFeedbackOnRecordPostFirstProof,
    required this.returnCheckPayoffCandidate,
    required this.whatChangedV2Prompt,
    required this.whatChangedV2Display,
    required this.showWhatChangedV2,
    required this.showWhatChangedV2Display,
    required this.showOpenCapturePromptChips,
    required this.showLowFrictionReturnCard,
    required this.firstMomentCaptureCandidate,
    required this.firstSaveLiftCandidate,
    required this.firstSessionCaptureRepairCandidate,
    required this.openingRepairOverride,
    required this.showFirstSessionCaptureRepairCard,
    required this.firstSessionLiftCandidate,
    required this.showFirstSessionLiftCard,
    required this.showFirstSaveLiftCard,
    required this.showFirstMomentCaptureCard,
    required this.secondMomentReturnCandidate,
    required this.showSecondMomentReturnCard,
    required this.threeMomentCompletionCandidate,
    required this.showThreeMomentCompletionCard,
    required this.firstRunPositioningCandidate,
    required this.showFirstRunPositioningCard,
    required this.betaTodaySummaryCandidate,
    required this.showBetaTodaySummaryCard,
    required this.archiveTimelineSpineCandidate,
    required this.whatToNoticeNextCandidate,
    required this.showWhatToNoticeNextCard,
    required this.showArchiveTimelineSpineOnRecord,
    required this.suppressLegacyEducationCardsForSpineOnRecord,
    required this.timelineProofMomentCandidate,
    required this.showTimelineProofMomentOnRecord,
    required this.betaTesterReportCandidate,
    required this.showBetaTesterReportOnRecord,
    required this.notRelevantRecoveryCandidate,
    required this.proofQualityResponseTimelineCandidate,
    required this.proofQualityResponseSpineCandidate,
    required this.betaProofLiftTimelineCandidate,
    required this.returnAfterProofRecordCandidate,
    required this.showReturnAfterProofStrengthenedOnRecordReady,
    required this.showReturnAfterProofGenericOnRecordReady,
    required this.showReturnAfterProofOnRecordReady,
    required this.returnAfterProofLiftV2Candidate,
    required this.showReturnAfterProofLiftV2OnRecordReady,
    required this.recordLoosenSignalsPreAudit,
    required this.recordEvidenceAnchorPreAudit,
    required this.recordFeedbackStateForLift,
    required this.timelineFeedbackType,
    required this.betaRepairLabInput,
    required this.showBetaRepairLabProPlacementOnRecord,
    required this.betaRepairLabProPlacementResult,
    required this.showBetaRepairLabPricingValueFramingOnRecord,
    required this.betaRepairLabPricingValueFramingResult,
    required this.showBetaRepairLabPaywallValueOnRecord,
    required this.betaRepairLabPaywallValueResult,
    required this.hasProEngagementOnRecord,
    required this.showBetaRepairLabPricingValidationOnRecord,
    required this.showBetaRepairLabEvidenceTrailClarityOnRecord,
    required this.betaRepairLabPricingValidationResult,
    required this.proUnderstandingLiftRecordReadyInput,
    required this.showProUnderstandingLiftOnRecordReady,
    required this.showProVisibilityLiftOnRecordReady,
    required this.proUnderstandingLiftRecordReadyResult,
    required this.proVisibilityLiftRecordReadyResult,
    required this.showProofQualityResponseOnRecordReady,
    required this.showNotRelevantRecoveryOnRecordReady,
    required this.showBetaProofLiftOnRecordReady,
    required this.betaActivationPathPreAuditContext,
    required this.betaActivationPathPreAuditResult,
    required this.showBetaActivationPathCard,
    required this.betaActivationPathResult,
    required this.betaFeedbackCaptureRecordReadyPreAudit,
    required this.showBetaFeedbackCaptureRecordReady,
    required this.betaFeedbackCaptureRecordReadyResult,
    required this.betaProofFeedbackCounts,
    required this.betaProofFeedbackRowVisibleOnTimeline,
    required this.proofQualityRepairInput,
    required this.showProofQualityRepairOnRecord,
    required this.proofQualityRepairResult,
    required this.proofFloorRescueInput,
    required this.showProofFloorRescueOnRecord,
    required this.proofFloorRescueResult,
    required this.blocksProByProofFloorOnRecord,
    required this.showBetaRepairLabProofOnRecord,
    required this.betaRepairLabProofResult,
    required this.blocksProCardsByProofProtectionOnRecord,
    required this.betaRepairLabEvidenceTrailClarityResult,
    required this.recordReadySurfacePriority,
    required this.shareableNonPrivateProofResult,
    required this.showShareableNonPrivateProofOnRecord,
    required this.proofSpecificityBoostCandidate,
    required this.timelineProofParentVisible,
    required this.showProofSpecificityBoostOnTimelineProof,
    required this.showProofQualityResponseUnderTimelineProof,
    required this.showProofQualityResponseUnderArchiveSpine,
    required this.showNotRelevantRecoveryUnderTimelineProof,
    required this.showBetaProofLiftUnderTimelineProof,
    required this.showReturnAfterProofLiftV2BelowProofOnRecord,
    required this.showReturnAfterProofLiftV2InGuidanceStack,
    required this.showReturnAfterProofBelowProofOnRecord,
    required this.showReturnAfterProofInGuidanceStack,
    required this.showProUnderstandingLiftBelowProofOnRecord,
    required this.showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord,
    required this.showBetaRepairLabPricingValidationBelowProofOnRecord,
    required this.showBetaRepairLabPricingValueFramingBelowProofOnRecord,
    required this.showBetaRepairLabPaywallValueBelowProofOnRecord,
    required this.showBetaRepairLabProPlacementBelowProofOnRecord,
    required this.showProUnderstandingLiftInProSectionOnRecord,
    required this.showProVisibilityLiftBelowProofOnRecord,
    required this.showProVisibilityLiftInProSectionOnRecord,
    required this.showProBridgeBelowProofOnRecord,
    required this.showProBridgeInProSectionOnRecord,
    required this.proBridgeVisibilityRecordResult,
    required this.patternReviewInboxActivePostSave,
    required this.timelineProofMomentPostSaveCandidate,
    required this.showTimelineProofMomentOnFirstProofPayoff,
    required this.proofSpecificityPostSaveCandidate,
    required this.showProofSpecificityOnFirstProofPayoff,
    required this.proofSpecificityBoostPostSaveCandidate,
    required this.proofQualityResponseFirstProofCandidate,
    required this.proofQualityResponseTimelinePostSaveCandidate,
    required this.betaProofLiftFirstProofCandidate,
    required this.betaProofLiftTimelinePostSaveCandidate,
    required this.returnAfterProofPostSaveCandidate,
    required this.firstProofPayoffParentVisible,
    required this.showProofSpecificityBoostOnFirstProofPayoff,
    required this.showProofQualityResponseOnFirstProofPayoff,
    required this.timelineProofPostSaveParentVisible,
    required this.showProofSpecificityBoostOnTimelineProofPostSave,
    required this.showProofQualityResponseOnTimelineProofPostSave,
    required this.showBetaProofLiftOnFirstProofPayoff,
    required this.showBetaProofLiftUnderTimelineProofPostSave,
    required this.showReturnAfterProofStrengthenedOnFirstProofPayoff,
    required this.showReturnAfterProofGenericOnFirstProofPayoff,
    required this.showReturnAfterProofOnFirstProofPayoff,
    required this.returnAfterProofLiftV2PostSaveCandidate,
    required this.showReturnAfterProofLiftV2OnPostSave,
    required this.postSaveLoosenSignalsPreAudit,
    required this.postSaveEvidenceAnchorPreAudit,
    required this.postSaveFeedbackStateForLift,
    required this.hasProEngagementOnPostSave,
    required this.proUnderstandingLiftPostSaveInput,
    required this.showProUnderstandingLiftOnPostSave,
    required this.proUnderstandingLiftPostSaveResult,
    required this.showProVisibilityLiftOnPostSave,
    required this.proVisibilityLiftPostSaveResult,
    required this.showProEvidenceValuePostSave,
    required this.showBetaInviteLoopPostSave,
    required this.showProPreviewPostSave,
    required this.showProBridgeVisibilityPostSave,
    required this.showProLockMomentPostSave,
    required this.monthlyPrivateReportPreviewPostSave,
    required this.showMonthlyPrivateReportPreviewPostSave,
    required this.betaFeedbackRecordSurfaces,
    required this.betaFeedbackIntelligenceSurfaceOnRecordReady,
    required this.betaFeedbackIntelligenceSurfacePostSave,
    required this.helpedTrackingPrompt,
    required this.showHelpedTracking,
    required this.showReturnCheckPayoff,
    required this.showArchiveSummaryOnRecord,
    required this.lowEvidenceGuidance,
    required this.quietSignalCandidate,
    required this.showQuietSignalOnRecord,
    required this.showLowEvidenceGuidanceOnRecord,
    required this.dailyArchiveMemoryCandidate,
    required this.firstProofLoopActive,
    required this.showDailyArchiveMemory,
    required this.showReturningWatchTargetFocusedUi,
    required this.recordReadyShowsWatchTargetOnly,
    required this.recordReadySuppressStreakPressure,
    required this.betaTestScriptCardCandidate,
    required this.showBetaTestScriptCard,
    required this.daysSinceLastEntry,
    required this.showReturnedAfterDelayRecovery,
    required this.nextBestActionCandidate,
    required this.showNextBestActionOnRecord,
    required this.postSaveReturnHandoffCandidate,
    required this.returnTomorrowCuePostSave,
    required this.postSaveDegradedForReturnCue,
    required this.comeBackTomorrowV2PostSaveWatch,
    required this.showComeBackTomorrowV2PostSave,
    required this.showPostSaveCuriosityHook,
    required this.betaFeedbackCapturePostSavePreAudit,
    required this.showBetaFeedbackCapturePostSave,
    required this.betaFeedbackCapturePostSaveResult,
    required this.postSaveProofFloorRescueInput,
    required this.blocksProByProofFloorOnPostSave,
    required this.recordPostSaveSurfacePriority,
    required this.proPreviewPostSaveResult,
    required this.betaInviteLoopPostSaveResult,
    required this.proBridgeVisibilityPostSaveResult,
    required this.showReturnTomorrowCuePostSave,
    required this.firstWeekProgressPostSave,
    required this.showFirstWeekProgressPostSave,
    required this.showPostSaveReturnHandoff,
    required this.beliefUpdatePayoff,
    required this.journalShareProof,
    required this.shareableProof,
    required this.returnLoopPayoff,
    required this.postSaveDailyMirror,
    required this.postSaveArchiveHierarchy,
    required this.suppressNoisyRepeatPostSaveCards,
    required this.repeatPostSaveThoughtMapPreview,
    required this.showDegradedTranscriptFocusedPostSave,
    required this.suppressDegradedTranscriptPostSaveCompetitors,
    required this.returningUserToday,
    required this.nextMomentPrompt,
    required this.dailyArchiveExercise,
    required this.todaysOneQuestion,
    required this.recordHomeSurface,
    required this.showArchiveProgressCards,
    required this.readyCapturePolicy,
    required this.showTesterMission,
    required this.testerMissionCompact,
    required this.showTesterMissionFull,
    required this.testerMission,
    required this.showThoughtMapRecordCta,
    required this.showPositiveReinforcementRecordCta,
    required this.showPatternChangedRecordCta,
    required this.showArchiveSummaryRecordCta,
    required this.showDailyReturnReasonRecordCta,
    required this.showFirstWeekLoopRecordCta,
    required this.bottomInset,
    required this.showFirstSessionOnboarding,
    required this.showFirstUseWordingHelper,
    required this.showCloseButton,
  });

  final RecordUiState ui;
  final RecordingPhase policyMic;
  final bool policyUserDenied;
  final bool firstUseSimplifiedRecord;
  final String? error;
  final String? localSaveTitle;
  final String? syncNote;
  final String stageLabel;
  final List<JournalEntry> entriesAfterSave;
  final bool lastCaptureAnalysisSucceeded;
  final bool canRecord;
  final bool showFraming;
  final bool compact;
  final RecordStackDecision stack;
  final bool suppressPostResultNextCheckCompetitors;
  final RecordAuditPresentation? auditPresentation;
  final bool justSavedFirstEntry;
  final int postSaveEntryCount;
  final bool suppressNoisyFirstSaveCards;
  final bool suppressEarlyPatternClaimCards;
  final bool suppressLatestSaveArchiveInsight;
  final SecondSessionPayoff? secondSessionPayoff;
  final ThirdEntryBeliefPayoff? thirdEntryBeliefPayoff;
  final ConfirmedRepeatTriggerPayoff? confirmedRepeatTriggerPayoff;
  final ConfirmedRepeatHelpfulActionPayoff? confirmedRepeatHelpfulActionPayoff;
  final ConfirmedRepeatChangeNotice? confirmedRepeatChangeNotice;
  final RepeatReturnCheckOffer? repeatReturnCheckOffer;
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
  final bool firstProofPayoffSeenOnRecord;
  final bool isDegradedTranscriptOnRecord;
  final CurrentRelevanceState? currentRelevanceCandidate;
  final bool patternReviewInboxActiveOnRecord;
  final bool showCurrentRelevanceOnRecordReady;
  final bool currentRelevanceQuestionActiveOnRecord;
  final CorrectionMemoryResult? correctionMemoryCandidate;
  final bool showCorrectionMemoryOnRecordReady;
  final EvidenceWeightingResult? evidenceWeightingCandidate;
  final bool showEvidenceWeightingOnRecordReady;
  final ProofSpecificityResult proofSpecificityCandidate;
  final bool showProofSpecificityOnRecordReady;
  final PresentDayRelevanceResult? presentDayRelevanceCandidate;
  final bool showPresentDayRelevanceOnRecordReady;
  final bool showCaptureFreedomLine;
  final TimelinePositioningResult timelinePositioningCandidate;
  final int otherEducationCardsOnRecord;
  final bool showTimelinePositioningOnRecordReady;
  final int patternConfidenceEducationCount;
  final PatternConfidenceExplanationResult? patternConfidenceExplanationCandidate;
  final bool showPatternConfidenceExplanationOnRecordReady;
  final bool showProEvidenceValueOnRecordReady;
  final bool showProBridgeVisibilityOnRecordReady;
  final bool showProEvidenceValuePrivateReportOnRecord;
  final bool showConfirmedRepeatWhyMattersOnRecord;
  final bool showConfirmedRepeatThoughtMapOnRecord;
  final bool showPositiveReinforcementOnRecord;
  final bool showHelpfulActionAppearedOnRecord;
  final bool showChangeProofOnRecord;
  final bool showFirstWeekLoopOnRecord;
  final FirstProofPayoff? firstProofPayoffCandidate;
  final bool showFirstProofPayoff;
  final ThreeDayChallengeState? threeDayChallengeCandidate;
  final bool showThreeDayChallengeOnRecord;
  final PatternConfidence? firstProofPatternConfidence;
  final String firstProofTruthProofKey;
  final bool showFirstProofTruth;
  final FirstProofTruthAnswer? firstProofTruthAnswer;
  final bool showFirstProofActionLoop;
  final FirstProofActionLoopContent? firstProofActionLoopContent;
  final bool showFirstProofMoment;
  final bool postSaveHasConfirmedRepeat;
  final bool postSaveHasFirstProof;
  final bool postSaveDegraded;
  final bool showCoreValueFeedbackOnRecordPostFirstProof;
  final ReturnCheckPayoff? returnCheckPayoffCandidate;
  final WhatChangedV2Prompt? whatChangedV2Prompt;
  final WhatChangedV2Prompt? whatChangedV2Display;
  final bool showWhatChangedV2;
  final bool showWhatChangedV2Display;
  final bool showOpenCapturePromptChips;
  final bool showLowFrictionReturnCard;
  final FirstMomentCaptureResult firstMomentCaptureCandidate;
  final FirstSaveLiftResult firstSaveLiftCandidate;
  final FirstSessionCaptureRepairResult firstSessionCaptureRepairCandidate;
  final FirstSessionCaptureRepairResult? openingRepairOverride;
  final bool showFirstSessionCaptureRepairCard;
  final FirstSessionLiftResult firstSessionLiftCandidate;
  final bool showFirstSessionLiftCard;
  final bool showFirstSaveLiftCard;
  final bool showFirstMomentCaptureCard;
  final SecondMomentReturnResult secondMomentReturnCandidate;
  final bool showSecondMomentReturnCard;
  final ThreeMomentCompletionResult threeMomentCompletionCandidate;
  final bool showThreeMomentCompletionCard;
  final FirstRunPositioningResult firstRunPositioningCandidate;
  final bool showFirstRunPositioningCard;
  final BetaTodaySummaryResult betaTodaySummaryCandidate;
  final bool showBetaTodaySummaryCard;
  final ArchiveTimelineSpineResult? archiveTimelineSpineCandidate;
  final WhatToNoticeNextResult whatToNoticeNextCandidate;
  final bool showWhatToNoticeNextCard;
  final bool showArchiveTimelineSpineOnRecord;
  final bool suppressLegacyEducationCardsForSpineOnRecord;
  final TimelineProofMomentResult? timelineProofMomentCandidate;
  final bool showTimelineProofMomentOnRecord;
  final BetaTesterReportResult betaTesterReportCandidate;
  final bool showBetaTesterReportOnRecord;
  final NotRelevantRecoveryResult notRelevantRecoveryCandidate;
  final ProofQualityResponseResult proofQualityResponseTimelineCandidate;
  final ProofQualityResponseResult proofQualityResponseSpineCandidate;
  final BetaProofLiftResult betaProofLiftTimelineCandidate;
  final ReturnAfterProofResult returnAfterProofRecordCandidate;
  final bool showReturnAfterProofStrengthenedOnRecordReady;
  final bool showReturnAfterProofGenericOnRecordReady;
  final bool showReturnAfterProofOnRecordReady;
  final ReturnAfterProofLiftV2Result returnAfterProofLiftV2Candidate;
  final bool showReturnAfterProofLiftV2OnRecordReady;
  final ProBridgeTimingLoosenSignals recordLoosenSignalsPreAudit;
  final EvidenceAnchorExtractionResult recordEvidenceAnchorPreAudit;
  final ProofQualityFeedbackState recordFeedbackStateForLift;
  final BetaProofFeedbackType? timelineFeedbackType;
  final BetaRepairLabVisibilityInput betaRepairLabInput;
  final bool showBetaRepairLabProPlacementOnRecord;
  final BetaRepairLabProPlacementResult betaRepairLabProPlacementResult;
  final bool showBetaRepairLabPricingValueFramingOnRecord;
  final PricingValueFramingResult betaRepairLabPricingValueFramingResult;
  final bool showBetaRepairLabPaywallValueOnRecord;
  final PaywallValueRepairResult betaRepairLabPaywallValueResult;
  final bool hasProEngagementOnRecord;
  final bool showBetaRepairLabPricingValidationOnRecord;
  final bool showBetaRepairLabEvidenceTrailClarityOnRecord;
  final PricingValidationResult betaRepairLabPricingValidationResult;
  final ProUnderstandingLiftVisibilityInput proUnderstandingLiftRecordReadyInput;
  final bool showProUnderstandingLiftOnRecordReady;
  final bool showProVisibilityLiftOnRecordReady;
  final ProUnderstandingLiftResult? proUnderstandingLiftRecordReadyResult;
  final ProVisibilityLiftResult? proVisibilityLiftRecordReadyResult;
  final bool showProofQualityResponseOnRecordReady;
  final bool showNotRelevantRecoveryOnRecordReady;
  final bool showBetaProofLiftOnRecordReady;
  final BetaActivationPathContext betaActivationPathPreAuditContext;
  final BetaActivationPathResult betaActivationPathPreAuditResult;
  final bool showBetaActivationPathCard;
  final BetaActivationPathResult? betaActivationPathResult;
  final BetaFeedbackCaptureResult betaFeedbackCaptureRecordReadyPreAudit;
  final bool showBetaFeedbackCaptureRecordReady;
  final BetaFeedbackCaptureResult? betaFeedbackCaptureRecordReadyResult;
  final dynamic betaProofFeedbackCounts;
  final bool betaProofFeedbackRowVisibleOnTimeline;
  final ProofQualityRepairVisibilityInput proofQualityRepairInput;
  final bool showProofQualityRepairOnRecord;
  final ProofQualityRepairResult proofQualityRepairResult;
  final ProofFloorRescueInput proofFloorRescueInput;
  final bool showProofFloorRescueOnRecord;
  final ProofFloorRescueResult proofFloorRescueResult;
  final bool blocksProByProofFloorOnRecord;
  final bool showBetaRepairLabProofOnRecord;
  final BetaRepairLabProofResult betaRepairLabProofResult;
  final bool blocksProCardsByProofProtectionOnRecord;
  final EvidenceTrailClarityResult betaRepairLabEvidenceTrailClarityResult;
  final SurfacePriorityResult? recordReadySurfacePriority;
  final ShareableProofResult shareableNonPrivateProofResult;
  final bool showShareableNonPrivateProofOnRecord;
  final ProofSpecificityBoostResult proofSpecificityBoostCandidate;
  final bool timelineProofParentVisible;
  final bool showProofSpecificityBoostOnTimelineProof;
  final bool showProofQualityResponseUnderTimelineProof;
  final bool showProofQualityResponseUnderArchiveSpine;
  final bool showNotRelevantRecoveryUnderTimelineProof;
  final bool showBetaProofLiftUnderTimelineProof;
  final bool showReturnAfterProofLiftV2BelowProofOnRecord;
  final bool showReturnAfterProofLiftV2InGuidanceStack;
  final bool showReturnAfterProofBelowProofOnRecord;
  final bool showReturnAfterProofInGuidanceStack;
  final bool showProUnderstandingLiftBelowProofOnRecord;
  final bool showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord;
  final bool showBetaRepairLabPricingValidationBelowProofOnRecord;
  final bool showBetaRepairLabPricingValueFramingBelowProofOnRecord;
  final bool showBetaRepairLabPaywallValueBelowProofOnRecord;
  final bool showBetaRepairLabProPlacementBelowProofOnRecord;
  final bool showProUnderstandingLiftInProSectionOnRecord;
  final bool showProVisibilityLiftBelowProofOnRecord;
  final bool showProVisibilityLiftInProSectionOnRecord;
  final bool showProBridgeBelowProofOnRecord;
  final bool showProBridgeInProSectionOnRecord;
  final ProBridgeVisibilityResult? proBridgeVisibilityRecordResult;
  final bool patternReviewInboxActivePostSave;
  final TimelineProofMomentResult? timelineProofMomentPostSaveCandidate;
  final bool showTimelineProofMomentOnFirstProofPayoff;
  final ProofSpecificityResult proofSpecificityPostSaveCandidate;
  final bool showProofSpecificityOnFirstProofPayoff;
  final ProofSpecificityBoostResult proofSpecificityBoostPostSaveCandidate;
  final ProofQualityResponseResult proofQualityResponseFirstProofCandidate;
  final ProofQualityResponseResult proofQualityResponseTimelinePostSaveCandidate;
  final BetaProofLiftResult betaProofLiftFirstProofCandidate;
  final BetaProofLiftResult betaProofLiftTimelinePostSaveCandidate;
  final ReturnAfterProofResult returnAfterProofPostSaveCandidate;
  final bool firstProofPayoffParentVisible;
  final bool showProofSpecificityBoostOnFirstProofPayoff;
  final bool showProofQualityResponseOnFirstProofPayoff;
  final bool timelineProofPostSaveParentVisible;
  final bool showProofSpecificityBoostOnTimelineProofPostSave;
  final bool showProofQualityResponseOnTimelineProofPostSave;
  final bool showBetaProofLiftOnFirstProofPayoff;
  final bool showBetaProofLiftUnderTimelineProofPostSave;
  final bool showReturnAfterProofStrengthenedOnFirstProofPayoff;
  final bool showReturnAfterProofGenericOnFirstProofPayoff;
  final bool showReturnAfterProofOnFirstProofPayoff;
  final ReturnAfterProofLiftV2Result returnAfterProofLiftV2PostSaveCandidate;
  final bool showReturnAfterProofLiftV2OnPostSave;
  final ProBridgeTimingLoosenSignals postSaveLoosenSignalsPreAudit;
  final EvidenceAnchorExtractionResult postSaveEvidenceAnchorPreAudit;
  final ProofQualityFeedbackState postSaveFeedbackStateForLift;
  final bool hasProEngagementOnPostSave;
  final ProUnderstandingLiftVisibilityInput proUnderstandingLiftPostSaveInput;
  final bool showProUnderstandingLiftOnPostSave;
  final ProUnderstandingLiftResult? proUnderstandingLiftPostSaveResult;
  final bool showProVisibilityLiftOnPostSave;
  final ProVisibilityLiftResult? proVisibilityLiftPostSaveResult;
  final bool showProEvidenceValuePostSave;
  final bool showBetaInviteLoopPostSave;
  final bool showProPreviewPostSave;
  final bool showProBridgeVisibilityPostSave;
  final bool showProLockMomentPostSave;
  final MonthlyPrivateReportPreview? monthlyPrivateReportPreviewPostSave;
  final bool showMonthlyPrivateReportPreviewPostSave;
  final List<BetaFeedbackIntelligenceSurface> betaFeedbackRecordSurfaces;
  final BetaFeedbackIntelligenceSurface? betaFeedbackIntelligenceSurfaceOnRecordReady;
  final BetaFeedbackIntelligenceSurface? betaFeedbackIntelligenceSurfacePostSave;
  final HelpedTrackingPrompt? helpedTrackingPrompt;
  final bool showHelpedTracking;
  final bool showReturnCheckPayoff;
  final bool showArchiveSummaryOnRecord;
  final LowEvidenceGuidance? lowEvidenceGuidance;
  final QuietSignal? quietSignalCandidate;
  final bool showQuietSignalOnRecord;
  final bool showLowEvidenceGuidanceOnRecord;
  final DailyArchiveMemoryResult? dailyArchiveMemoryCandidate;
  final bool firstProofLoopActive;
  final bool showDailyArchiveMemory;
  final bool showReturningWatchTargetFocusedUi;
  final bool recordReadyShowsWatchTargetOnly;
  final bool recordReadySuppressStreakPressure;
  final BetaTestScriptCompactCard? betaTestScriptCardCandidate;
  final bool showBetaTestScriptCard;
  final int? daysSinceLastEntry;
  final bool showReturnedAfterDelayRecovery;
  final NextBestActionResult? nextBestActionCandidate;
  final bool showNextBestActionOnRecord;
  final PostSaveReturnHandoff? postSaveReturnHandoffCandidate;
  final ReturnTomorrowCue? returnTomorrowCuePostSave;
  final bool postSaveDegradedForReturnCue;
  final ComeBackTomorrowPostSaveWatch? comeBackTomorrowV2PostSaveWatch;
  final bool showComeBackTomorrowV2PostSave;
  final bool showPostSaveCuriosityHook;
  final BetaFeedbackCaptureResult betaFeedbackCapturePostSavePreAudit;
  final bool showBetaFeedbackCapturePostSave;
  final BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveResult;
  final ProofFloorRescueInput postSaveProofFloorRescueInput;
  final bool blocksProByProofFloorOnPostSave;
  final SurfacePriorityResult? recordPostSaveSurfacePriority;
  final ProPreviewResult? proPreviewPostSaveResult;
  final BetaInviteLoopResult? betaInviteLoopPostSaveResult;
  final ProBridgeVisibilityResult? proBridgeVisibilityPostSaveResult;
  final bool showReturnTomorrowCuePostSave;
  final FirstWeekProgress? firstWeekProgressPostSave;
  final bool showFirstWeekProgressPostSave;
  final bool showPostSaveReturnHandoff;
  final BeliefUpdatePayoff? beliefUpdatePayoff;
  final ShareableArchiveProof? journalShareProof;
  final ShareableArchiveProof? shareableProof;
  final DayTwoReturnLoopPayoff? returnLoopPayoff;
  final DailyMirrorResult? postSaveDailyMirror;
  final PostSaveArchiveHierarchy? postSaveArchiveHierarchy;
  final bool suppressNoisyRepeatPostSaveCards;
  final ArchiveThoughtMapPreview? repeatPostSaveThoughtMapPreview;
  final bool showDegradedTranscriptFocusedPostSave;
  final bool suppressDegradedTranscriptPostSaveCompetitors;
  final ReturningUserToday? returningUserToday;
  final NextMomentPrompt? nextMomentPrompt;
  final DailyArchiveExerciseResult? dailyArchiveExercise;
  final TodaysQuestionResult? todaysOneQuestion;
  final RecordHomeSurfacePolicy recordHomeSurface;
  final bool showArchiveProgressCards;
  final RecordCtaPolicyResolution readyCapturePolicy;
  final bool showTesterMission;
  final bool testerMissionCompact;
  final bool showTesterMissionFull;
  final TesterMissionResult? testerMission;
  final bool showThoughtMapRecordCta;
  final bool showPositiveReinforcementRecordCta;
  final bool showPatternChangedRecordCta;
  final bool showArchiveSummaryRecordCta;
  final bool showDailyReturnReasonRecordCta;
  final bool showFirstWeekLoopRecordCta;
  final double bottomInset;
  final bool showFirstSessionOnboarding;
  final bool showFirstUseWordingHelper;
  final bool showCloseButton;
}
