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
  bool showReturnAfterProofOnFirstProofPayoff = false;
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
}
