import 'package:archiveme_mobile/features/recording/recording_dependencies.dart';

/// Mutable post-save-surface locals for RecordSurfaceResolver.resolve.
/// Populated by the post-save card pipeline (I-A / I-B) and rewritten
/// in place by the post-save audit and later residual wipes.
final class RecordPostSaveSurfaceBag {
  bool showTimelineProofMomentOnFirstProofPayoff = false;
  bool showProofSpecificityOnFirstProofPayoff = false;
  bool showProofSpecificityBoostOnFirstProofPayoff = false;
  bool showProofSpecificityBoostOnTimelineProofPostSave = false;
  bool showBetaProofLiftOnFirstProofPayoff = false;
  bool showBetaProofLiftUnderTimelineProofPostSave = false;
  bool showReturnAfterProofStrengthenedOnFirstProofPayoff = false;
  bool showReturnAfterProofGenericOnFirstProofPayoff = false;
  bool showReturnAfterProofLiftV2OnPostSave = false;
  bool showProUnderstandingLiftOnPostSave = false;
  bool showProVisibilityLiftOnPostSave = false;
  bool showProEvidenceValuePostSave = false;
  bool showBetaInviteLoopPostSave = false;
  bool showProPreviewPostSave = false;
  bool showProBridgeVisibilityPostSave = false;
  bool showProLockMomentPostSave = false;
  bool showMonthlyPrivateReportPreviewPostSave = false;
  bool showComeBackTomorrowV2PostSave = false;
  bool showBetaFeedbackCapturePostSave = false;
  BetaFeedbackCaptureResult? betaFeedbackCapturePostSaveResult;

  late ProofSpecificityResult proofSpecificityPostSaveCandidate;
  late ProofSpecificityBoostResult proofSpecificityBoostPostSaveCandidate;
  late ProofQualityResponseResult proofQualityResponseFirstProofCandidate;
  late ProofQualityResponseResult proofQualityResponseTimelinePostSaveCandidate;
  late BetaProofLiftResult betaProofLiftFirstProofCandidate;
  late BetaProofLiftResult betaProofLiftTimelinePostSaveCandidate;
  late ReturnAfterProofResult returnAfterProofPostSaveCandidate;
  bool firstProofPayoffParentVisible = false;
  bool showProofQualityResponseOnFirstProofPayoff = false;
  bool timelineProofPostSaveParentVisible = false;
  bool showProofQualityResponseOnTimelineProofPostSave = false;
  late ReturnAfterProofLiftV2Result returnAfterProofLiftV2PostSaveCandidate;
  late ProBridgeTimingLoosenSignals postSaveLoosenSignalsPreAudit;
  late EvidenceAnchorExtractionResult postSaveEvidenceAnchorPreAudit;
  late ProofQualityFeedbackState postSaveFeedbackStateForLift;
  bool hasProEngagementOnPostSave = false;
  late ProUnderstandingLiftVisibilityInput proUnderstandingLiftPostSaveInput;
  ProUnderstandingLiftResult? base;
  ProUnderstandingLiftResult? proUnderstandingLiftPostSaveResult;
  ProVisibilityLiftResult? proVisibilityLiftPostSaveResult;
  MonthlyPrivateReportPreview? monthlyPrivateReportPreviewPostSave;

  PostSaveReturnHandoff? postSaveReturnHandoffCandidate;
  ReturnTomorrowCue? returnTomorrowCuePostSave;
  bool postSaveDegradedForReturnCue = false;
  ComeBackTomorrowPostSaveWatch? comeBackTomorrowV2PostSaveWatch;
  bool showPostSaveCuriosityHook = false;
  late BetaFeedbackCaptureResult betaFeedbackCapturePostSavePreAudit;
  late ProofFloorRescueInput postSaveProofFloorRescueInput;
  bool blocksProByProofFloorOnPostSave = false;

  bool get showReturnAfterProofOnFirstProofPayoff =>
      showReturnAfterProofStrengthenedOnFirstProofPayoff ||
      showReturnAfterProofGenericOnFirstProofPayoff;

  bool get hasBetaProofLiftVisible =>
      showBetaProofLiftOnFirstProofPayoff ||
      showBetaProofLiftUnderTimelineProofPostSave;

  bool hasTimelineProofVisible(TimelineProofMomentResult? candidate) =>
      showTimelineProofMomentOnFirstProofPayoff && candidate != null;

  void registerTimelineProofMoment(bool show) {
    showTimelineProofMomentOnFirstProofPayoff = show;
  }

