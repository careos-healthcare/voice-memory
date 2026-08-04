import 'beta_repair_lab_model.dart';
import '../beta_proof_feedback/beta_proof_feedback_copy.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';

/// Beta repair lab copy — testing-only repair guidance and overrides.
abstract final class BetaRepairLabCopy {
  BetaRepairLabCopy._();

  static const cardTitle = 'Beta repair lab';
  static const cardBody =
      'Choose one repair to test. Only one can be active at a time.';
  static const warning =
      'Use one repair per tester round. Do not test multiple repairs at once.';
  static const guidanceOnlyNote =
      'Repairs only apply when beta mode is on and a mode is selected.';
  static const buildOverrideActivePrefix = 'Build override active:';
  static const defaultBaselineActivePrefix = 'Default beta baseline active:';
  static const defaultBaselineLabel = 'Proof protection';
  static const buildOverrideWarning =
      'This build is testing one repair mode. Do not compare it with mixed-mode testers.';
  static const activeModeLabel = 'Active repair';
  static const noneLabel = 'None';

  static const openingTitle = 'Write one sentence';
  static const openingBody =
      'Pick one moment from today. No setup. No journal.';
  static const openingPrimaryCta = 'Start typing';
  static const openingSecondaryCta = 'Use voice';
  static const openingMicrocopy =
      'ArchiveMe needs one real save before it can show what returns.';
  static const chipCheckedAgain = 'I checked again';
  static const chipAvoidedIt = 'I avoided it';
  static const chipWantedControl = 'I wanted control';
  static const chipFeltFamiliar = 'It felt familiar';

  static const proofWeakTitle = 'Still watching';
  static const proofWeakBody =
      'There is not enough clear evidence yet. Save one more moment if it returns.';
  static const proofStrongTitle = 'Here is the specific repeat';
  static const proofStrongBody =
      'ArchiveMe is showing this because the same kind of moment came back, '
      'not because one entry was important.';
  static const proofStrongWhyAppeared =
      'Why this appeared: this pattern appeared across saved moments.';
  static const proofFeedbackPrompt = 'Does this feel right?';
  static const proofFeedbackYes = 'Yes';
  static const proofFeedbackTooVague = 'Too vague';
  static const proofFeedbackNotRelevant = 'Not relevant';
  static const proofFeedbackTooVagueResponse =
      'Got it. ArchiveMe will wait for clearer evidence before showing this again.';
  static const proofFeedbackNotRelevantResponse =
      'Got it. ArchiveMe will not treat this as a useful pattern.';

  static const proPlacementTitle = 'Keep the longer trail';
  static const proPlacementBody =
      'Free shows the first useful proof. Pro keeps tracking whether this pattern '
      'returns, changes, fades, or needs correcting.';
  static const proPlacementPrimaryCta = 'See Pro timeline';
  static const proPlacementSecondaryCta = 'Not now';

  static const proExplanationTitle = 'Free vs Pro';
  static const proExplanationBody =
      'Free shows the first useful proof. Pro keeps the longer proof trail: '
      'what returns, what changes, what fades, and what you correct.';
  static const proExplanationBulletFree = 'Free: first proof';
  static const proExplanationBulletPro = 'Pro: longer evidence trail';
  static const proExplanationBulletControl =
      'Control: delete or correct anything';
  static const proExplanationSupport =
      'Not more chat. The record behind the pattern.';
  static const proExplanationPrimaryCta = 'See what Pro keeps';

  static String modeLabel(BetaRepairLabMode mode) => switch (mode) {
    BetaRepairLabMode.none => noneLabel,
    BetaRepairLabMode.openingScreenSimplification =>
      'Opening screen simplification',
    BetaRepairLabMode.proofSpecificityCaution =>
      'Proof specificity and caution',
    BetaRepairLabMode.proPlacementAfterUsefulProof =>
      'Pro placement after useful proof',
    BetaRepairLabMode.proExplanation => 'Pro explanation',
    BetaRepairLabMode.paywallValue => 'Paywall value repair',
    BetaRepairLabMode.pricingValueFraming => 'Pricing value framing',
    BetaRepairLabMode.pricingValidation => 'Pricing validation',
    BetaRepairLabMode.evidenceTrailTimelineClarity =>
      'Evidence trail timeline clarity',
  };

