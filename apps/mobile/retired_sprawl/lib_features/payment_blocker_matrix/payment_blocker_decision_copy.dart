/// Payment blocker decision labels — interpretation only, no product changes.
abstract final class PaymentBlockerDecisionCopy {
  PaymentBlockerDecisionCopy._();

  static const validateLongerTrailValue =
      'Validate whether seeing the same repeat over time is enough value to pay for.';

  static const sharpenProofValueProposition =
      'Sharpen why the first proof matters. Do not add more proof yet.';

  static const investigatePrioritisationConceptOnly =
      'Investigate whether prioritisation would help payment intent. Do not build ranked lists.';

  static const guardrail =
      'Ranking is only a concept investigation if payment is blocked by prioritisation. '
      'It is not a product build yet.';

  static const insufficientDataLabel =
      'Collect more tester feedback before choosing the next payment action.';

  static const repairProofFirstLabel =
      'Repair useful proof before testing payment blockers.';

  static const repairProUnderstandingLabel =
      'Repair Pro understanding before testing payment blockers.';

  static const validatePriceCopyLabel =
      'Validate pricing copy before changing product value.';

  static const productionCandidateLabel =
      'Payment blockers are clear enough to move toward production validation.';

  static Iterable<String> allVisibleStrings() sync* {
    yield validateLongerTrailValue;
    yield sharpenProofValueProposition;
    yield investigatePrioritisationConceptOnly;
    yield guardrail;
    yield insufficientDataLabel;
    yield repairProofFirstLabel;
    yield repairProUnderstandingLabel;
    yield validatePriceCopyLabel;
    yield productionCandidateLabel;
  }
}