  void registerProofSpecificity(bool show) {
    showProofSpecificityOnFirstProofPayoff = show;
  }

  void registerProofSpecificityBoostOnFirstProof(bool show) {
    showProofSpecificityBoostOnFirstProofPayoff = show;
  }

  void registerProofSpecificityBoostOnTimeline(bool show) {
    showProofSpecificityBoostOnTimelineProofPostSave = show;
  }

  void registerBetaProofLiftOnFirstProof(bool show) {
    showBetaProofLiftOnFirstProofPayoff = show;
  }

  void registerBetaProofLiftOnTimeline(bool show) {
    showBetaProofLiftUnderTimelineProofPostSave = show;
  }

  void registerReturnAfterProof({
    required bool strengthened,
    required bool generic,
  }) {
    showReturnAfterProofStrengthenedOnFirstProofPayoff = strengthened;
    showReturnAfterProofGenericOnFirstProofPayoff = generic;
  }

  void registerReturnAfterProofLiftV2(bool show) {
    showReturnAfterProofLiftV2OnPostSave = show;
  }

  void registerProUnderstandingLift(bool show) {
    showProUnderstandingLiftOnPostSave = show;
  }

  void registerProVisibilityLift(bool show) {
    showProVisibilityLiftOnPostSave = show;
  }

  void registerProEvidenceValue(bool show) {
    showProEvidenceValuePostSave = show;
  }

  void registerBetaInviteLoop(bool show) {
    showBetaInviteLoopPostSave = show;
  }

  void registerProPreview(bool show) {
    showProPreviewPostSave = show;
  }

  void registerProBridgeVisibility(bool show) {
    showProBridgeVisibilityPostSave = show;
  }

  void registerProLockMoment(bool show) {
    showProLockMomentPostSave = show;
  }

  void registerMonthlyPrivateReport(bool show) {
    showMonthlyPrivateReportPreviewPostSave = show;
  }

  void registerComeBackTomorrow(bool show) {
    showComeBackTomorrowV2PostSave = show;
  }

  void registerBetaFeedbackCapture({
    required bool show,
    BetaFeedbackCaptureResult? result,
  }) {
    showBetaFeedbackCapturePostSave = show;
    betaFeedbackCapturePostSaveResult = result;
  }

  void storeProofSpecificityCandidate(ProofSpecificityResult candidate) {
    proofSpecificityPostSaveCandidate = candidate;
  }

  void storeProofSupportCandidates({
    required ProofSpecificityBoostResult boost,
    required ProofQualityResponseResult firstProofQuality,
    required ProofQualityResponseResult timelineQuality,
    required BetaProofLiftResult firstProofLift,
    required BetaProofLiftResult timelineLift,
    required ReturnAfterProofResult returnAfterProof,
  }) {
    proofSpecificityBoostPostSaveCandidate = boost;
    proofQualityResponseFirstProofCandidate = firstProofQuality;
    proofQualityResponseTimelinePostSaveCandidate = timelineQuality;
    betaProofLiftFirstProofCandidate = firstProofLift;
    betaProofLiftTimelinePostSaveCandidate = timelineLift;
    returnAfterProofPostSaveCandidate = returnAfterProof;
  }

  void storeParentVisibility({
    required bool firstProofPayoff,
    required bool timelineProof,
  }) {
    firstProofPayoffParentVisible = firstProofPayoff;
    timelineProofPostSaveParentVisible = timelineProof;
  }

  void storeQualityResponseShows({
    required bool onFirstProofPayoff,
    required bool onTimelineProof,
  }) {
    showProofQualityResponseOnFirstProofPayoff = onFirstProofPayoff;
    showProofQualityResponseOnTimelineProofPostSave = onTimelineProof;
  }

  void storeLiftV2Candidate(ReturnAfterProofLiftV2Result candidate) {
    returnAfterProofLiftV2PostSaveCandidate = candidate;
  }

  void storeLoosenAndEngagement({
    required ProBridgeTimingLoosenSignals loosen,
    required EvidenceAnchorExtractionResult evidence,
    required ProofQualityFeedbackState feedback,
    required bool hasProEngagement,
    required ProUnderstandingLiftVisibilityInput understandingInput,
  }) {
    postSaveLoosenSignalsPreAudit = loosen;
    postSaveEvidenceAnchorPreAudit = evidence;
    postSaveFeedbackStateForLift = feedback;
    hasProEngagementOnPostSave = hasProEngagement;
    proUnderstandingLiftPostSaveInput = understandingInput;
  }

