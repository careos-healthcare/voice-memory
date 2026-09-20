import 'package:archiveme_mobile/audio/recording_types.dart';
import 'package:archiveme_mobile/features/beta/tester_mission_model.dart';
import 'package:archiveme_mobile/features/daily_archive_exercise/daily_archive_exercise_models.dart';
import 'package:archiveme_mobile/features/daily_archive_memory/daily_archive_memory_model.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:archiveme_mobile/features/record/record_home_surface_policy.dart';
import 'package:archiveme_mobile/features/record/record_stack_policy.dart';
import 'package:archiveme_mobile/features/recording/record_surface_field_type_exports.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

class RecordSurfaceViewState {
  const RecordSurfaceViewState({
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
    required this.recordReadySurfacePriority,
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
    required this.recordLoosenSignals,
    required this.recordReadyProTiming,
    required this.betaActivationPathFinalContext,
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
    required this.base,
    required this.showProVisibilityLiftOnPostSave,
    required this.proVisibilityLiftPostSaveResult,
    required this.showProEvidenceValuePostSave,
    required this.showBetaInviteLoopPostSave,
    required this.showProPreviewPostSave,
    required this.showProBridgeVisibilityPostSave,
    required this.showProLockMomentPostSave,
    required this.monthlyPrivateReportPreviewPostSave,
    required this.showMonthlyPrivateReportPreviewPostSave,
    required this.betaFeedbackIntelligenceSurfaceOnRecordReady,
    required this.betaFeedbackIntelligenceSurfacePostSave,
    required this.helpedTrackingPrompt,
    required this.showHelpedTracking,
    required this.showReturnCheckPayoff,
    required this.showArchiveSummaryOnRecord,
    required this.confirmedRepeatChangeNoticeOnRecord,
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
    required this.postSaveLoosenSignals,
    required this.postSaveProTiming,
    required this.betaFeedbackCapturePostSaveFinal,
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
    required this.showRecordCaptureModes,
    required this.testerMissionCompact,
    required this.showTesterMissionFull,
    required this.testerMission,
    required this.showThoughtMapRecordCta,
    required this.showPositiveReinforcementRecordCta,
    required this.showPatternChangedRecordCta,
    required this.showArchiveSummaryRecordCta,
    required this.showDailyReturnReasonRecordCta,
    required this.showFirstWeekLoopRecordCta,
  });

