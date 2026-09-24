import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/config/v1_feature_flags.dart';
import 'package:archiveme_mobile/dev/visual_audit_overrides.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_store.dart';
import 'package:archiveme_mobile/features/beta/core_value_feedback_store.dart';
import 'package:archiveme_mobile/features/beta/tester_mission_store.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:archiveme_mobile/features/beta_test_script/beta_test_script_store.dart';
import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_why_matters_store.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:archiveme_mobile/features/low_friction_return/low_friction_return_engine.dart';
import 'package:archiveme_mobile/features/monthly_private_report/monthly_private_report_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_lock_moment/pro_lock_moment_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_engine.dart';
import 'package:archiveme_mobile/features/recording/record_surface_input.dart';
import 'package:archiveme_mobile/features/recording/record_surface_resolver.dart';
import 'package:archiveme_mobile/features/recording/record_user_pro_state.dart';
import 'package:archiveme_mobile/features/repeat_return_check/pattern_changed_store.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_store.dart';
import 'package:archiveme_mobile/features/shareable_proof/shareable_proof_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_analytics.dart';
import 'package:archiveme_mobile/features/three_moment_completion/three_moment_completion_store.dart';
import 'package:archiveme_mobile/features/voice_capture/microphone_permission_state.dart';
import 'package:archiveme_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'record_surface_test_fixtures.dart';
import 'support/release_suite_static_state_reset.dart';