  static String modeFixes(BetaRepairLabMode mode) => switch (mode) {
    BetaRepairLabMode.none => 'No active repair.',
    BetaRepairLabMode.openingScreenSimplification =>
      'First-moment save and opening-screen clarity.',
    BetaRepairLabMode.proofSpecificityCaution =>
      'Useful proof quality and cautious weak-proof handling.',
    BetaRepairLabMode.proPlacementAfterUsefulProof =>
      'Saw Pro after useful proof without stacking cards.',
    BetaRepairLabMode.proExplanation =>
      'Understands Pro after Pro is already visible.',
    BetaRepairLabMode.paywallValue =>
      'Paywall CTA tap after users understand Pro.',
    BetaRepairLabMode.pricingValueFraming =>
      'Would Pay after Paywall CTA tap is weak.',
    BetaRepairLabMode.pricingValidation =>
      'Monthly price intent after Pro value moment.',
    BetaRepairLabMode.evidenceTrailTimelineClarity =>
      'Timeline clarity after useful proof before price changes.',
  };

  static String modeWhenToUse(BetaRepairLabMode mode) => switch (mode) {
    BetaRepairLabMode.none => 'Default state before choosing a repair.',
    BetaRepairLabMode.openingScreenSimplification =>
      'When first-moment saves are below target.',
    BetaRepairLabMode.proofSpecificityCaution =>
      'When useful proof is weak or feedback is negative.',
    BetaRepairLabMode.proPlacementAfterUsefulProof =>
      'When proof and first-moment capture pass but Saw Pro is low.',
    BetaRepairLabMode.proExplanation =>
      'When Saw Pro passes but Understands Pro is low.',
    BetaRepairLabMode.paywallValue =>
      'When Understands Pro passes but Paywall CTA tap is 0.',
    BetaRepairLabMode.pricingValueFraming =>
      'When Paywall CTA tap improves but Would Pay stays weak.',
    BetaRepairLabMode.pricingValidation =>
      'When Paywall CTA / Would Pay stay weak after polish.',
    BetaRepairLabMode.evidenceTrailTimelineClarity =>
      'When pricing feedback says clarify timeline or evidence trail.',
  };

  static String modeChanges(BetaRepairLabMode mode) => switch (mode) {
    BetaRepairLabMode.none => 'Production/default behavior.',
    BetaRepairLabMode.openingScreenSimplification =>
      '0-entry capture copy only.',
    BetaRepairLabMode.proofSpecificityCaution =>
      'Weak/strong proof copy and feedback prompt only.',
    BetaRepairLabMode.proPlacementAfterUsefulProof =>
      'One Pro card after useful proof only.',
    BetaRepairLabMode.proExplanation => 'Pro explanation copy only.',
    BetaRepairLabMode.paywallValue =>
      'One pre-paywall value card after useful proof only.',
    BetaRepairLabMode.pricingValueFraming =>
      'One pricing value framing card after useful proof only.',
    BetaRepairLabMode.pricingValidation =>
      'One pricing validation card after useful proof only.',
    BetaRepairLabMode.evidenceTrailTimelineClarity =>
      'One evidence trail clarity card after useful proof only.',
  };

