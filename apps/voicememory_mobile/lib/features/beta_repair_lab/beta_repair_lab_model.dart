import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';

enum BetaRepairLabMode {
  none,
  openingScreenSimplification,
  proofSpecificityCaution,
  proPlacementAfterUsefulProof,
  proExplanation,
  paywallValue,
  pricingValueFraming,
  pricingValidation,
  evidenceTrailTimelineClarity,
}

enum BetaRepairLabProofVariant {
  weak,
  strong,
}

class BetaRepairLabModeInfo {
  const BetaRepairLabModeInfo({
    required this.mode,
    required this.label,
    required this.fixes,
    required this.whenToUse,
    required this.changes,
    required this.doNotTouch,
  });

  final BetaRepairLabMode mode;
  final String label;
  final String fixes;
  final String whenToUse;
  final String changes;
  final String doNotTouch;
}

class BetaRepairLabProofResult {
  const BetaRepairLabProofResult({
    required this.shouldShow,
    required this.variant,
    required this.title,
    required this.body,
    required this.whyAppearedLine,
    required this.feedbackPrompt,
    required this.source,
    required this.entryCount,
  });

  static const hidden = BetaRepairLabProofResult(
    shouldShow: false,
    variant: BetaRepairLabProofVariant.weak,
    title: '',
    body: '',
    whyAppearedLine: '',
    feedbackPrompt: '',
    source: '',
    entryCount: 0,
  );

  final bool shouldShow;
  final BetaRepairLabProofVariant variant;
  final String title;
  final String body;
  final String whyAppearedLine;
  final String feedbackPrompt;
  final String source;
  final int entryCount;
}

class BetaRepairLabProPlacementResult {
  const BetaRepairLabProPlacementResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.source,
    required this.entryCount,
  });

  static const hidden = BetaRepairLabProPlacementResult(
    shouldShow: false,
    title: '',
    body: '',
    primaryCta: '',
    secondaryCta: '',
    source: '',
    entryCount: 0,
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final String source;
  final int entryCount;
}

class BetaRepairLabVisibilityInput {
  const BetaRepairLabVisibilityInput({
    required this.mode,
    required this.entryCount,
    required this.source,
    required this.isPro,
    required this.isRecording,
    required this.isDegradedTranscriptState,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    required this.hasTimelineProofVisible,
    required this.hasConfirmedRepeat,
    required this.confidenceLevel,
    required this.hasUsefulProofFeedback,
    required this.feedbackType,
    required this.isNegativeFeedback,
    required this.betaMissionEnabled,
  });

  final BetaRepairLabMode mode;
  final int entryCount;
  final String source;
  final bool isPro;
  final bool isRecording;
  final bool isDegradedTranscriptState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final bool hasTimelineProofVisible;
  final bool hasConfirmedRepeat;
  final ProofConfidenceLevel confidenceLevel;
  final bool hasUsefulProofFeedback;
  final BetaProofFeedbackType? feedbackType;
  final bool isNegativeFeedback;
  final bool betaMissionEnabled;
}

class BetaRepairLabState {
  const BetaRepairLabState({
    required this.mode,
    required this.localMode,
    required this.activeModeLabel,
    required this.warning,
    required this.buildOverrideActive,
    required this.defaultBaselineActive,
    this.buildOverrideLabel,
    this.defaultBaselineStatusLabel,
  });

  final BetaRepairLabMode mode;
  final BetaRepairLabMode localMode;
  final String activeModeLabel;
  final String warning;
  final bool buildOverrideActive;
  final bool defaultBaselineActive;
  final String? buildOverrideLabel;
  final String? defaultBaselineStatusLabel;
}