  /// Test-only snapshot of every field for characterization testing.
  /// Not a public API -- do not use outside tests.
  @visibleForTesting
  Map<String, Object?> toDebugMap() => {
    'policyMic': _debugSnap(policyMic),
    'policyUserDenied': _debugSnap(policyUserDenied),
    'firstUseSimplifiedRecord': _debugSnap(firstUseSimplifiedRecord),
    'error': _debugSnap(error),
    'localSaveTitle': _debugSnap(localSaveTitle),
    'syncNote': _debugSnap(syncNote),
    'stageLabel': _debugSnap(stageLabel),
    'entriesAfterSave': _debugSnap(entriesAfterSave),
    'lastCaptureAnalysisSucceeded': _debugSnap(lastCaptureAnalysisSucceeded),
    'canRecord': _debugSnap(canRecord),
    'showFraming': _debugSnap(showFraming),
    'compact': _debugSnap(compact),
    'stack': _debugSnap(stack),
    'suppressPostResultNextCheckCompetitors': _debugSnap(
      suppressPostResultNextCheckCompetitors,
    ),
    'auditPresentation': _debugSnap(auditPresentation),
    'justSavedFirstEntry': _debugSnap(justSavedFirstEntry),
    'postSaveEntryCount': _debugSnap(postSaveEntryCount),
    'suppressNoisyFirstSaveCards': _debugSnap(suppressNoisyFirstSaveCards),
    'suppressEarlyPatternClaimCards': _debugSnap(suppressEarlyPatternClaimCards),
    'suppressLatestSaveArchiveInsight': _debugSnap(
      suppressLatestSaveArchiveInsight,
    ),
    'secondSessionPayoff': _debugSnap(secondSessionPayoff),
    'thirdEntryBeliefPayoff': _debugSnap(thirdEntryBeliefPayoff),
    'confirmedRepeatTriggerPayoff': _debugSnap(confirmedRepeatTriggerPayoff),
    'confirmedRepeatHelpfulActionPayoff': _debugSnap(
      confirmedRepeatHelpfulActionPayoff,
    ),
    'confirmedRepeatChangeNotice': _debugSnap(confirmedRepeatChangeNotice),
    'repeatReturnCheckOffer': _debugSnap(repeatReturnCheckOffer),
    'earlyEvidenceTimeline': _debugSnap(earlyEvidenceTimeline),
    'showEarlyEvidenceTimeline': _debugSnap(showEarlyEvidenceTimeline),
    'suppressEarlyRepeatPayoffCompetitors': _debugSnap(
      suppressEarlyRepeatPayoffCompetitors,
    ),
    'earlyFirstSignalOnRecord': _debugSnap(earlyFirstSignalOnRecord),
    'returnTomorrowCueReady': _debugSnap(returnTomorrowCueReady),
    'returnDayFlowCandidate': _debugSnap(returnDayFlowCandidate),
    'showReturnDayFlow': _debugSnap(showReturnDayFlow),
    'showReturnTomorrowCueReady': _debugSnap(showReturnTomorrowCueReady),
    'firstWeekProgressReady': _debugSnap(firstWeekProgressReady),
    'showFirstWeekProgressReady': _debugSnap(showFirstWeekProgressReady),
    'showEarlyReturnReminder': _debugSnap(showEarlyReturnReminder),
    'viewingConfirmedRepeatOnRecord': _debugSnap(viewingConfirmedRepeatOnRecord),
    'suppressConfirmedRepeatInlineFeedback': _debugSnap(
      suppressConfirmedRepeatInlineFeedback,
    ),
    'showConfirmedRepeatBetaFeedback': _debugSnap(
      showConfirmedRepeatBetaFeedback,
    ),
    'repeatReturnChangeProof': _debugSnap(repeatReturnChangeProof),
    'patternChangedCandidate': _debugSnap(patternChangedCandidate),
    'patternChangedDismissed': _debugSnap(patternChangedDismissed),
    'confirmedRepeatThoughtMap': _debugSnap(confirmedRepeatThoughtMap),
    'positivePattern': _debugSnap(positivePattern),
    'helpfulActionAppearedCandidate': _debugSnap(helpfulActionAppearedCandidate),
    'showHelpfulActionAppearedEligible': _debugSnap(
      showHelpfulActionAppearedEligible,
    ),
    'positiveReinforcement': _debugSnap(positiveReinforcement),
    'archiveSummaryCandidate': _debugSnap(archiveSummaryCandidate),
    'archiveBeliefSurfaceCandidate': _debugSnap(archiveBeliefSurfaceCandidate),
    'patternNamePrompt': _debugSnap(patternNamePrompt),
    'showArchiveCurrentBeliefEligible': _debugSnap(
      showArchiveCurrentBeliefEligible,
    ),
    'dailyReturnReasonCandidate': _debugSnap(dailyReturnReasonCandidate),
    'hasChangeOverTimeProof': _debugSnap(hasChangeOverTimeProof),
    'postProofArchiveProof': _debugSnap(postProofArchiveProof),
    'archiveSummaryVisibleForProGate': _debugSnap(
      archiveSummaryVisibleForProGate,
    ),
    'weeklyArchiveReviewVisibleForProGate': _debugSnap(
      weeklyArchiveReviewVisibleForProGate,
    ),
    'hasConfirmedRepeatForProGate': _debugSnap(hasConfirmedRepeatForProGate),
    'privateArchiveReportForProGate': _debugSnap(privateArchiveReportForProGate),
    'privateArchiveReportPreviewForProGate': _debugSnap(
      privateArchiveReportPreviewForProGate,
    ),
    'patternChangedForProGate': _debugSnap(patternChangedForProGate),
    'hasReturnCheckAnsweredForProGate': _debugSnap(
      hasReturnCheckAnsweredForProGate,
    ),
    'showPostProofProBridge': _debugSnap(showPostProofProBridge),
    'proofSurfaceLayout': _debugSnap(proofSurfaceLayout),
    'showArchiveSummary': _debugSnap(showArchiveSummary),
    'archiveSummary': _debugSnap(archiveSummary),
    'showDailyReturnReason': _debugSnap(showDailyReturnReason),
    'dailyReturnReason': _debugSnap(dailyReturnReason),
    'archiveWatchingCandidate': _debugSnap(archiveWatchingCandidate),
    'archiveWatching': _debugSnap(archiveWatching),
    'weeklyArchiveReview': _debugSnap(weeklyArchiveReview),
    'showWeeklyArchiveReview': _debugSnap(showWeeklyArchiveReview),
    'privateArchiveReportCandidate': _debugSnap(privateArchiveReportCandidate),
    'showPrivateArchiveReport': _debugSnap(showPrivateArchiveReport),
    'showConfirmedRepeatWhyMatters': _debugSnap(showConfirmedRepeatWhyMatters),
    'showConfirmedRepeatThoughtMap': _debugSnap(showConfirmedRepeatThoughtMap),
    'showPositiveReinforcement': _debugSnap(showPositiveReinforcement),
    'firstWeekLoopCandidate': _debugSnap(firstWeekLoopCandidate),
    'firstWeekLoopProGated': _debugSnap(firstWeekLoopProGated),
    'recordProofStack': _debugSnap(recordProofStack),
    'showPatternChanged': _debugSnap(showPatternChanged),
    'showArchiveCurrentBeliefOnRecord': _debugSnap(
      showArchiveCurrentBeliefOnRecord,
    ),
    'showEarlyEvidenceTimelineOnRecord': _debugSnap(
      showEarlyEvidenceTimelineOnRecord,
    ),
    'showWeeklyArchiveReviewOnRecord': _debugSnap(
      showWeeklyArchiveReviewOnRecord,
    ),
    'showPrivateArchiveReportOnRecord': _debugSnap(
      showPrivateArchiveReportOnRecord,
    ),
    'showDailyReturnReasonOnRecord': _debugSnap(showDailyReturnReasonOnRecord),
    'showPostProofProBridgeOnRecord': _debugSnap(showPostProofProBridgeOnRecord),
    'firstProofPayoffSeenOnRecord': _debugSnap(firstProofPayoffSeenOnRecord),
    'isDegradedTranscriptOnRecord': _debugSnap(isDegradedTranscriptOnRecord),
    'currentRelevanceCandidate': _debugSnap(currentRelevanceCandidate),
    'patternReviewInboxActiveOnRecord': _debugSnap(
      patternReviewInboxActiveOnRecord,
    ),
    'showCurrentRelevanceOnRecordReady': _debugSnap(
      showCurrentRelevanceOnRecordReady,
    ),
    'currentRelevanceQuestionActiveOnRecord': _debugSnap(
      currentRelevanceQuestionActiveOnRecord,
    ),
    'correctionMemoryCandidate': _debugSnap(correctionMemoryCandidate),
    'showCorrectionMemoryOnRecordReady': _debugSnap(
      showCorrectionMemoryOnRecordReady,
    ),
    'evidenceWeightingCandidate': _debugSnap(evidenceWeightingCandidate),
    'showEvidenceWeightingOnRecordReady': _debugSnap(
      showEvidenceWeightingOnRecordReady,
    ),
    'proofSpecificityCandidate': _debugSnap(proofSpecificityCandidate),
    'showProofSpecificityOnRecordReady': _debugSnap(
      showProofSpecificityOnRecordReady,
    ),
    'presentDayRelevanceCandidate': _debugSnap(presentDayRelevanceCandidate),
    'showPresentDayRelevanceOnRecordReady': _debugSnap(
      showPresentDayRelevanceOnRecordReady,
    ),
    'showCaptureFreedomLine': _debugSnap(showCaptureFreedomLine),
    'timelinePositioningCandidate': _debugSnap(timelinePositioningCandidate),
    'otherEducationCardsOnRecord': _debugSnap(otherEducationCardsOnRecord),
    'showTimelinePositioningOnRecordReady': _debugSnap(
      showTimelinePositioningOnRecordReady,
    ),
    'patternConfidenceEducationCount': _debugSnap(
      patternConfidenceEducationCount,
    ),
    'patternConfidenceExplanationCandidate': _debugSnap(
      patternConfidenceExplanationCandidate,
    ),
    'showPatternConfidenceExplanationOnRecordReady': _debugSnap(
      showPatternConfidenceExplanationOnRecordReady,
    ),
    'showProEvidenceValueOnRecordReady': _debugSnap(
      showProEvidenceValueOnRecordReady,
    ),
    'showProBridgeVisibilityOnRecordReady': _debugSnap(
      showProBridgeVisibilityOnRecordReady,
    ),
    'showProEvidenceValuePrivateReportOnRecord': _debugSnap(
      showProEvidenceValuePrivateReportOnRecord,
    ),
    'showConfirmedRepeatWhyMattersOnRecord': _debugSnap(
      showConfirmedRepeatWhyMattersOnRecord,
    ),
    'showConfirmedRepeatThoughtMapOnRecord': _debugSnap(
      showConfirmedRepeatThoughtMapOnRecord,
    ),
    'showPositiveReinforcementOnRecord': _debugSnap(
      showPositiveReinforcementOnRecord,
    ),
    'showHelpfulActionAppearedOnRecord': _debugSnap(
      showHelpfulActionAppearedOnRecord,
    ),
    'showChangeProofOnRecord': _debugSnap(showChangeProofOnRecord),
    'showFirstWeekLoopOnRecord': _debugSnap(showFirstWeekLoopOnRecord),
    'firstProofPayoffCandidate': _debugSnap(firstProofPayoffCandidate),
    'showFirstProofPayoff': _debugSnap(showFirstProofPayoff),
    'threeDayChallengeCandidate': _debugSnap(threeDayChallengeCandidate),
    'showThreeDayChallengeOnRecord': _debugSnap(showThreeDayChallengeOnRecord),
    'firstProofPatternConfidence': _debugSnap(firstProofPatternConfidence),
    'firstProofTruthProofKey': _debugSnap(firstProofTruthProofKey),
    'showFirstProofTruth': _debugSnap(showFirstProofTruth),
    'firstProofTruthAnswer': _debugSnap(firstProofTruthAnswer),
    'showFirstProofActionLoop': _debugSnap(showFirstProofActionLoop),
    'firstProofActionLoopContent': _debugSnap(firstProofActionLoopContent),
    'showFirstProofMoment': _debugSnap(showFirstProofMoment),
    'postSaveHasConfirmedRepeat': _debugSnap(postSaveHasConfirmedRepeat),
    'postSaveHasFirstProof': _debugSnap(postSaveHasFirstProof),
    'postSaveDegraded': _debugSnap(postSaveDegraded),
    'showCoreValueFeedbackOnRecordPostFirstProof': _debugSnap(
      showCoreValueFeedbackOnRecordPostFirstProof,
    ),
    'returnCheckPayoffCandidate': _debugSnap(returnCheckPayoffCandidate),
    'whatChangedV2Prompt': _debugSnap(whatChangedV2Prompt),
    'whatChangedV2Display': _debugSnap(whatChangedV2Display),
    'showWhatChangedV2': _debugSnap(showWhatChangedV2),
    'showWhatChangedV2Display': _debugSnap(showWhatChangedV2Display),
    'showOpenCapturePromptChips': _debugSnap(showOpenCapturePromptChips),
    'showLowFrictionReturnCard': _debugSnap(showLowFrictionReturnCard),
    'firstMomentCaptureCandidate': _debugSnap(firstMomentCaptureCandidate),
    'firstSaveLiftCandidate': _debugSnap(firstSaveLiftCandidate),
    'firstSessionCaptureRepairCandidate': _debugSnap(
      firstSessionCaptureRepairCandidate,
    ),
    'openingRepairOverride': _debugSnap(openingRepairOverride),
    'showFirstSessionCaptureRepairCard': _debugSnap(
      showFirstSessionCaptureRepairCard,
    ),
    'firstSessionLiftCandidate': _debugSnap(firstSessionLiftCandidate),
    'showFirstSessionLiftCard': _debugSnap(showFirstSessionLiftCard),
    'showFirstSaveLiftCard': _debugSnap(showFirstSaveLiftCard),
    'showFirstMomentCaptureCard': _debugSnap(showFirstMomentCaptureCard),
    'secondMomentReturnCandidate': _debugSnap(secondMomentReturnCandidate),
    'showSecondMomentReturnCard': _debugSnap(showSecondMomentReturnCard),
    'threeMomentCompletionCandidate': _debugSnap(
      threeMomentCompletionCandidate,
    ),
    'showThreeMomentCompletionCard': _debugSnap(showThreeMomentCompletionCard),
    'firstRunPositioningCandidate': _debugSnap(firstRunPositioningCandidate),
    'showFirstRunPositioningCard': _debugSnap(showFirstRunPositioningCard),
    'betaTodaySummaryCandidate': _debugSnap(betaTodaySummaryCandidate),
    'showBetaTodaySummaryCard': _debugSnap(showBetaTodaySummaryCard),
    'archiveTimelineSpineCandidate': _debugSnap(archiveTimelineSpineCandidate),
    'whatToNoticeNextCandidate': _debugSnap(whatToNoticeNextCandidate),
    'showWhatToNoticeNextCard': _debugSnap(showWhatToNoticeNextCard),
    'showArchiveTimelineSpineOnRecord': _debugSnap(
      showArchiveTimelineSpineOnRecord,
    ),
    'suppressLegacyEducationCardsForSpineOnRecord': _debugSnap(
      suppressLegacyEducationCardsForSpineOnRecord,
    ),
    'timelineProofMomentCandidate': _debugSnap(timelineProofMomentCandidate),
    'showTimelineProofMomentOnRecord': _debugSnap(
      showTimelineProofMomentOnRecord,
    ),
    'betaTesterReportCandidate': _debugSnap(betaTesterReportCandidate),
    'showBetaTesterReportOnRecord': _debugSnap(showBetaTesterReportOnRecord),
    'notRelevantRecoveryCandidate': _debugSnap(notRelevantRecoveryCandidate),
    'proofQualityResponseTimelineCandidate': _debugSnap(
      proofQualityResponseTimelineCandidate,
    ),
    'proofQualityResponseSpineCandidate': _debugSnap(
      proofQualityResponseSpineCandidate,
    ),
    'betaProofLiftTimelineCandidate': _debugSnap(
      betaProofLiftTimelineCandidate,
    ),
    'returnAfterProofRecordCandidate': _debugSnap(
      returnAfterProofRecordCandidate,
    ),
    'showReturnAfterProofStrengthenedOnRecordReady': _debugSnap(
      showReturnAfterProofStrengthenedOnRecordReady,
    ),
    'showReturnAfterProofGenericOnRecordReady': _debugSnap(
      showReturnAfterProofGenericOnRecordReady,
    ),
    'showReturnAfterProofOnRecordReady': _debugSnap(
      showReturnAfterProofOnRecordReady,
    ),
    'returnAfterProofLiftV2Candidate': _debugSnap(
      returnAfterProofLiftV2Candidate,
    ),
    'showReturnAfterProofLiftV2OnRecordReady': _debugSnap(
      showReturnAfterProofLiftV2OnRecordReady,
    ),
    'recordReadySurfacePriority': _debugSnap(recordReadySurfacePriority),
    'recordLoosenSignalsPreAudit': _debugSnap(recordLoosenSignalsPreAudit),
    'recordEvidenceAnchorPreAudit': _debugSnap(recordEvidenceAnchorPreAudit),
    'recordFeedbackStateForLift': _debugSnap(recordFeedbackStateForLift),
    'timelineFeedbackType': _debugSnap(timelineFeedbackType),
    'betaRepairLabInput': _debugSnap(betaRepairLabInput),
    'showBetaRepairLabProPlacementOnRecord': _debugSnap(
      showBetaRepairLabProPlacementOnRecord,
    ),
    'betaRepairLabProPlacementResult': _debugSnap(
      betaRepairLabProPlacementResult,
    ),
    'showBetaRepairLabPricingValueFramingOnRecord': _debugSnap(
      showBetaRepairLabPricingValueFramingOnRecord,
    ),
    'betaRepairLabPricingValueFramingResult': _debugSnap(
      betaRepairLabPricingValueFramingResult,
    ),
    'showBetaRepairLabPaywallValueOnRecord': _debugSnap(
      showBetaRepairLabPaywallValueOnRecord,
    ),
    'betaRepairLabPaywallValueResult': _debugSnap(
      betaRepairLabPaywallValueResult,
    ),
    'hasProEngagementOnRecord': _debugSnap(hasProEngagementOnRecord),
    'showBetaRepairLabPricingValidationOnRecord': _debugSnap(
      showBetaRepairLabPricingValidationOnRecord,
    ),
    'showBetaRepairLabEvidenceTrailClarityOnRecord': _debugSnap(
      showBetaRepairLabEvidenceTrailClarityOnRecord,
    ),
    'betaRepairLabPricingValidationResult': _debugSnap(
      betaRepairLabPricingValidationResult,
    ),
    'proUnderstandingLiftRecordReadyInput': _debugSnap(
      proUnderstandingLiftRecordReadyInput,
    ),
    'showProUnderstandingLiftOnRecordReady': _debugSnap(
      showProUnderstandingLiftOnRecordReady,
    ),
    'showProVisibilityLiftOnRecordReady': _debugSnap(
      showProVisibilityLiftOnRecordReady,
    ),
    'proUnderstandingLiftRecordReadyResult': _debugSnap(
      proUnderstandingLiftRecordReadyResult,
    ),
    'proVisibilityLiftRecordReadyResult': _debugSnap(
      proVisibilityLiftRecordReadyResult,
    ),
    'showProofQualityResponseOnRecordReady': _debugSnap(
      showProofQualityResponseOnRecordReady,
    ),
    'showNotRelevantRecoveryOnRecordReady': _debugSnap(
      showNotRelevantRecoveryOnRecordReady,
    ),
    'showBetaProofLiftOnRecordReady': _debugSnap(showBetaProofLiftOnRecordReady),
    'betaActivationPathPreAuditContext': _debugSnap(
      betaActivationPathPreAuditContext,
    ),
    'betaActivationPathPreAuditResult': _debugSnap(
      betaActivationPathPreAuditResult,
    ),
    'showBetaActivationPathCard': _debugSnap(showBetaActivationPathCard),
    'betaActivationPathResult': _debugSnap(betaActivationPathResult),
    'betaFeedbackCaptureRecordReadyPreAudit': _debugSnap(
      betaFeedbackCaptureRecordReadyPreAudit,
    ),
    'showBetaFeedbackCaptureRecordReady': _debugSnap(
      showBetaFeedbackCaptureRecordReady,
    ),
    'betaFeedbackCaptureRecordReadyResult': _debugSnap(
      betaFeedbackCaptureRecordReadyResult,
    ),
    'betaProofFeedbackCounts': _debugSnap(betaProofFeedbackCounts),
    'betaProofFeedbackRowVisibleOnTimeline': _debugSnap(
      betaProofFeedbackRowVisibleOnTimeline,
    ),
    'proofQualityRepairInput': _debugSnap(proofQualityRepairInput),
    'showProofQualityRepairOnRecord': _debugSnap(showProofQualityRepairOnRecord),
    'proofQualityRepairResult': _debugSnap(proofQualityRepairResult),
    'proofFloorRescueInput': _debugSnap(proofFloorRescueInput),
    'showProofFloorRescueOnRecord': _debugSnap(showProofFloorRescueOnRecord),
    'proofFloorRescueResult': _debugSnap(proofFloorRescueResult),
    'blocksProByProofFloorOnRecord': _debugSnap(blocksProByProofFloorOnRecord),
    'showBetaRepairLabProofOnRecord': _debugSnap(showBetaRepairLabProofOnRecord),
    'betaRepairLabProofResult': _debugSnap(betaRepairLabProofResult),
    'blocksProCardsByProofProtectionOnRecord': _debugSnap(
      blocksProCardsByProofProtectionOnRecord,
    ),
    'betaRepairLabEvidenceTrailClarityResult': _debugSnap(
      betaRepairLabEvidenceTrailClarityResult,
    ),
    'recordLoosenSignals': _debugSnap(recordLoosenSignals),
    'recordReadyProTiming': _debugSnap(recordReadyProTiming),
    'betaActivationPathFinalContext': _debugSnap(betaActivationPathFinalContext),
    'shareableNonPrivateProofResult': _debugSnap(shareableNonPrivateProofResult),
    'showShareableNonPrivateProofOnRecord': _debugSnap(
      showShareableNonPrivateProofOnRecord,
    ),
    'proofSpecificityBoostCandidate': _debugSnap(proofSpecificityBoostCandidate),
    'timelineProofParentVisible': _debugSnap(timelineProofParentVisible),
    'showProofSpecificityBoostOnTimelineProof': _debugSnap(
      showProofSpecificityBoostOnTimelineProof,
    ),
    'showProofQualityResponseUnderTimelineProof': _debugSnap(
      showProofQualityResponseUnderTimelineProof,
    ),
    'showProofQualityResponseUnderArchiveSpine': _debugSnap(
      showProofQualityResponseUnderArchiveSpine,
    ),
    'showNotRelevantRecoveryUnderTimelineProof': _debugSnap(
      showNotRelevantRecoveryUnderTimelineProof,
    ),
    'showBetaProofLiftUnderTimelineProof': _debugSnap(
      showBetaProofLiftUnderTimelineProof,
    ),
    'showReturnAfterProofLiftV2BelowProofOnRecord': _debugSnap(
      showReturnAfterProofLiftV2BelowProofOnRecord,
    ),
    'showReturnAfterProofLiftV2InGuidanceStack': _debugSnap(
      showReturnAfterProofLiftV2InGuidanceStack,
    ),
    'showReturnAfterProofBelowProofOnRecord': _debugSnap(
      showReturnAfterProofBelowProofOnRecord,
    ),
    'showReturnAfterProofInGuidanceStack': _debugSnap(
      showReturnAfterProofInGuidanceStack,
    ),
    'showProUnderstandingLiftBelowProofOnRecord': _debugSnap(
      showProUnderstandingLiftBelowProofOnRecord,
    ),
    'showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord': _debugSnap(
      showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord,
    ),
    'showBetaRepairLabPricingValidationBelowProofOnRecord': _debugSnap(
      showBetaRepairLabPricingValidationBelowProofOnRecord,
    ),
    'showBetaRepairLabPricingValueFramingBelowProofOnRecord': _debugSnap(
      showBetaRepairLabPricingValueFramingBelowProofOnRecord,
    ),
    'showBetaRepairLabPaywallValueBelowProofOnRecord': _debugSnap(
      showBetaRepairLabPaywallValueBelowProofOnRecord,
    ),
    'showBetaRepairLabProPlacementBelowProofOnRecord': _debugSnap(
      showBetaRepairLabProPlacementBelowProofOnRecord,
    ),
    'showProUnderstandingLiftInProSectionOnRecord': _debugSnap(
      showProUnderstandingLiftInProSectionOnRecord,
    ),
    'showProVisibilityLiftBelowProofOnRecord': _debugSnap(
      showProVisibilityLiftBelowProofOnRecord,
    ),
    'showProVisibilityLiftInProSectionOnRecord': _debugSnap(
      showProVisibilityLiftInProSectionOnRecord,
    ),
    'showProBridgeBelowProofOnRecord': _debugSnap(
      showProBridgeBelowProofOnRecord,
    ),
    'showProBridgeInProSectionOnRecord': _debugSnap(
      showProBridgeInProSectionOnRecord,
    ),
    'proBridgeVisibilityRecordResult': _debugSnap(
      proBridgeVisibilityRecordResult,
    ),
    'patternReviewInboxActivePostSave': _debugSnap(
      patternReviewInboxActivePostSave,
    ),
    'timelineProofMomentPostSaveCandidate': _debugSnap(
      timelineProofMomentPostSaveCandidate,
    ),
    'showTimelineProofMomentOnFirstProofPayoff': _debugSnap(
      showTimelineProofMomentOnFirstProofPayoff,
    ),
    'proofSpecificityPostSaveCandidate': _debugSnap(
      proofSpecificityPostSaveCandidate,
    ),
    'showProofSpecificityOnFirstProofPayoff': _debugSnap(
      showProofSpecificityOnFirstProofPayoff,
    ),
    'proofSpecificityBoostPostSaveCandidate': _debugSnap(
      proofSpecificityBoostPostSaveCandidate,
    ),
    'proofQualityResponseFirstProofCandidate': _debugSnap(
      proofQualityResponseFirstProofCandidate,
    ),
    'proofQualityResponseTimelinePostSaveCandidate': _debugSnap(
      proofQualityResponseTimelinePostSaveCandidate,
    ),
    'betaProofLiftFirstProofCandidate': _debugSnap(
      betaProofLiftFirstProofCandidate,
    ),
    'betaProofLiftTimelinePostSaveCandidate': _debugSnap(
      betaProofLiftTimelinePostSaveCandidate,
    ),
    'returnAfterProofPostSaveCandidate': _debugSnap(
      returnAfterProofPostSaveCandidate,
    ),
    'firstProofPayoffParentVisible': _debugSnap(firstProofPayoffParentVisible),
    'showProofSpecificityBoostOnFirstProofPayoff': _debugSnap(
      showProofSpecificityBoostOnFirstProofPayoff,
    ),
    'showProofQualityResponseOnFirstProofPayoff': _debugSnap(
      showProofQualityResponseOnFirstProofPayoff,
    ),
    'timelineProofPostSaveParentVisible': _debugSnap(
      timelineProofPostSaveParentVisible,
    ),
    'showProofSpecificityBoostOnTimelineProofPostSave': _debugSnap(
      showProofSpecificityBoostOnTimelineProofPostSave,
    ),
    'showProofQualityResponseOnTimelineProofPostSave': _debugSnap(
      showProofQualityResponseOnTimelineProofPostSave,
    ),
    'showBetaProofLiftOnFirstProofPayoff': _debugSnap(
      showBetaProofLiftOnFirstProofPayoff,
    ),
    'showBetaProofLiftUnderTimelineProofPostSave': _debugSnap(
      showBetaProofLiftUnderTimelineProofPostSave,
    ),
    'showReturnAfterProofStrengthenedOnFirstProofPayoff': _debugSnap(
      showReturnAfterProofStrengthenedOnFirstProofPayoff,
    ),
    'showReturnAfterProofGenericOnFirstProofPayoff': _debugSnap(
      showReturnAfterProofGenericOnFirstProofPayoff,
    ),
    'showReturnAfterProofOnFirstProofPayoff': _debugSnap(
      showReturnAfterProofOnFirstProofPayoff,
    ),
    'returnAfterProofLiftV2PostSaveCandidate': _debugSnap(
      returnAfterProofLiftV2PostSaveCandidate,
    ),
    'showReturnAfterProofLiftV2OnPostSave': _debugSnap(
      showReturnAfterProofLiftV2OnPostSave,
    ),
    'postSaveLoosenSignalsPreAudit': _debugSnap(postSaveLoosenSignalsPreAudit),
    'postSaveEvidenceAnchorPreAudit': _debugSnap(postSaveEvidenceAnchorPreAudit),
    'postSaveFeedbackStateForLift': _debugSnap(postSaveFeedbackStateForLift),
    'hasProEngagementOnPostSave': _debugSnap(hasProEngagementOnPostSave),
    'proUnderstandingLiftPostSaveInput': _debugSnap(
      proUnderstandingLiftPostSaveInput,
    ),
    'showProUnderstandingLiftOnPostSave': _debugSnap(
      showProUnderstandingLiftOnPostSave,
    ),
    'proUnderstandingLiftPostSaveResult': _debugSnap(
      proUnderstandingLiftPostSaveResult,
    ),
    'base': _debugSnap(base),
    'showProVisibilityLiftOnPostSave': _debugSnap(
      showProVisibilityLiftOnPostSave,
    ),
    'proVisibilityLiftPostSaveResult': _debugSnap(
      proVisibilityLiftPostSaveResult,
    ),
    'showProEvidenceValuePostSave': _debugSnap(showProEvidenceValuePostSave),
    'showBetaInviteLoopPostSave': _debugSnap(showBetaInviteLoopPostSave),
    'showProPreviewPostSave': _debugSnap(showProPreviewPostSave),
    'showProBridgeVisibilityPostSave': _debugSnap(
      showProBridgeVisibilityPostSave,
    ),
    'showProLockMomentPostSave': _debugSnap(showProLockMomentPostSave),
    'monthlyPrivateReportPreviewPostSave': _debugSnap(
      monthlyPrivateReportPreviewPostSave,
    ),
    'showMonthlyPrivateReportPreviewPostSave': _debugSnap(
      showMonthlyPrivateReportPreviewPostSave,
    ),
    'betaFeedbackIntelligenceSurfaceOnRecordReady': _debugSnap(
      betaFeedbackIntelligenceSurfaceOnRecordReady,
    ),
    'betaFeedbackIntelligenceSurfacePostSave': _debugSnap(
      betaFeedbackIntelligenceSurfacePostSave,
    ),
    'helpedTrackingPrompt': _debugSnap(helpedTrackingPrompt),
    'showHelpedTracking': _debugSnap(showHelpedTracking),
    'showReturnCheckPayoff': _debugSnap(showReturnCheckPayoff),
    'showArchiveSummaryOnRecord': _debugSnap(showArchiveSummaryOnRecord),
    'confirmedRepeatChangeNoticeOnRecord': _debugSnap(
      confirmedRepeatChangeNoticeOnRecord,
    ),
    'lowEvidenceGuidance': _debugSnap(lowEvidenceGuidance),
    'quietSignalCandidate': _debugSnap(quietSignalCandidate),
    'showQuietSignalOnRecord': _debugSnap(showQuietSignalOnRecord),
    'showLowEvidenceGuidanceOnRecord': _debugSnap(
      showLowEvidenceGuidanceOnRecord,
    ),
    'dailyArchiveMemoryCandidate': _debugSnap(dailyArchiveMemoryCandidate),
    'firstProofLoopActive': _debugSnap(firstProofLoopActive),
    'showDailyArchiveMemory': _debugSnap(showDailyArchiveMemory),
    'showReturningWatchTargetFocusedUi': _debugSnap(
      showReturningWatchTargetFocusedUi,
    ),
    'recordReadyShowsWatchTargetOnly': _debugSnap(
      recordReadyShowsWatchTargetOnly,
    ),
    'recordReadySuppressStreakPressure': _debugSnap(
      recordReadySuppressStreakPressure,
    ),
    'betaTestScriptCardCandidate': _debugSnap(betaTestScriptCardCandidate),
    'showBetaTestScriptCard': _debugSnap(showBetaTestScriptCard),
    'daysSinceLastEntry': _debugSnap(daysSinceLastEntry),
    'showReturnedAfterDelayRecovery': _debugSnap(showReturnedAfterDelayRecovery),
    'nextBestActionCandidate': _debugSnap(nextBestActionCandidate),
    'showNextBestActionOnRecord': _debugSnap(showNextBestActionOnRecord),
    'postSaveReturnHandoffCandidate': _debugSnap(postSaveReturnHandoffCandidate),
    'returnTomorrowCuePostSave': _debugSnap(returnTomorrowCuePostSave),
    'postSaveDegradedForReturnCue': _debugSnap(postSaveDegradedForReturnCue),
    'comeBackTomorrowV2PostSaveWatch': _debugSnap(
      comeBackTomorrowV2PostSaveWatch,
    ),
    'showComeBackTomorrowV2PostSave': _debugSnap(showComeBackTomorrowV2PostSave),
    'showPostSaveCuriosityHook': _debugSnap(showPostSaveCuriosityHook),
    'betaFeedbackCapturePostSavePreAudit': _debugSnap(
      betaFeedbackCapturePostSavePreAudit,
    ),
    'showBetaFeedbackCapturePostSave': _debugSnap(
      showBetaFeedbackCapturePostSave,
    ),
    'betaFeedbackCapturePostSaveResult': _debugSnap(
      betaFeedbackCapturePostSaveResult,
    ),
    'postSaveProofFloorRescueInput': _debugSnap(postSaveProofFloorRescueInput),
    'blocksProByProofFloorOnPostSave': _debugSnap(
      blocksProByProofFloorOnPostSave,
    ),
    'recordPostSaveSurfacePriority': _debugSnap(recordPostSaveSurfacePriority),
    'postSaveLoosenSignals': _debugSnap(postSaveLoosenSignals),
    'postSaveProTiming': _debugSnap(postSaveProTiming),
    'betaFeedbackCapturePostSaveFinal': _debugSnap(
      betaFeedbackCapturePostSaveFinal,
    ),
    'proPreviewPostSaveResult': _debugSnap(proPreviewPostSaveResult),
    'betaInviteLoopPostSaveResult': _debugSnap(betaInviteLoopPostSaveResult),
    'proBridgeVisibilityPostSaveResult': _debugSnap(
      proBridgeVisibilityPostSaveResult,
    ),
    'showReturnTomorrowCuePostSave': _debugSnap(showReturnTomorrowCuePostSave),
    'firstWeekProgressPostSave': _debugSnap(firstWeekProgressPostSave),
    'showFirstWeekProgressPostSave': _debugSnap(showFirstWeekProgressPostSave),
    'showPostSaveReturnHandoff': _debugSnap(showPostSaveReturnHandoff),
    'beliefUpdatePayoff': _debugSnap(beliefUpdatePayoff),
    'journalShareProof': _debugSnap(journalShareProof),
    'shareableProof': _debugSnap(shareableProof),
    'returnLoopPayoff': _debugSnap(returnLoopPayoff),
    'postSaveDailyMirror': _debugSnap(postSaveDailyMirror),
    'postSaveArchiveHierarchy': _debugSnap(postSaveArchiveHierarchy),
    'suppressNoisyRepeatPostSaveCards': _debugSnap(
      suppressNoisyRepeatPostSaveCards,
    ),
    'repeatPostSaveThoughtMapPreview': _debugSnap(
      repeatPostSaveThoughtMapPreview,
    ),
    'showDegradedTranscriptFocusedPostSave': _debugSnap(
      showDegradedTranscriptFocusedPostSave,
    ),
    'suppressDegradedTranscriptPostSaveCompetitors': _debugSnap(
      suppressDegradedTranscriptPostSaveCompetitors,
    ),
    'returningUserToday': _debugSnap(returningUserToday),
    'nextMomentPrompt': _debugSnap(nextMomentPrompt),
    'dailyArchiveExercise': _debugSnap(dailyArchiveExercise),
    'todaysOneQuestion': _debugSnap(todaysOneQuestion),
    'recordHomeSurface': _debugSnap(recordHomeSurface),
    'showArchiveProgressCards': _debugSnap(showArchiveProgressCards),
    'readyCapturePolicy': _debugSnap(readyCapturePolicy),
    'showTesterMission': _debugSnap(showTesterMission),
    'showRecordCaptureModes': _debugSnap(showRecordCaptureModes),
    'testerMissionCompact': _debugSnap(testerMissionCompact),
    'showTesterMissionFull': _debugSnap(showTesterMissionFull),
    'testerMission': _debugSnap(testerMission),
    'showThoughtMapRecordCta': _debugSnap(showThoughtMapRecordCta),
    'showPositiveReinforcementRecordCta': _debugSnap(
      showPositiveReinforcementRecordCta,
    ),
    'showPatternChangedRecordCta': _debugSnap(showPatternChangedRecordCta),
    'showArchiveSummaryRecordCta': _debugSnap(showArchiveSummaryRecordCta),
    'showDailyReturnReasonRecordCta': _debugSnap(showDailyReturnReasonRecordCta),
    'showFirstWeekLoopRecordCta': _debugSnap(showFirstWeekLoopRecordCta),
  };

