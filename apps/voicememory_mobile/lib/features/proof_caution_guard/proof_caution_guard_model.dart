import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';

enum ProofCautionGuardBlockedReason {
  userMarkedNotRelevant,
  noSafeAnchor,
  genericWordingOnly,
  entriesUnrelated,
  degradedTranscript,
  correctionBackground,
}

extension ProofCautionGuardBlockedReasonAnalytics
    on ProofCautionGuardBlockedReason {
  String get analyticsValue => switch (this) {
    ProofCautionGuardBlockedReason.userMarkedNotRelevant =>
      'user_marked_not_relevant',
    ProofCautionGuardBlockedReason.noSafeAnchor => 'no_safe_anchor',
    ProofCautionGuardBlockedReason.genericWordingOnly => 'generic_wording_only',
    ProofCautionGuardBlockedReason.entriesUnrelated => 'entries_unrelated',
    ProofCautionGuardBlockedReason.degradedTranscript => 'degraded_transcript',
    ProofCautionGuardBlockedReason.correctionBackground =>
      'correction_background',
  };
}

enum ProofCautionGuardUpgradeReason { watchOnlyRollback, emergingRollback }

extension ProofCautionGuardUpgradeReasonAnalytics
    on ProofCautionGuardUpgradeReason {
  String get analyticsValue => switch (this) {
    ProofCautionGuardUpgradeReason.watchOnlyRollback => 'watch_only_rollback',
    ProofCautionGuardUpgradeReason.emergingRollback => 'emerging_rollback',
  };
}

class ProofCautionGuardResult {
  const ProofCautionGuardResult({
    required this.calibration,
    required this.applied,
    required this.originalLevel,
    required this.adjustedLevel,
    this.reason,
    this.blockedReason,
  });

  final ProofConfidenceCalibrationResult calibration;
  final bool applied;
  final ProofConfidenceLevel originalLevel;
  final ProofConfidenceLevel adjustedLevel;
  final ProofCautionGuardUpgradeReason? reason;
  final ProofCautionGuardBlockedReason? blockedReason;
}
