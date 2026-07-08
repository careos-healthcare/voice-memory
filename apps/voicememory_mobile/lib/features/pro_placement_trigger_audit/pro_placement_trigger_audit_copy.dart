import 'pro_placement_trigger_audit_model.dart';

/// Pro placement trigger audit copy — metadata-safe diagnostics only.
abstract final class ProPlacementTriggerAuditCopy {
  ProPlacementTriggerAuditCopy._();

  static const cardTitle = 'Pro placement trigger audit';
  static const activeRepairLabel = 'Active repair mode';
  static const outcomeLabel = 'Audit outcome';
  static const blockReasonLabel = 'Block reason';
  static const warning =
      'Do not make Pro more aggressive until this audit is understood.';
  static const localNote = 'Diagnostics only. Does not change Pro placement.';

  static const inactiveTitle = 'Pro placement audit inactive';
  static const inactiveBody =
      'This audit only matters when the Pro placement repair is active.';

  static const eligibleAndShownTitle = 'Pro placement is eligible';
  static const eligibleAndShownBody =
      'A useful proof was found and the Pro card should be shown.';

  static const blockedNoUsefulProofTitle = 'Pro blocked: no useful proof';
  static const blockedNoUsefulProofBody =
      'The user has not reached a useful proof moment yet. Do not push Pro earlier.';

  static const blockedWeakProofTitle = 'Pro blocked: proof too weak';
  static const blockedWeakProofBody =
      'The proof is still watch-only or cautious. Pro should stay hidden.';

  static const blockedNegativeFeedbackTitle =
      'Pro blocked: negative proof feedback';
  static const blockedNegativeFeedbackBody =
      'The user marked the proof too vague or not relevant. Pro should stay hidden.';

  static const blockedNoStrongAnchorTitle = 'Pro blocked: weak evidence anchor';
  static const blockedNoStrongAnchorBody =
      'The proof does not have a strong enough anchor yet.';

  static const blockedAlreadyShownTitle = 'Pro already shown';
  static const blockedAlreadyShownBody =
      'The Pro card was already shown once. Do not stack Pro cards.';

  static const blockedNotBetaRepairModeTitle = 'Pro placement repair not active';
  static const blockedNotBetaRepairModeBody =
      'This build is not testing Pro placement.';

  static const unknownTitle = 'Pro placement unclear';
  static const unknownBody =
      'The audit could not determine why Pro was hidden.';

  static String titleFor(ProPlacementTriggerAuditOutcome outcome) =>
      switch (outcome) {
        ProPlacementTriggerAuditOutcome.inactive => inactiveTitle,
        ProPlacementTriggerAuditOutcome.eligibleAndShown => eligibleAndShownTitle,
        ProPlacementTriggerAuditOutcome.blockedNoUsefulProof =>
          blockedNoUsefulProofTitle,
        ProPlacementTriggerAuditOutcome.blockedWeakProof => blockedWeakProofTitle,
        ProPlacementTriggerAuditOutcome.blockedNegativeFeedback =>
          blockedNegativeFeedbackTitle,
        ProPlacementTriggerAuditOutcome.blockedNoStrongAnchor =>
          blockedNoStrongAnchorTitle,
        ProPlacementTriggerAuditOutcome.blockedAlreadyShown =>
          blockedAlreadyShownTitle,
        ProPlacementTriggerAuditOutcome.blockedNotBetaRepairMode =>
          blockedNotBetaRepairModeTitle,
        ProPlacementTriggerAuditOutcome.unknown => unknownTitle,
      };

  static String bodyFor(ProPlacementTriggerAuditOutcome outcome) =>
      switch (outcome) {
        ProPlacementTriggerAuditOutcome.inactive => inactiveBody,
        ProPlacementTriggerAuditOutcome.eligibleAndShown => eligibleAndShownBody,
        ProPlacementTriggerAuditOutcome.blockedNoUsefulProof =>
          blockedNoUsefulProofBody,
        ProPlacementTriggerAuditOutcome.blockedWeakProof => blockedWeakProofBody,
        ProPlacementTriggerAuditOutcome.blockedNegativeFeedback =>
          blockedNegativeFeedbackBody,
        ProPlacementTriggerAuditOutcome.blockedNoStrongAnchor =>
          blockedNoStrongAnchorBody,
        ProPlacementTriggerAuditOutcome.blockedAlreadyShown =>
          blockedAlreadyShownBody,
        ProPlacementTriggerAuditOutcome.blockedNotBetaRepairMode =>
          blockedNotBetaRepairModeBody,
        ProPlacementTriggerAuditOutcome.unknown => unknownBody,
      };

  static String blockReasonFor(ProPlacementTriggerAuditOutcome outcome) =>
      switch (outcome) {
        ProPlacementTriggerAuditOutcome.inactive => 'audit_inactive',
        ProPlacementTriggerAuditOutcome.eligibleAndShown => 'none',
        ProPlacementTriggerAuditOutcome.blockedNoUsefulProof =>
          'no_useful_proof',
        ProPlacementTriggerAuditOutcome.blockedWeakProof => 'weak_proof',
        ProPlacementTriggerAuditOutcome.blockedNegativeFeedback =>
          'negative_feedback',
        ProPlacementTriggerAuditOutcome.blockedNoStrongAnchor =>
          'weak_evidence_anchor',
        ProPlacementTriggerAuditOutcome.blockedAlreadyShown => 'already_shown',
        ProPlacementTriggerAuditOutcome.blockedNotBetaRepairMode =>
          'repair_mode_mismatch',
        ProPlacementTriggerAuditOutcome.unknown => 'unknown',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield activeRepairLabel;
    yield outcomeLabel;
    yield blockReasonLabel;
    yield warning;
    yield localNote;
    yield inactiveTitle;
    yield inactiveBody;
    yield eligibleAndShownTitle;
    yield eligibleAndShownBody;
    yield blockedNoUsefulProofTitle;
    yield blockedNoUsefulProofBody;
    yield blockedWeakProofTitle;
    yield blockedWeakProofBody;
    yield blockedNegativeFeedbackTitle;
    yield blockedNegativeFeedbackBody;
    yield blockedNoStrongAnchorTitle;
    yield blockedNoStrongAnchorBody;
    yield blockedAlreadyShownTitle;
    yield blockedAlreadyShownBody;
    yield blockedNotBetaRepairModeTitle;
    yield blockedNotBetaRepairModeBody;
    yield unknownTitle;
    yield unknownBody;
  }
}
