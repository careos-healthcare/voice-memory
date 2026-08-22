import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';

enum ProPlacementTriggerAuditOutcome {
  inactive,
  eligibleAndShown,
  blockedNoUsefulProof,
  blockedWeakProof,
  blockedNegativeFeedback,
  blockedNoStrongAnchor,
  blockedAlreadyShown,
  blockedNotBetaRepairMode,
  unknown,
}

class ProPlacementTriggerAuditInput {
  const ProPlacementTriggerAuditInput({
    required this.betaMissionEnabled,
    required this.activeRepairMode,
    required this.entryCount,
    required this.confidenceLevel,
    required this.hasSafeAnchor,
    required this.hasMatchQuality,
    required this.hasConfirmedRepeat,
    required this.hasTimelineProofVisible,
    required this.feedbackType,
    required this.hasUsefulOrStrongProof,
    required this.proPlacementEligible,
    required this.proPlacementShown,
    required this.proPlacementBlocked,
    required this.hasProEngagement,
    required this.source,
  });

  final bool betaMissionEnabled;
  final BetaRepairLabMode activeRepairMode;
  final int entryCount;
  final ProofConfidenceLevel confidenceLevel;
  final bool hasSafeAnchor;
  final bool hasMatchQuality;
  final bool hasConfirmedRepeat;
  final bool hasTimelineProofVisible;
  final BetaProofFeedbackType? feedbackType;
  final bool hasUsefulOrStrongProof;
  final bool proPlacementEligible;
  final bool proPlacementShown;
  final bool proPlacementBlocked;
  final bool hasProEngagement;
  final String source;
}

class ProPlacementTriggerAuditResult {
  const ProPlacementTriggerAuditResult({
    required this.shouldShow,
    required this.outcome,
    required this.title,
    required this.body,
    required this.blockReason,
    required this.activeRepairModeLabel,
    required this.warning,
    required this.source,
    required this.entryCount,
  });

  static const hidden = ProPlacementTriggerAuditResult(
    shouldShow: false,
    outcome: ProPlacementTriggerAuditOutcome.inactive,
    title: '',
    body: '',
    blockReason: '',
    activeRepairModeLabel: '',
    warning: '',
    source: '',
    entryCount: 0,
  );

  final bool shouldShow;
  final ProPlacementTriggerAuditOutcome outcome;
  final String title;
  final String body;
  final String blockReason;
  final String activeRepairModeLabel;
  final String warning;
  final String source;
  final int entryCount;
}

extension ProPlacementTriggerAuditOutcomeAnalytics
    on ProPlacementTriggerAuditOutcome {
  String get analyticsValue => switch (this) {
    ProPlacementTriggerAuditOutcome.inactive => 'inactive',
    ProPlacementTriggerAuditOutcome.eligibleAndShown => 'eligible_and_shown',
    ProPlacementTriggerAuditOutcome.blockedNoUsefulProof =>
      'blocked_no_useful_proof',
    ProPlacementTriggerAuditOutcome.blockedWeakProof => 'blocked_weak_proof',
    ProPlacementTriggerAuditOutcome.blockedNegativeFeedback =>
      'blocked_negative_feedback',
    ProPlacementTriggerAuditOutcome.blockedNoStrongAnchor =>
      'blocked_no_strong_anchor',
    ProPlacementTriggerAuditOutcome.blockedAlreadyShown =>
      'blocked_already_shown',
    ProPlacementTriggerAuditOutcome.blockedNotBetaRepairMode =>
      'blocked_not_beta_repair_mode',
    ProPlacementTriggerAuditOutcome.unknown => 'unknown',
  };
}