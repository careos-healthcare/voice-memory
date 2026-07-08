import 'beta_repair_lab_model.dart';

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
  static const proofFeedbackPrompt = 'Did this feel like a real connection?';

  static const proPlacementTitle = 'Keep tracking this';
  static const proPlacementBody =
      'Free showed this first proof. Pro keeps watching what happens next.';
  static const proPlacementPrimaryCta = 'See Pro timeline';
  static const proPlacementSecondaryCta = 'Not now';

  static const proExplanationTitle = 'Free vs Pro';
  static const proExplanationBody =
      'Free shows the first useful proof. Pro keeps the longer timeline: '
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
      };

  static String modeFixes(BetaRepairLabMode mode) => switch (mode) {
        BetaRepairLabMode.none => 'No active repair.',
        BetaRepairLabMode.openingScreenSimplification =>
          'First-session save and opening-screen clarity.',
        BetaRepairLabMode.proofSpecificityCaution =>
          'Useful proof quality and cautious weak-proof handling.',
        BetaRepairLabMode.proPlacementAfterUsefulProof =>
          'Saw Pro after useful proof without stacking cards.',
        BetaRepairLabMode.proExplanation =>
          'Understands Pro after Pro is already visible.',
      };

  static String modeWhenToUse(BetaRepairLabMode mode) => switch (mode) {
        BetaRepairLabMode.none => 'Default state before choosing a repair.',
        BetaRepairLabMode.openingScreenSimplification =>
          'When first-session saves are below target.',
        BetaRepairLabMode.proofSpecificityCaution =>
          'When useful proof is weak or feedback is negative.',
        BetaRepairLabMode.proPlacementAfterUsefulProof =>
          'When proof and first-session pass but Saw Pro is low.',
        BetaRepairLabMode.proExplanation =>
          'When Saw Pro passes but Understands Pro is low.',
      };

  static String modeChanges(BetaRepairLabMode mode) => switch (mode) {
        BetaRepairLabMode.none => 'Production/default behavior.',
        BetaRepairLabMode.openingScreenSimplification =>
          '0-entry capture copy only.',
        BetaRepairLabMode.proofSpecificityCaution =>
          'Weak/strong proof copy and feedback prompt only.',
        BetaRepairLabMode.proPlacementAfterUsefulProof =>
          'One Pro card after useful proof only.',
        BetaRepairLabMode.proExplanation =>
          'Pro explanation copy only.',
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
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield cardTitle;
    yield cardBody;
    yield warning;
    yield guidanceOnlyNote;
    yield buildOverrideActivePrefix;
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
    yield proofFeedbackPrompt;
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
      };
}
