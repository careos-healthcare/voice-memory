import '../beta_feedback/beta_feedback_models.dart';

/// Read-only beta validation snapshot — counts and booleans only.
class BetaOutcomesSnapshot {
  const BetaOutcomesSnapshot({
    required this.savedMomentCount,
    required this.usableEvidenceCount,
    required this.depthLevelLabel,
    required this.watchThemesCount,
    required this.returnRitualSet,
    required this.feedbackStatusLabel,
    required this.optionalNotePresent,
    required this.testimonialCopied,
    required this.shareProofReady,
    required this.interpretations,
    required this.feedbackState,
  });

  final int savedMomentCount;
  final int usableEvidenceCount;
  final String depthLevelLabel;
  final int watchThemesCount;
  final bool returnRitualSet;
  final String feedbackStatusLabel;
  final bool optionalNotePresent;
  final bool testimonialCopied;
  final bool shareProofReady;
  final List<String> interpretations;
  final BetaFeedbackState feedbackState;
}

/// Local inputs for deterministic beta outcomes — metadata only.
class BetaOutcomesInput {
  const BetaOutcomesInput({
    required this.savedMomentCount,
    required this.usableEvidenceCount,
    required this.depthLevelLabel,
    required this.watchThemesCount,
    required this.returnRitualSet,
    required this.feedbackState,
    required this.shareProofReady,
  });

  final int savedMomentCount;
  final int usableEvidenceCount;
  final String depthLevelLabel;
  final int watchThemesCount;
  final bool returnRitualSet;
  final BetaFeedbackState feedbackState;
  final bool shareProofReady;
}
