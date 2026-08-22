import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';

enum ProBridgeVisibilitySurface {
  recordReady,
  recordPostSaveAfterPayoff,
  archivePatterns,
}

extension ProBridgeVisibilitySurfaceStorage on ProBridgeVisibilitySurface {
  String get analyticsValue => switch (this) {
    ProBridgeVisibilitySurface.recordReady => 'record_ready',
    ProBridgeVisibilitySurface.recordPostSaveAfterPayoff =>
      'record_post_save_after_payoff',
    ProBridgeVisibilitySurface.archivePatterns => 'archive_patterns',
  };
}

class ProBridgeVisibilityInput {
  const ProBridgeVisibilityInput({
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.isPro,
    required this.postProofProBridgeEnabled,
    required this.hasFirstProof,
    this.isRecording = false,
    this.isZeroEntryState = false,
    this.isFirstRecordingState = false,
    this.isPostSaveDegradedState = false,
    this.isDegradedTranscriptState = false,
    this.hasTimelineProofVisible = false,
    this.hasFirstProofPayoffVisible = false,
    this.hasBetaTesterReportVisible = false,
    this.hasCorrectionMemoryVisible = false,
    this.hasMonthlyPrivateReportPreviewVisible = false,
    this.hasBetaProofLiftVisible = false,
    this.hasReturnAfterProofStrengthenedVisible = false,
    this.feedbackState = ProofQualityFeedbackState.none,
    this.whatChangedQuestionActive = false,
    this.patternReviewInboxHasActiveItems = false,
    this.proSlotAvailable = true,
    this.compact = false,
    this.confidenceLevel,
    this.hasSafeAnchor = false,
    this.hasFreshReturnAfterCorrection = false,
    this.hasSolidStrongPatternWithSafeAnchors = false,
    this.hasSeenFirstRepeat = false,
    this.hasOpenedEvidenceTrail = false,
  });

  final ProBridgeVisibilitySurface surface;
  final String source;
  final int entryCount;
  final bool isPro;
  final bool postProofProBridgeEnabled;
  final bool hasFirstProof;
  final bool isRecording;
  final bool isZeroEntryState;
  final bool isFirstRecordingState;
  final bool isPostSaveDegradedState;
  final bool isDegradedTranscriptState;
  final bool hasTimelineProofVisible;
  final bool hasFirstProofPayoffVisible;
  final bool hasBetaTesterReportVisible;
  final bool hasCorrectionMemoryVisible;
  final bool hasMonthlyPrivateReportPreviewVisible;
  final bool hasBetaProofLiftVisible;
  final bool hasReturnAfterProofStrengthenedVisible;
  final ProofQualityFeedbackState feedbackState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool proSlotAvailable;
  final bool compact;
  final ProofConfidenceLevel? confidenceLevel;
  final bool hasSafeAnchor;
  final bool hasFreshReturnAfterCorrection;
  final bool hasSolidStrongPatternWithSafeAnchors;
  final bool hasSeenFirstRepeat;
  final bool hasOpenedEvidenceTrail;
}

class ProBridgeVisibilityResult {
  const ProBridgeVisibilityResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.cta,
    required this.secondary,
    required this.entryCount,
    required this.source,
    required this.surface,
    required this.triggerReason,
    required this.hasTimelineProof,
    required this.feedbackState,
    this.confidenceLevel,
    this.hasSafeAnchor = false,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final String cta;
  final String secondary;
  final int entryCount;
  final String source;
  final ProBridgeVisibilitySurface surface;
  final String? triggerReason;
  final bool hasTimelineProof;
  final ProofQualityFeedbackState feedbackState;
  final ProofConfidenceLevel? confidenceLevel;
  final bool hasSafeAnchor;
}