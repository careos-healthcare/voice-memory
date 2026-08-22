import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_floor_rescue/proof_floor_rescue_copy.dart';

class ProofFloorRescueInput {
  const ProofFloorRescueInput({
    required this.entryCount,
    required this.source,
    required this.isPro,
    required this.hasTimelineProofVisible,
    required this.hasConfirmedRepeat,
    required this.confidenceLevel,
    required this.hasSafeAnchor,
    required this.hasLowMatchQuality,
    required this.usefulFeedbackCount,
    required this.isRecording, required this.isDegradedTranscriptState, required this.whatChangedQuestionActive, required this.patternReviewInboxHasActiveItems, this.latestFeedbackType,
    this.feedbackAnsweredToday = false,
    this.surface = BetaProofFeedbackSurface.timelineProofMoment,
  });

  final int entryCount;
  final String source;
  final bool isPro;
  final bool hasTimelineProofVisible;
  final bool hasConfirmedRepeat;
  final ProofConfidenceLevel confidenceLevel;
  final bool hasSafeAnchor;
  final bool hasLowMatchQuality;
  final int usefulFeedbackCount;
  final BetaProofFeedbackType? latestFeedbackType;
  final bool feedbackAnsweredToday;
  final bool isRecording;
  final bool isDegradedTranscriptState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final BetaProofFeedbackSurface surface;
}

class ProofFloorRescueResult {
  const ProofFloorRescueResult({
    required this.shouldShow,
    required this.state,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.showFeedbackOptions, required this.source, required this.entryCount, required this.confidenceLevel, required this.surface, this.secondaryCta,
  });

  static const hidden = ProofFloorRescueResult(
    shouldShow: false,
    state: ProofFloorRescueState.waitForClearerEvidence,
    title: '',
    body: '',
    primaryCta: '',
    showFeedbackOptions: false,
    source: '',
    entryCount: 0,
    confidenceLevel: ProofConfidenceLevel.watchOnly,
    surface: BetaProofFeedbackSurface.timelineProofMoment,
  );

  final bool shouldShow;
  final ProofFloorRescueState state;
  final String title;
  final String body;
  final String primaryCta;
  final String? secondaryCta;
  final bool showFeedbackOptions;
  final String source;
  final int entryCount;
  final ProofConfidenceLevel confidenceLevel;
  final BetaProofFeedbackSurface surface;
}

class ProofFloorRescueRepairFocus {
  const ProofFloorRescueRepairFocus({
    required this.focus,
    required this.title,
    required this.body,
    required this.label,
  });

  final ProofFloorRescueRepairFocusId focus;
  final String title;
  final String body;
  final String label;
}