  static String modeDoNotTouch(BetaRepairLabMode mode) => switch (mode) {
    BetaRepairLabMode.none => 'Everything.',
    BetaRepairLabMode.openingScreenSimplification =>
      'Proof, Pro, paywall, pricing.',
    BetaRepairLabMode.proofSpecificityCaution =>
      'Proof thresholds, Pro after weak proof, pricing.',
    BetaRepairLabMode.proPlacementAfterUsefulProof =>
      'Paywall copy, billing, placement before proof.',
    BetaRepairLabMode.proExplanation =>
      'Placement, purchase mechanics, pricing.',
    BetaRepairLabMode.paywallValue =>
      'Paywall screen, billing, pricing, proof thresholds.',
    BetaRepairLabMode.pricingValueFraming =>
      'Paywall screen, billing, pricing, purchase mechanics.',
    BetaRepairLabMode.pricingValidation =>
      'Paywall screen, billing, products, purchase mechanics.',
    BetaRepairLabMode.evidenceTrailTimelineClarity =>
      'Paywall screen, billing, pricing, purchase mechanics.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield cardBody;
    yield warning;
    yield guidanceOnlyNote;
    yield buildOverrideActivePrefix;
    yield defaultBaselineActivePrefix;
    yield defaultBaselineLabel;
    yield buildOverrideWarning;
    yield activeModeLabel;
    yield noneLabel;
    yield openingTitle;
    yield openingBody;
    yield openingPrimaryCta;
    yield openingSecondaryCta;
    yield openingMicrocopy;
    yield chipCheckedAgain;
    yield chipAvoidedIt;
    yield chipWantedControl;
    yield chipFeltFamiliar;
    yield proofWeakTitle;
    yield proofWeakBody;
    yield proofStrongTitle;
    yield proofStrongBody;
    yield proofStrongWhyAppeared;
    yield proofFeedbackPrompt;
    yield proofFeedbackYes;
    yield proofFeedbackTooVague;
    yield proofFeedbackNotRelevant;
    yield proofFeedbackTooVagueResponse;
    yield proofFeedbackNotRelevantResponse;
    yield proPlacementTitle;
    yield proPlacementBody;
    yield proPlacementPrimaryCta;
    yield proPlacementSecondaryCta;
    yield proExplanationTitle;
    yield proExplanationBody;
    yield proExplanationBulletFree;
    yield proExplanationBulletPro;
    yield proExplanationBulletControl;
    yield proExplanationSupport;
    yield proExplanationPrimaryCta;
    for (final mode in BetaRepairLabMode.values) {
      yield modeLabel(mode);
      yield modeFixes(mode);
      yield modeWhenToUse(mode);
      yield modeChanges(mode);
      yield modeDoNotTouch(mode);
    }
  }
}

extension BetaRepairLabProofFeedbackCopy on BetaRepairLabCopy {
  static const feedbackTypes = [
    BetaProofFeedbackType.useful,
    BetaProofFeedbackType.tooVague,
    BetaProofFeedbackType.notRelevant,
  ];

  static String feedbackLabel(BetaProofFeedbackType type) => switch (type) {
    BetaProofFeedbackType.useful => BetaRepairLabCopy.proofFeedbackYes,
    BetaProofFeedbackType.tooVague => BetaRepairLabCopy.proofFeedbackTooVague,
    BetaProofFeedbackType.notRelevant =>
      BetaRepairLabCopy.proofFeedbackNotRelevant,
    BetaProofFeedbackType.alreadyKnew =>
      BetaProofFeedbackCopy.answerAlreadyKnew,
  };

  static String? feedbackResponse(BetaProofFeedbackType type) => switch (type) {
    BetaProofFeedbackType.tooVague =>
      BetaRepairLabCopy.proofFeedbackTooVagueResponse,
    BetaProofFeedbackType.notRelevant =>
      BetaRepairLabCopy.proofFeedbackNotRelevantResponse,
    _ => null,
  };
}

enum BetaRepairLabChipId {
  checkedAgain,
  avoidedIt,
  wantedControl,
  feltFamiliar,
}

extension BetaRepairLabModeAnalytics on BetaRepairLabMode {
  String get analyticsValue => switch (this) {
    BetaRepairLabMode.none => 'none',
    BetaRepairLabMode.openingScreenSimplification =>
      'opening_screen_simplification',
    BetaRepairLabMode.proofSpecificityCaution => 'proof_specificity_caution',
    BetaRepairLabMode.proPlacementAfterUsefulProof =>
      'pro_placement_after_useful_proof',
    BetaRepairLabMode.proExplanation => 'pro_explanation',
    BetaRepairLabMode.paywallValue => 'paywall_value',
    BetaRepairLabMode.pricingValueFraming => 'pricing_value_framing',
    BetaRepairLabMode.pricingValidation => 'pricing_validation',
    BetaRepairLabMode.evidenceTrailTimelineClarity =>
      'evidence_trail_timeline_clarity',
  };
}