  void storeProUnderstandingResults({
    required ProUnderstandingLiftResult? builtBase,
    required ProUnderstandingLiftResult? result,
  }) {
    base = builtBase;
    proUnderstandingLiftPostSaveResult = result;
  }

  void storeProVisibilityResult(ProVisibilityLiftResult? result) {
    proVisibilityLiftPostSaveResult = result;
  }

  void storeMonthlyReportPreview(MonthlyPrivateReportPreview? preview) {
    monthlyPrivateReportPreviewPostSave = preview;
  }

  void storeReturnCueState({
    required PostSaveReturnHandoff? handoff,
    required ReturnTomorrowCue? returnCue,
    required bool degradedForReturnCue,
    required ComeBackTomorrowPostSaveWatch? watch,
    required bool curiosityHook,
  }) {
    postSaveReturnHandoffCandidate = handoff;
    returnTomorrowCuePostSave = returnCue;
    postSaveDegradedForReturnCue = degradedForReturnCue;
    comeBackTomorrowV2PostSaveWatch = watch;
    showPostSaveCuriosityHook = curiosityHook;
  }

  void storeProofFloor({
    required ProofFloorRescueInput input,
    required bool blocksPro,
  }) {
    postSaveProofFloorRescueInput = input;
    blocksProByProofFloorOnPostSave = blocksPro;
  }

  void suppressProofSpecificityBoostOnFirstProof() {
    showProofSpecificityBoostOnFirstProofPayoff = false;
  }

  void suppressProofSpecificityBoostOnTimeline() {
    showProofSpecificityBoostOnTimelineProofPostSave = false;
  }

  void suppressBetaSurfaces() {
    showBetaProofLiftOnFirstProofPayoff = false;
    showBetaProofLiftUnderTimelineProofPostSave = false;
    showBetaInviteLoopPostSave = false;
    showBetaFeedbackCapturePostSave = false;
    betaFeedbackCapturePostSaveResult = null;
  }

  void suppressProCardsByProofFloor() {
    showProUnderstandingLiftOnPostSave = false;
    showProVisibilityLiftOnPostSave = false;
    showProPreviewPostSave = false;
    showProBridgeVisibilityPostSave = false;
    showProEvidenceValuePostSave = false;
    showProLockMomentPostSave = false;
    showMonthlyPrivateReportPreviewPostSave = false;
  }

  void suppressStrongProofPayoff() {
    showBetaProofLiftOnFirstProofPayoff = false;
    showBetaProofLiftUnderTimelineProofPostSave = false;
  }

  void suppressReturnAfterProofForLiftV2() {
    showReturnAfterProofStrengthenedOnFirstProofPayoff = false;
    showReturnAfterProofGenericOnFirstProofPayoff = false;
  }

  void suppressComeBackTomorrow() {
    showComeBackTomorrowV2PostSave = false;
  }