/// Step 0 characterization harness for [RecordSurfaceResolver.resolve].
///
/// Deferred — these three flags are compile-time consts; adding test overrides
/// would break `v1_scope_cut_test`, the reachability audit, and V1 tree-shaking.
/// All scenarios below run against compiled defaults only:
/// - [V1FeatureFlags.enableV1Only] is true (do not add an enableV1Only-off case)
/// - [V1CapabilityRegistry.notifications] is false (do not add a notifications-on case)
/// - [ScreenshotMode.enabled] is false (do not add a screenshot-mode-on case)
void main() {
  setUp(() async {
    await ReleaseSuiteStaticStateReset.resetCachedState();

    await RepeatReturnCheckStore.resetForTest();
    await FirstProofTruthStore.resetForTest(null);
    await PatternChangedStore.resetForTest();
    await BetaRepairLabStore.resetForTest(null);
    await DelayedPaywallProofStore.resetForTest();
    SurfacePriorityAnalytics.resetForTest();
    ShareableProofSeenLatch.resetForTest();
    ProPlacementTriggerAuditEngine.resetForTest();
    await ConfirmedRepeatBetaFeedbackStore.resetForTest();
    await ConfirmedRepeatWhyMattersStore.resetForTest();
    await ProEvidenceValueDismissStore.resetForTest();
    await ProLockMomentDismissStore.resetForTest();
    await MonthlyPrivateReportDismissStore.resetForTest();
    await LowFrictionReturnStore.resetForTest(null);
    await ThreeMomentCompletionStore.resetForTest(null);
    await ReturnAfterProofStore.resetForTest(null);
    await BetaTestScriptStore.resetForTest(null);
    await TesterMissionStore.resetForTest();
    await CoreValueFeedbackStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(null);
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = false;
    ActivationFunnelAnalytics.resetForTest();
    VisualAuditOverrides.setRecordPresentation(null);

    // Global helper sets bypassGateForTest=true; goldens need the real gate.
    DelayedPaywallProofStore.bypassGateForTest = false;
  });

  tearDown(() {
    VisualAuditOverrides.setRecordPresentation(null);
    ArchiveBetaMissionGate.resetForTest();
    ShareableProofSeenLatch.resetForTest();
  });

  test('compiled defaults match the deferred-flag polarity', () {
    expect(V1FeatureFlags.enableV1Only, isTrue);
    expect(V1CapabilityRegistry.notifications, isFalse);
    expect(ScreenshotMode.enabled, isFalse);
  });

  test('toDebugMap covers every constructor field', () {
    final map = _resolve(emptyRecordSurfaceInput());
    expect(map.length, 361);
    expect(map.keys, containsAll(_constructorFieldNames));
    expect(map.keys.toSet().length, 361);
  });

  test('empty ready: first-use simplified record', () {
    final map = _resolve(emptyRecordSurfaceInput());
    expect(map['canRecord'], isTrue);
    expect(map['showFraming'], isTrue);
    expect(map['firstUseSimplifiedRecord'], isTrue);
    expect(map['showEarlyReturnReminder'], isFalse);
    expect(map['showWeeklyArchiveReviewOnRecord'], isFalse);
    expect(map['showDailyThoughtprintmory'], isFalse);
    _expectStable(emptyRecordSurfaceInput());
  });

  test('ready with one entry', () {
    final one = relatedRepeatEntry(
      id: 'e1',
      transcript:
          'I had no capacity but I said yes again to the extra meeting today.',
      createdAt: DateTime(2026, 6, 10, 12),
    );
    final input = emptyRecordSurfaceInput(journalEntries: [one], entryCount: 1);
    final map = _resolve(input);
    expect(map['firstUseSimplifiedRecord'], isFalse);
    expect(map['canRecord'], isTrue);
    _expectStable(input);
  });

  test('ready with three related entries', () {
    final input = emptyRecordSurfaceInput(
      journalEntries: threeRelatedRepeatEntries(),
    );
    final map = _resolve(input);
    expect(map['firstUseSimplifiedRecord'], isFalse);
    expect(map['postSaveEntryCount'], 3);
    _expectStable(input);
  });

  test('ready with four related entries', () {
    final input = emptyRecordSurfaceInput(
      journalEntries: fourRelatedRepeatEntries(),
    );
    final map = _resolve(input);
    expect(map['firstUseSimplifiedRecord'], isFalse);
    expect(map['postSaveEntryCount'], 4);
    _expectStable(input);
  });

  test('recording', () {
    final input = emptyRecordSurfaceInput(ui: RecordUiState.recording);
    final map = _resolve(input);
    expect(map['canRecord'], isTrue);
    expect(map['policyMic'], 'recording');
    _expectStable(input);
  });

  test('permission blocked', () {
    final input = emptyRecordSurfaceInput(
      ui: RecordUiState.permissionBlocked,
      micPermissionState: MicrophonePermissionState.deniedOpenSettings,
    );
    final map = _resolve(input);
    expect(map['canRecord'], isFalse);
    expect(map['policyUserDenied'], isTrue);
    _expectStable(input);
  });

  test('post-save first save', () {
    final first = relatedRepeatEntry(
      id: 'e1',
      transcript:
          'I had no capacity but I said yes again to the extra meeting today.',
      createdAt: DateTime(2026, 6, 10, 12),
    );
    final input = emptyRecordSurfaceInput(
      ui: RecordUiState.done,
      isPostSave: true,
      journalEntries: [first],
      entriesAfterSave: [first],
      recordReturnProJustSaved: true,
    );
    final map = _resolve(input);
    expect(map['justSavedFirstEntry'], isTrue);
    expect(map['suppressNoisyFirstSaveCards'], isTrue);
    _expectStable(input);
  });

  test('post-save with three related entries', () {
    final entries = threeRelatedRepeatEntries();
    final input = emptyRecordSurfaceInput(
      ui: RecordUiState.done,
      isPostSave: true,
      journalEntries: entries,
      entriesAfterSave: entries,
    );
    final map = _resolve(input);
    expect(map['justSavedFirstEntry'], isFalse);
    expect(map['postSaveEntryCount'], 3);
    _expectStable(input);
  });

  test('post-save with four related entries', () {
    final entries = fourRelatedRepeatEntries();
    final input = emptyRecordSurfaceInput(
      ui: RecordUiState.done,
      isPostSave: true,
      journalEntries: entries,
      entriesAfterSave: entries,
    );
    final map = _resolve(input);
    expect(map['postSaveEntryCount'], 4);
    _expectStable(input);
  });

  test('ready four entries as pro vs free', () {
    final entries = fourRelatedRepeatEntries();
    final free = _resolve(
      emptyRecordSurfaceInput(journalEntries: entries),
    );
    final pro = _resolve(
      emptyRecordSurfaceInput(
        journalEntries: entries,
        userProState: const RecordUserProState(
          recordReturnProState: null,
          isPro: true,
        ),
      ),
    );
    expect(free.length, 361);
    expect(pro.length, 361);
    expect(free.keys, pro.keys);
  });

  test('visual audit overlay applies presentation', () {
    VisualAuditOverrides.setRecordPresentation(
      const RecordAuditPresentation(
        ui: RecordUiState.done,
        justSavedFirst: true,
        localSaveTitle: 'audit-save',
        error: 'audit-error',
      ),
    );
    final map = _resolve(emptyRecordSurfaceInput());
    expect(map['justSavedFirstEntry'], isTrue);
    expect(map['localSaveTitle'], 'audit-save');
    expect(map['error'], 'audit-error');
    expect(map['auditPresentation'], isNotNull);
  });
}

