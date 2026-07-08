import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'first_session_proof_repair_copy.dart';

enum FirstSessionProofRepairChipId {
  keptCheckingAgain,
  avoidedReplying,
  wantedControl,
  couldNotLetGo,
  feltFamiliar,
}

enum FirstSessionProofRepairFocusId {
  usefulProofQuality,
  firstSessionCapture,
  continueTesting,
}

class FirstSessionProofRepairChip {
  const FirstSessionProofRepairChip({
    required this.id,
    required this.text,
  });

  final FirstSessionProofRepairChipId id;
  final String text;
}

class FirstSessionCaptureRepairResult {
  const FirstSessionCaptureRepairResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.primaryCta,
    required this.secondaryCta,
    required this.microcopy,
    required this.typedCapturePrompt,
    required this.chips,
    required this.entryCount,
    required this.source,
  });

  static const hidden = FirstSessionCaptureRepairResult(
    shouldShow: false,
    title: '',
    body: '',
    primaryCta: '',
    secondaryCta: '',
    microcopy: '',
    typedCapturePrompt: '',
    chips: [],
    entryCount: 0,
    source: '',
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String primaryCta;
  final String secondaryCta;
  final String microcopy;
  final String typedCapturePrompt;
  final List<FirstSessionProofRepairChip> chips;
  final int entryCount;
  final String source;
}

class ProofQualityRepairResult {
  const ProofQualityRepairResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.cta,
    required this.source,
    required this.entryCount,
    required this.confidenceLevel,
    required this.surface,
  });

  static const hidden = ProofQualityRepairResult(
    shouldShow: false,
    title: '',
    body: '',
    cta: '',
    source: '',
    entryCount: 0,
    confidenceLevel: ProofConfidenceLevel.watchOnly,
    surface: BetaProofFeedbackSurface.timelineProofMoment,
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String cta;
  final String source;
  final int entryCount;
  final ProofConfidenceLevel confidenceLevel;
  final BetaProofFeedbackSurface surface;
}

class ProofQualityRepairVisibilityInput {
  const ProofQualityRepairVisibilityInput({
    required this.entryCount,
    required this.source,
    required this.hasTimelineProofVisible,
    required this.hasConfirmedRepeat,
    required this.confidenceLevel,
    required this.usefulFeedbackCount,
    required this.negativeFeedbackCount,
    required this.betaProofFeedbackRowVisible,
    required this.isRecording,
    required this.isDegradedTranscriptState,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
  });

  final int entryCount;
  final String source;
  final bool hasTimelineProofVisible;
  final bool hasConfirmedRepeat;
  final ProofConfidenceLevel confidenceLevel;
  final int usefulFeedbackCount;
  final int negativeFeedbackCount;
  final bool betaProofFeedbackRowVisible;
  final bool isRecording;
  final bool isDegradedTranscriptState;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
}

class FirstSessionProofRepairFocus {
  const FirstSessionProofRepairFocus({
    required this.focus,
    required this.label,
  });

  final FirstSessionProofRepairFocusId focus;
  final String label;
}