  void applyPriorityAudit(
    SurfacePriorityResult audit, {
    required TimelineProofMomentResult? timelineProof,
    required bool firstProofPayoffVisible,
    required FirstProofPayoff? firstProofPayoffCandidate,
  }) {
    showTimelineProofMomentOnFirstProofPayoff = audit.isVisible(
      SurfacePriorityCardKey.timelineProofMomentPostSave,
      candidate:
          showTimelineProofMomentOnFirstProofPayoff && timelineProof != null,
    );
    showProofSpecificityOnFirstProofPayoff = audit.isVisible(
      SurfacePriorityCardKey.proofSpecificityPostSave,
      candidate:
          showProofSpecificityOnFirstProofPayoff &&
          proofSpecificityPostSaveCandidate.shouldShow,
    );
    showReturnAfterProofStrengthenedOnFirstProofPayoff = audit.isVisible(
      SurfacePriorityCardKey.returnAfterProofStrengthened,
      candidate:
          showReturnAfterProofStrengthenedOnFirstProofPayoff &&
          firstProofPayoffVisible &&
          firstProofPayoffCandidate != null,
    );
    showReturnAfterProofGenericOnFirstProofPayoff = audit.isVisible(
      SurfacePriorityCardKey.returnAfterProof,
      candidate:
          showReturnAfterProofGenericOnFirstProofPayoff &&
          firstProofPayoffVisible &&
          firstProofPayoffCandidate != null,
    );
    showReturnAfterProofLiftV2OnPostSave = audit.isVisible(
      SurfacePriorityCardKey.returnAfterProofLiftV2,
      candidate:
          showReturnAfterProofLiftV2OnPostSave &&
          firstProofPayoffVisible &&
          firstProofPayoffCandidate != null,
    );
    if (showReturnAfterProofLiftV2OnPostSave) {
      suppressReturnAfterProofForLiftV2();
    }
    showProPreviewPostSave = audit.isVisible(
      SurfacePriorityCardKey.proPreview,
      candidate: showProPreviewPostSave,
    );
    showBetaInviteLoopPostSave = audit.isVisible(
      SurfacePriorityCardKey.betaInviteLoop,
      candidate: showBetaInviteLoopPostSave,
    );
    showProBridgeVisibilityPostSave = audit.isVisible(
      SurfacePriorityCardKey.proBridgeVisibility,
      candidate: showProBridgeVisibilityPostSave,
    );
    showProUnderstandingLiftOnPostSave = audit.isVisible(
      SurfacePriorityCardKey.proUnderstandingLift,
      candidate: showProUnderstandingLiftOnPostSave,
    );
    showProVisibilityLiftOnPostSave = audit.isVisible(
      SurfacePriorityCardKey.proVisibilityLift,
      candidate: showProVisibilityLiftOnPostSave,
    );
    showProEvidenceValuePostSave = audit.isVisible(
      SurfacePriorityCardKey.proEvidenceValue,
      candidate: showProEvidenceValuePostSave,
    );
    showProLockMomentPostSave = audit.isVisible(
      SurfacePriorityCardKey.proLockMoment,
      candidate: showProLockMomentPostSave,
    );
    showBetaFeedbackCapturePostSave = audit.isVisible(
      SurfacePriorityCardKey.betaFeedbackCapture,
      candidate: showBetaFeedbackCapturePostSave,
    );
    betaFeedbackCapturePostSaveResult = showBetaFeedbackCapturePostSave
        ? betaFeedbackCapturePostSavePreAudit
        : null;
  }

  void applyProMomentGates(ProMomentTimingContext timing) {
    showProPreviewPostSave = ProMomentTimingEngine.applyGate(
      candidate: showProPreviewPostSave,
      timing: timing.copyWith(
        proSlotAvailable:
            !showProUnderstandingLiftOnPostSave &&
            !showProVisibilityLiftOnPostSave,
      ),
    );
    showProBridgeVisibilityPostSave = ProMomentTimingEngine.applyGate(
      candidate: showProBridgeVisibilityPostSave,
      timing: timing.copyWith(
        proSlotAvailable:
            !showProUnderstandingLiftOnPostSave &&
            !showProVisibilityLiftOnPostSave &&
            !showProPreviewPostSave,
      ),
    );
    showProEvidenceValuePostSave = ProMomentTimingEngine.applyGate(
      candidate: showProEvidenceValuePostSave,
      timing: timing.copyWith(
        proSlotAvailable:
            !showProUnderstandingLiftOnPostSave &&
            !showProVisibilityLiftOnPostSave &&
            !showProPreviewPostSave &&
            !showProBridgeVisibilityPostSave,
      ),
    );
    showProLockMomentPostSave = ProMomentTimingEngine.applyGate(
      candidate: showProLockMomentPostSave,
      timing: timing.copyWith(
        proSlotAvailable:
            showProLockMomentPostSave &&
            !showProUnderstandingLiftOnPostSave &&
            !showProVisibilityLiftOnPostSave &&
            !showProPreviewPostSave &&
            !showProBridgeVisibilityPostSave,
      ),
    );
    showMonthlyPrivateReportPreviewPostSave = ProMomentTimingEngine.applyGate(
      candidate: showMonthlyPrivateReportPreviewPostSave,
      timing: timing.copyWith(
        hasMonthlyPrivateReportPreviewVisible: true,
        proSlotAvailable:
            showMonthlyPrivateReportPreviewPostSave &&
            !showProUnderstandingLiftOnPostSave &&
            !showProVisibilityLiftOnPostSave &&
            !showProPreviewPostSave &&
            !showProBridgeVisibilityPostSave,
      ),
    );
  }

  void applyBetaFeedbackResult(BetaFeedbackCaptureResult result) {
    showBetaFeedbackCapturePostSave =
        showBetaFeedbackCapturePostSave && result.shouldShow;
    betaFeedbackCapturePostSaveResult = showBetaFeedbackCapturePostSave
        ? result
        : null;
  }
}
