import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_copy.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_copy.dart';
import 'package:archiveme_mobile/features/pro_placement_trigger_audit/pro_placement_trigger_audit_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:flutter/foundation.dart';

/// Beta/testing diagnostics for why Pro placement did or did not appear.
abstract final class ProPlacementTriggerAuditEngine {
  ProPlacementTriggerAuditEngine._();

  static ProPlacementTriggerAuditInput? _latestInput;

  static ProPlacementTriggerAuditInput? get latestInput => _latestInput;

  static void updateLatestInput(ProPlacementTriggerAuditInput input) {
    _latestInput = input;
  }

  static bool shouldShow({required bool betaMissionEnabled}) =>
      betaMissionEnabled && ArchiveBetaMissionGate.isEnabled;

  static ProPlacementTriggerAuditResult build({
    required ProPlacementTriggerAuditInput input,
  }) {
    if (!shouldShow(betaMissionEnabled: input.betaMissionEnabled)) {
      return ProPlacementTriggerAuditResult.hidden;
    }

    final outcome = resolveOutcome(input);
    return ProPlacementTriggerAuditResult(
      shouldShow: true,
      outcome: outcome,
      title: ProPlacementTriggerAuditCopy.titleFor(outcome),
      body: ProPlacementTriggerAuditCopy.bodyFor(outcome),
      blockReason: ProPlacementTriggerAuditCopy.blockReasonFor(outcome),
      activeRepairModeLabel: BetaRepairLabCopy.modeLabel(
        input.activeRepairMode,
      ),
      warning: ProPlacementTriggerAuditCopy.warning,
      source: input.source,
      entryCount: input.entryCount,
    );
  }

  static ProPlacementTriggerAuditOutcome resolveOutcome(
    ProPlacementTriggerAuditInput input,
  ) {
    if (!input.betaMissionEnabled) {
      return ProPlacementTriggerAuditOutcome.inactive;
    }
    if (input.activeRepairMode !=
        BetaRepairLabMode.proPlacementAfterUsefulProof) {
      return ProPlacementTriggerAuditOutcome.inactive;
    }
    if (input.feedbackType == BetaProofFeedbackType.tooVague ||
        input.feedbackType == BetaProofFeedbackType.notRelevant) {
      return ProPlacementTriggerAuditOutcome.blockedNegativeFeedback;
    }
    if (input.hasProEngagement) {
      return ProPlacementTriggerAuditOutcome.blockedAlreadyShown;
    }
    if (!input.hasUsefulOrStrongProof) {
      return ProPlacementTriggerAuditOutcome.blockedNoUsefulProof;
    }
    if (_isWeakConfidence(input.confidenceLevel)) {
      return ProPlacementTriggerAuditOutcome.blockedWeakProof;
    }
    if (!input.hasSafeAnchor) {
      return ProPlacementTriggerAuditOutcome.blockedNoStrongAnchor;
    }
    if (input.proPlacementEligible && input.proPlacementShown) {
      return ProPlacementTriggerAuditOutcome.eligibleAndShown;
    }
    if (input.proPlacementEligible && !input.proPlacementShown) {
      return ProPlacementTriggerAuditOutcome.unknown;
    }
    if (input.proPlacementBlocked) {
      return ProPlacementTriggerAuditOutcome.unknown;
    }
    return ProPlacementTriggerAuditOutcome.unknown;
  }

  static bool hasUsefulOrStrongProof({
    required BetaProofFeedbackType? feedbackType,
    required ProofConfidenceLevel confidenceLevel,
  }) {
    if (feedbackType == BetaProofFeedbackType.useful) return true;
    return confidenceLevel == ProofConfidenceLevel.useful ||
        confidenceLevel == ProofConfidenceLevel.strong ||
        confidenceLevel == ProofConfidenceLevel.freshReturn;
  }

  static bool _isWeakConfidence(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.watchOnly ||
      level == ProofConfidenceLevel.emerging;

  @visibleForTesting
  static void resetForTest() {
    _latestInput = null;
  }
}