import 'package:archiveme_mobile/features/recording/recording_dependencies.dart';

/// Mutable ready-surface locals for RecordSurfaceResolver.resolve.
/// Populated by the ready-education / first-proof / first-session pipeline
/// and rewritten in place by later ready-audit phases.
final class RecordReadySurfaceBag {
  bool showCurrentRelevanceOnRecordReady = false;
  bool showCorrectionMemoryOnRecordReady = false;
  bool showEvidenceWeightingOnRecordReady = false;
  bool showProofSpecificityOnRecordReady = false;
  bool showPresentDayRelevanceOnRecordReady = false;
  bool showCaptureFreedomLine = false;
  bool showTimelinePositioningOnRecordReady = false;
  bool showPatternConfidenceExplanationOnRecordReady = false;
  bool showProEvidenceValueOnRecordReady = false;
  bool showProBridgeVisibilityOnRecordReady = false;
  bool showProEvidenceValuePrivateReportOnRecord = false;
  bool showFirstProofPayoff = false;
  bool showOpenCapturePromptChips = false;
  bool showLowFrictionReturnCard = false;
  late FirstSessionCaptureRepairResult firstSessionCaptureRepairCandidate;
  bool showFirstSessionCaptureRepairCard = false;
  bool showFirstSessionLiftCard = false;
  bool showFirstSaveLiftCard = false;
  bool showFirstMomentCaptureCard = false;
  bool showSecondMomentReturnCard = false;
  bool showThreeMomentCompletionCard = false;
  bool showFirstRunPositioningCard = false;
  bool showBetaTodaySummaryCard = false;
  bool showWhatToNoticeNextCard = false;
  bool showArchiveTimelineSpineOnRecord = false;
  bool showTimelineProofMomentOnRecord = false;
  bool showBetaTesterReportOnRecord = false;
  bool showReturnAfterProofStrengthenedOnRecordReady = false;
  bool showReturnAfterProofGenericOnRecordReady = false;
  bool showReturnAfterProofOnRecordReady = false;
  bool showReturnAfterProofLiftV2OnRecordReady = false;
  bool showBetaRepairLabProPlacementOnRecord = false;
  bool showBetaRepairLabPricingValueFramingOnRecord = false;
  bool showBetaRepairLabPaywallValueOnRecord = false;
  bool showBetaRepairLabPricingValidationOnRecord = false;
  bool showBetaRepairLabEvidenceTrailClarityOnRecord = false;
  bool showProUnderstandingLiftOnRecordReady = false;
  bool showProVisibilityLiftOnRecordReady = false;
  ProUnderstandingLiftResult? proUnderstandingLiftRecordReadyResult;
  bool showProofQualityResponseOnRecordReady = false;
  bool showNotRelevantRecoveryOnRecordReady = false;
  bool showBetaProofLiftOnRecordReady = false;
  bool showBetaActivationPathCard = false;
  BetaActivationPathResult? betaActivationPathResult;
  bool showBetaFeedbackCaptureRecordReady = false;
  BetaFeedbackCaptureResult? betaFeedbackCaptureRecordReadyResult;
  bool showProofQualityRepairOnRecord = false;
  bool showProofFloorRescueOnRecord = false;
  bool showBetaRepairLabProofOnRecord = false;
}