Map<String, Object?> _resolve(RecordSurfaceInput input) {
  return RecordSurfaceResolver.resolve(input).toDebugMap();
}

void _expectStable(RecordSurfaceInput input) {
  final first = RecordSurfaceResolver.resolve(input).toDebugMap();
  ShareableProofSeenLatch.resetForTest();
  ProPlacementTriggerAuditEngine.resetForTest();
  final second = RecordSurfaceResolver.resolve(input).toDebugMap();
  expect(second, first);
}

/// Constructor field names from RecordSurfaceViewState, in declaration order.
const _constructorFieldNames = <String>[
  'policyMic',
  'policyUserDenied',
  'firstUseSimplifiedRecord',
  'error',
  'localSaveTitle',
  'syncNote',
  'stageLabel',
  'entriesAfterSave',
  'lastCaptureAnalysisSucceeded',
  'canRecord',
  'showFraming',
  'compact',
  'stack',
  'suppressPostResultNextCheckCompetitors',
  'auditPresentation',
  'justSavedFirstEntry',
  'postSaveEntryCount',
  'suppressNoisyFirstSaveCards',
  'suppressEarlyPatternClaimCards',
  'suppressLatestSaveArchiveInsight',
  'secondSessionPayoff',
  'thirdEntryBeliefPayoff',
  'confirmedRepeatTriggerPayoff',
  'confirmedRepeatHelpfulActionPayoff',
  'confirmedRepeatChangeNotice',
  'repeatReturnCheckOffer',
  'earlyEvidenceTimeline',
  'showEarlyEvidenceTimeline',
  'suppressEarlyRepeatPayoffCompetitors',
  'earlyFirstSignalOnRecord',
  'returnTomorrowCueReady',
  'returnDayFlowCandidate',
  'showReturnDayFlow',
  'showReturnTomorrowCueReady',
  'firstWeekProgressReady',
  'showFirstWeekProgressReady',
  'showEarlyReturnReminder',
  'viewingConfirmedRepeatOnRecord',
  'suppressConfirmedRepeatInlineFeedback',
  'showConfirmedRepeatBetaFeedback',
  'repeatReturnChangeProof',
  'patternChangedCandidate',
  'patternChangedDismissed',
  'confirmedRepeatThoughtMap',
  'positivePattern',
  'helpfulActionAppearedCandidate',
  'showHelpfulActionAppearedEligible',
  'positiveReinforcement',
  'archiveSummaryCandidate',
  'archiveBeliefSurfaceCandidate',
  'patternNamePrompt',
  'showArchiveCurrentBeliefEligible',
  'dailyReturnReasonCandidate',
  'hasChangeOverTimeProof',
  'postProofArchiveProof',
  'archiveSummaryVisibleForProGate',
  'weeklyArchiveReviewVisibleForProGate',
  'hasConfirmedRepeatForProGate',
  'privateArchiveReportForProGate',
  'privateArchiveReportPreviewForProGate',
  'patternChangedForProGate',
  'hasReturnCheckAnsweredForProGate',
  'showPostProofProBridge',
  'proofSurfaceLayout',
  'showArchiveSummary',
  'archiveSummary',
  'showDailyReturnReason',
  'dailyReturnReason',
  'archiveWatchingCandidate',
  'archiveWatching',
  'weeklyArchiveReview',
  'showWeeklyArchiveReview',
  'privateArchiveReportCandidate',
  'showPrivateArchiveReport',
  'showConfirmedRepeatWhyMatters',
  'showConfirmedRepeatThoughtMap',
  'showPositiveReinforcement',
  'firstWeekLoopCandidate',
  'firstWeekLoopProGated',
  'recordProofStack',
  'showPatternChanged',
  'showArchiveCurrentBeliefOnRecord',
  'showEarlyEvidenceTimelineOnRecord',
  'showWeeklyArchiveReviewOnRecord',
  'showPrivateArchiveReportOnRecord',
  'showDailyReturnReasonOnRecord',
  'showPostProofProBridgeOnRecord',
  'firstProofPayoffSeenOnRecord',
  'isDegradedTranscriptOnRecord',
  'currentRelevanceCandidate',
  'patternReviewInboxActiveOnRecord',
  'showCurrentRelevanceOnRecordReady',
  'currentRelevanceQuestionActiveOnRecord',
  'correctionMemoryCandidate',
  'showCorrectionMemoryOnRecordReady',
  'evidenceWeightingCandidate',
  'showEvidenceWeightingOnRecordReady',
  'proofSpecificityCandidate',
  'showProofSpecificityOnRecordReady',
  'presentDayRelevanceCandidate',
  'showPresentDayRelevanceOnRecordReady',
  'showCaptureFreedomLine',
  'timelinePositioningCandidate',
  'otherEducationCardsOnRecord',
  'showTimelinePositioningOnRecordReady',
  'patternConfidenceEducationCount',
  'patternConfidenceExplanationCandidate',
  'showPatternConfidenceExplanationOnRecordReady',
  'showProEvidenceValueOnRecordReady',
  'showProBridgeVisibilityOnRecordReady',
  'showProEvidenceValuePrivateReportOnRecord',
  'showConfirmedRepeatWhyMattersOnRecord',
  'showConfirmedRepeatThoughtMapOnRecord',
  'showPositiveReinforcementOnRecord',
  'showHelpfulActionAppearedOnRecord',
  'showChangeProofOnRecord',
  'showFirstWeekLoopOnRecord',
  'firstProofPayoffCandidate',
  'showFirstProofPayoff',
  'threeDayChallengeCandidate',
  'showThreeDayChallengeOnRecord',
  'firstProofPatternConfidence',
  'firstProofTruthProofKey',
  'showFirstProofTruth',
  'firstProofTruthAnswer',
  'showFirstProofActionLoop',
  'firstProofActionLoopContent',
  'showFirstProofMoment',
  'postSaveHasConfirmedRepeat',
  'postSaveHasFirstProof',
  'postSaveDegraded',
  'showCoreValueFeedbackOnRecordPostFirstProof',
  'returnCheckPayoffCandidate',
  'whatChangedV2Prompt',
  'whatChangedV2Display',
  'showWhatChangedV2',
  'showWhatChangedV2Display',
  'showOpenCapturePromptChips',
  'showLowFrictionReturnCard',
  'firstMomentCaptureCandidate',
  'firstSaveLiftCandidate',
  'firstSessionCaptureRepairCandidate',
  'openingRepairOverride',
  'showFirstSessionCaptureRepairCard',
  'firstSessionLiftCandidate',
  'showFirstSessionLiftCard',
  'showFirstSaveLiftCard',
  'showFirstMomentCaptureCard',
  'secondMomentReturnCandidate',
  'showSecondMomentReturnCard',
  'threeMomentCompletionCandidate',
  'showThreeMomentCompletionCard',
  'firstRunPositioningCandidate',
  'showFirstRunPositioningCard',
  'betaTodaySummaryCandidate',
  'showBetaTodaySummaryCard',
  'archiveTimelineSpineCandidate',
  'whatToNoticeNextCandidate',
  'showWhatToNoticeNextCard',
  'showArchiveTimelineSpineOnRecord',
  'suppressLegacyEducationCardsForSpineOnRecord',
  'timelineProofMomentCandidate',
  'showTimelineProofMomentOnRecord',
  'betaTesterReportCandidate',
  'showBetaTesterReportOnRecord',
  'notRelevantRecoveryCandidate',
  'proofQualityResponseTimelineCandidate',
  'proofQualityResponseSpineCandidate',
  'betaProofLiftTimelineCandidate',
  'returnAfterProofRecordCandidate',
  'showReturnAfterProofStrengthenedOnRecordReady',
  'showReturnAfterProofGenericOnRecordReady',
  'showReturnAfterProofOnRecordReady',
  'returnAfterProofLiftV2Candidate',
  'showReturnAfterProofLiftV2OnRecordReady',
  'recordReadySurfacePriority',
  'recordLoosenSignalsPreAudit',
  'recordEvidenceAnchorPreAudit',
  'recordFeedbackStateForLift',
  'timelineFeedbackType',
  'betaRepairLabInput',
  'showBetaRepairLabProPlacementOnRecord',
  'betaRepairLabProPlacementResult',
  'showBetaRepairLabPricingValueFramingOnRecord',
  'betaRepairLabPricingValueFramingResult',
  'showBetaRepairLabPaywallValueOnRecord',
  'betaRepairLabPaywallValueResult',
  'hasProEngagementOnRecord',
  'showBetaRepairLabPricingValidationOnRecord',
  'showBetaRepairLabEvidenceTrailClarityOnRecord',
  'betaRepairLabPricingValidationResult',
  'proUnderstandingLiftRecordReadyInput',
  'showProUnderstandingLiftOnRecordReady',
  'showProVisibilityLiftOnRecordReady',
  'proUnderstandingLiftRecordReadyResult',
  'proVisibilityLiftRecordReadyResult',
  'showProofQualityResponseOnRecordReady',
  'showNotRelevantRecoveryOnRecordReady',
  'showBetaProofLiftOnRecordReady',
  'betaActivationPathPreAuditContext',
  'betaActivationPathPreAuditResult',
  'showBetaActivationPathCard',
  'betaActivationPathResult',
  'betaFeedbackCaptureRecordReadyPreAudit',
  'showBetaFeedbackCaptureRecordReady',
  'betaFeedbackCaptureRecordReadyResult',
  'betaProofFeedbackCounts',
  'betaProofFeedbackRowVisibleOnTimeline',
  'proofQualityRepairInput',
  'showProofQualityRepairOnRecord',
  'proofQualityRepairResult',
  'proofFloorRescueInput',
  'showProofFloorRescueOnRecord',
  'proofFloorRescueResult',
  'blocksProByProofFloorOnRecord',
  'showBetaRepairLabProofOnRecord',
  'betaRepairLabProofResult',
  'blocksProCardsByProofProtectionOnRecord',
  'betaRepairLabEvidenceTrailClarityResult',
  'recordLoosenSignals',
  'recordReadyProTiming',
  'betaActivationPathFinalContext',
  'shareableNonPrivateProofResult',
  'showShareableNonPrivateProofOnRecord',
  'proofSpecificityBoostCandidate',
  'timelineProofParentVisible',
  'showProofSpecificityBoostOnTimelineProof',
  'showProofQualityResponseUnderTimelineProof',
  'showProofQualityResponseUnderArchiveSpine',
  'showNotRelevantRecoveryUnderTimelineProof',
  'showBetaProofLiftUnderTimelineProof',
  'showReturnAfterProofLiftV2BelowProofOnRecord',
  'showReturnAfterProofLiftV2InGuidanceStack',
  'showReturnAfterProofBelowProofOnRecord',
  'showReturnAfterProofInGuidanceStack',
  'showProUnderstandingLiftBelowProofOnRecord',
  'showBetaRepairLabEvidenceTrailClarityBelowProofOnRecord',
  'showBetaRepairLabPricingValidationBelowProofOnRecord',
  'showBetaRepairLabPricingValueFramingBelowProofOnRecord',
  'showBetaRepairLabPaywallValueBelowProofOnRecord',
  'showBetaRepairLabProPlacementBelowProofOnRecord',
  'showProUnderstandingLiftInProSectionOnRecord',
  'showProVisibilityLiftBelowProofOnRecord',
  'showProVisibilityLiftInProSectionOnRecord',
  'showProBridgeBelowProofOnRecord',
  'showProBridgeInProSectionOnRecord',
  'proBridgeVisibilityRecordResult',
  'patternReviewInboxActivePostSave',
  'timelineProofMomentPostSaveCandidate',
  'showTimelineProofMomentOnFirstProofPayoff',
  'proofSpecificityPostSaveCandidate',
  'showProofSpecificityOnFirstProofPayoff',
  'proofSpecificityBoostPostSaveCandidate',
  'proofQualityResponseFirstProofCandidate',
  'proofQualityResponseTimelinePostSaveCandidate',
  'betaProofLiftFirstProofCandidate',
  'betaProofLiftTimelinePostSaveCandidate',
  'returnAfterProofPostSaveCandidate',
  'firstProofPayoffParentVisible',
  'showProofSpecificityBoostOnFirstProofPayoff',
  'showProofQualityResponseOnFirstProofPayoff',
  'timelineProofPostSaveParentVisible',
  'showProofSpecificityBoostOnTimelineProofPostSave',
  'showProofQualityResponseOnTimelineProofPostSave',
  'showBetaProofLiftOnFirstProofPayoff',
  'showBetaProofLiftUnderTimelineProofPostSave',
  'showReturnAfterProofStrengthenedOnFirstProofPayoff',
  'showReturnAfterProofGenericOnFirstProofPayoff',
  'showReturnAfterProofOnFirstProofPayoff',
  'returnAfterProofLiftV2PostSaveCandidate',
  'showReturnAfterProofLiftV2OnPostSave',
  'postSaveLoosenSignalsPreAudit',
  'postSaveEvidenceAnchorPreAudit',
  'postSaveFeedbackStateForLift',
  'hasProEngagementOnPostSave',
  'proUnderstandingLiftPostSaveInput',
  'showProUnderstandingLiftOnPostSave',
  'proUnderstandingLiftPostSaveResult',
  'base',
  'showProVisibilityLiftOnPostSave',
  'proVisibilityLiftPostSaveResult',
  'showProEvidenceValuePostSave',
  'showBetaInviteLoopPostSave',
  'showProPreviewPostSave',
  'showProBridgeVisibilityPostSave',
  'showProLockMomentPostSave',
  'monthlyPrivateReportPreviewPostSave',
  'showMonthlyPrivateReportPreviewPostSave',
  'betaFeedbackIntelligenceSurfaceOnRecordReady',
  'betaFeedbackIntelligenceSurfacePostSave',
  'helpedTrackingPrompt',
  'showHelpedTracking',
  'showReturnCheckPayoff',
  'showArchiveSummaryOnRecord',
  'confirmedRepeatChangeNoticeOnRecord',
  'lowEvidenceGuidance',
  'quietSignalCandidate',
  'showQuietSignalOnRecord',
  'showLowEvidenceGuidanceOnRecord',
  'dailyThoughtprintmoryCandidate',
  'firstProofLoopActive',
  'showDailyThoughtprintmory',
  'showReturningWatchTargetFocusedUi',
  'recordReadyShowsWatchTargetOnly',
  'recordReadySuppressStreakPressure',
  'betaTestScriptCardCandidate',
  'showBetaTestScriptCard',
  'daysSinceLastEntry',
  'showReturnedAfterDelayRecovery',
  'nextBestActionCandidate',
  'showNextBestActionOnRecord',
  'postSaveReturnHandoffCandidate',
  'returnTomorrowCuePostSave',
  'postSaveDegradedForReturnCue',
  'comeBackTomorrowV2PostSaveWatch',
  'showComeBackTomorrowV2PostSave',
  'showPostSaveCuriosityHook',
  'betaFeedbackCapturePostSavePreAudit',
  'showBetaFeedbackCapturePostSave',
  'betaFeedbackCapturePostSaveResult',
  'postSaveProofFloorRescueInput',
  'blocksProByProofFloorOnPostSave',
  'recordPostSaveSurfacePriority',
  'postSaveLoosenSignals',
  'postSaveProTiming',
  'betaFeedbackCapturePostSaveFinal',
  'proPreviewPostSaveResult',
  'betaInviteLoopPostSaveResult',
  'proBridgeVisibilityPostSaveResult',
  'showReturnTomorrowCuePostSave',
  'firstWeekProgressPostSave',
  'showFirstWeekProgressPostSave',
  'showPostSaveReturnHandoff',
  'beliefUpdatePayoff',
  'journalShareProof',
  'shareableProof',
  'returnLoopPayoff',
  'postSaveDailyMirror',
  'postSaveArchiveHierarchy',
  'suppressNoisyRepeatPostSaveCards',
  'repeatPostSaveThoughtMapPreview',
  'showDegradedTranscriptFocusedPostSave',
  'suppressDegradedTranscriptPostSaveCompetitors',
  'returningUserToday',
  'nextMomentPrompt',
  'dailyArchiveExercise',
  'todaysOneQuestion',
  'recordHomeSurface',
  'showArchiveProgressCards',
  'readyCapturePolicy',
  'showTesterMission',
  'showRecordCaptureModes',
  'testerMissionCompact',
  'showTesterMissionFull',
  'testerMission',
  'showThoughtMapRecordCta',
  'showPositiveReinforcementRecordCta',
  'showPatternChangedRecordCta',
  'showArchiveSummaryRecordCta',
  'showDailyReturnReasonRecordCta',
  'showFirstWeekLoopRecordCta',
];