  final RecordingPhase policyMic;
  final bool policyUserDenied;
  final String? error;
  final String? localSaveTitle;
  final String? syncNote;
  final String stageLabel;
  final List<JournalEntry> entriesAfterSave;
  final bool lastCaptureAnalysisSucceeded;
  final bool firstUseSimplifiedRecord;
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
  final SurfacePriorityResult? recordReadySurfacePriority;
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
  final ProBridgeTimingLoosenSignals? recordLoosenSignals;
  final ProMomentTimingContext? recordReadyProTiming;
  final BetaActivationPathContext? betaActivationPathFinalContext;
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
  final ProUnderstandingLiftResult? base;
  final bool showProVisibilityLiftOnPostSave;
  final ProVisibilityLiftResult? proVisibilityLiftPostSaveResult;
  final bool showProEvidenceValuePostSave;
  final bool showBetaInviteLoopPostSave;
  final bool showProPreviewPostSave;
  final bool showProBridgeVisibilityPostSave;
  final bool showProLockMomentPostSave;
  final MonthlyPrivateReportPreview? monthlyPrivateReportPreviewPostSave;
  final bool showMonthlyPrivateReportPreviewPostSave;
  final BetaFeedbackIntelligenceSurface? betaFeedbackIntelligenceSurfaceOnRecordReady;
  final BetaFeedbackIntelligenceSurface? betaFeedbackIntelligenceSurfacePostSave;
  final HelpedTrackingPrompt? helpedTrackingPrompt;
  final bool showHelpedTracking;
  final bool showReturnCheckPayoff;
  final bool showArchiveSummaryOnRecord;
  final ConfirmedRepeatChangeNotice? confirmedRepeatChangeNoticeOnRecord;
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
  final ProBridgeTimingLoosenSignals? postSaveLoosenSignals;
  final ProMomentTimingContext? postSaveProTiming;
  final BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveFinal;
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
  final bool showRecordCaptureModes;
  final bool testerMissionCompact;
  final bool showTesterMissionFull;
  final TesterMissionResult? testerMission;
  final bool showThoughtMapRecordCta;
  final bool showPositiveReinforcementRecordCta;
  final bool showPatternChangedRecordCta;
  final bool showArchiveSummaryRecordCta;
  final bool showDailyReturnReasonRecordCta;
  final bool showFirstWeekLoopRecordCta;
}

/// Stable characterization snapshot: primitives and enums keep their values,
/// lists are walked, every other object becomes [Object.toString].
Object? _debugSnap(Object? value) {
  if (value == null) return null;
  if (value is bool || value is num || value is String) return value;
  if (value is Enum) return value.name;
  if (value is Iterable) {
    return [for (final item in value) _debugSnap(item)];
  }
  return value.toString();
}
