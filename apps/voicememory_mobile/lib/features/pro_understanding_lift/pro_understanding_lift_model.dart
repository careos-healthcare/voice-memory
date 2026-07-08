import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../proof_quality_response/proof_quality_response_model.dart';
import 'pro_understanding_lift_copy.dart';

class ProUnderstandingLiftResult {
  const ProUnderstandingLiftResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.bullets,
    required this.supportLine,
    required this.primaryCta,
    required this.secondaryCta,
    required this.source,
    required this.surface,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.hasPaywallSeen,
  });

  static const hidden = ProUnderstandingLiftResult(
    shouldShow: false,
    title: '',
    body: '',
    bullets: [],
    supportLine: '',
    primaryCta: '',
    secondaryCta: '',
    source: '',
    surface: ProUnderstandingLiftSurface.recordReady,
    entryCount: 0,
    hasUsefulProof: false,
    hasPaywallSeen: false,
  );

  final bool shouldShow;
  final String title;
  final String body;
  final List<String> bullets;
  final String supportLine;
  final String primaryCta;
  final String secondaryCta;
  final String source;
  final ProUnderstandingLiftSurface surface;
  final int entryCount;
  final bool hasUsefulProof;
  final bool hasPaywallSeen;
}

class ProUnderstandingLiftVisibilityInput {
  const ProUnderstandingLiftVisibilityInput({
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.isPro,
    required this.hasUsefulProof,
    required this.confidenceLevel,
    required this.feedbackState,
    required this.hasProEngagement,
    required this.hasFreshReturnAfterCorrection,
    required this.hasChangeAnchor,
    required this.isRecording,
    required this.isDegradedTranscriptState,
    required this.isPostSaveDegradedState,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
  });

  final ProUnderstandingLiftSurface surface;
  final String source;
  final int entryCount;
  final bool isPro;
  final bool hasUsefulProof;
  final ProofConfidenceLevel confidenceLevel;
  final ProofQualityFeedbackState feedbackState;
  final bool hasProEngagement;
  final bool hasFreshReturnAfterCorrection;
  final bool hasChangeAnchor;
  final bool isRecording;
  final bool isDegradedTranscriptState;
  final bool isPostSaveDegradedState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
}
