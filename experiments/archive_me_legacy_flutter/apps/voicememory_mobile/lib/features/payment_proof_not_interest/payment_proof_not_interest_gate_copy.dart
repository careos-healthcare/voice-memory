/// Payment proof not interest gate copy — separate idea interest from payment proof.
abstract final class PaymentProofNotInterestGateCopy {
  PaymentProofNotInterestGateCopy._();

  static const headline = 'Payment proof not interest gate';

  static const body =
      'Separate whether testers like the idea from whether they reach payment proof. '
      'Classification only — no pricing experiments and no new Pro benefits.';

  static const orderLine =
      'Signals: idea interesting, would pay maybe, first useful proof, Pro promise, '
      'Pro tap, purchase start, sandbox purchase, restore, price/details ask, '
      'continues using after proof.';

  static const signalTesterSaysIdeaInteresting = 'Tester says idea interesting';
  static const signalTesterSaysWouldPayMaybe = 'Tester says would pay maybe';
  static const signalTesterSeesFirstUsefulProof =
      'Tester sees first useful proof';
  static const signalTesterSeesProPromise = 'Tester sees Pro promise';
  static const signalTesterTapsPro = 'Tester taps Pro';
  static const signalTesterStartsPurchase = 'Tester starts purchase';
  static const signalTesterCompletesSandboxPurchase =
      'Tester completes sandbox purchase';
  static const signalTesterRestoresPurchase = 'Tester restores purchase';
  static const signalTesterAsksForPriceDetails =
      'Tester asks for price or details';
  static const signalTesterContinuesUsingAfterProof =
      'Tester continues using after proof';

  static const detailObserved = 'Observed';
  static const detailMissing = 'Not observed';
  static const detailInterestOnly = 'Interest only — not payment proof';
  static const detailBlocked = 'Blocked by earlier signal';

  static const interestOnlyLine =
      'Interest only. Tester likes the idea or says maybe, but payment evidence '
      'is not strong enough yet.';

  static const comprehensionOnlyLine =
      'Comprehension only. Tester understood the proof without trying to pay.';

  static const proCuriosityLine =
      'Pro curiosity. Tester tapped Pro but has not started purchase yet.';

  static const purchaseIntentLine =
      'Purchase intent. Tester started purchase but has not completed sandbox proof.';

  static const purchaseProofLine =
      'Purchase proof. Tester completed a sandbox purchase.';

  static const restoreProofLine =
      'Restore proof. Tester restored a purchase in sandbox.';

  static const notEnoughPaymentEvidenceLine =
      'Not enough payment evidence. Wait for stronger purchase or restore signals.';

  static const guardrail =
      'Payment proof not interest gate classifies tester behavior only. Do not count '
      'maybe as payment proof, do not run pricing experiments, and do not add Pro benefits.';

  static String labelFor(PaymentProofNotInterestGateSignalId id) =>
      switch (id) {
        PaymentProofNotInterestGateSignalId.testerSaysIdeaInteresting =>
          signalTesterSaysIdeaInteresting,
        PaymentProofNotInterestGateSignalId.testerSaysWouldPayMaybe =>
          signalTesterSaysWouldPayMaybe,
        PaymentProofNotInterestGateSignalId.testerSeesFirstUsefulProof =>
          signalTesterSeesFirstUsefulProof,
        PaymentProofNotInterestGateSignalId.testerSeesProPromise =>
          signalTesterSeesProPromise,
        PaymentProofNotInterestGateSignalId.testerTapsPro =>
          signalTesterTapsPro,
        PaymentProofNotInterestGateSignalId.testerStartsPurchase =>
          signalTesterStartsPurchase,
        PaymentProofNotInterestGateSignalId.testerCompletesSandboxPurchase =>
          signalTesterCompletesSandboxPurchase,
        PaymentProofNotInterestGateSignalId.testerRestoresPurchase =>
          signalTesterRestoresPurchase,
        PaymentProofNotInterestGateSignalId.testerAsksForPriceDetails =>
          signalTesterAsksForPriceDetails,
        PaymentProofNotInterestGateSignalId.testerContinuesUsingAfterProof =>
          signalTesterContinuesUsingAfterProof,
      };

  static String messageFor(PaymentProofNotInterestGateDecision decision) =>
      switch (decision) {
        PaymentProofNotInterestGateDecision.interestOnly => interestOnlyLine,
        PaymentProofNotInterestGateDecision.comprehensionOnly =>
          comprehensionOnlyLine,
        PaymentProofNotInterestGateDecision.proCuriosity => proCuriosityLine,
        PaymentProofNotInterestGateDecision.purchaseIntent =>
          purchaseIntentLine,
        PaymentProofNotInterestGateDecision.purchaseProof => purchaseProofLine,
        PaymentProofNotInterestGateDecision.restoreProof => restoreProofLine,
        PaymentProofNotInterestGateDecision.notEnoughPaymentEvidence =>
          notEnoughPaymentEvidenceLine,
      };

  static String recommendationFor(
    PaymentProofNotInterestGateDecision decision,
  ) => switch (decision) {
    PaymentProofNotInterestGateDecision.interestOnly =>
      'Keep measuring. Maybe and idea-interest are not payment proof.',
    PaymentProofNotInterestGateDecision.comprehensionOnly =>
      'Proof landed. Watch for Pro tap or purchase start before calling paid intent.',
    PaymentProofNotInterestGateDecision.proCuriosity =>
      'Pro curiosity is not payment proof. Watch for purchase start or completion.',
    PaymentProofNotInterestGateDecision.purchaseIntent =>
      'Purchase intent is promising. Finish sandbox purchase or restore proof.',
    PaymentProofNotInterestGateDecision.purchaseProof =>
      'Sandbox purchase counts as payment proof.',
    PaymentProofNotInterestGateDecision.restoreProof =>
      'Sandbox restore counts as payment proof.',
    PaymentProofNotInterestGateDecision.notEnoughPaymentEvidence =>
      'Collect more tester signals before classifying payment proof.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield signalTesterSaysIdeaInteresting;
    yield signalTesterSaysWouldPayMaybe;
    yield signalTesterSeesFirstUsefulProof;
    yield signalTesterSeesProPromise;
    yield signalTesterTapsPro;
    yield signalTesterStartsPurchase;
    yield signalTesterCompletesSandboxPurchase;
    yield signalTesterRestoresPurchase;
    yield signalTesterAsksForPriceDetails;
    yield signalTesterContinuesUsingAfterProof;
    yield detailObserved;
    yield detailMissing;
    yield detailInterestOnly;
    yield detailBlocked;
    yield interestOnlyLine;
    yield comprehensionOnlyLine;
    yield proCuriosityLine;
    yield purchaseIntentLine;
    yield purchaseProofLine;
    yield restoreProofLine;
    yield notEnoughPaymentEvidenceLine;
    yield guardrail;
    for (final decision in PaymentProofNotInterestGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum PaymentProofNotInterestGateSignalId {
  testerSaysIdeaInteresting,
  testerSaysWouldPayMaybe,
  testerSeesFirstUsefulProof,
  testerSeesProPromise,
  testerTapsPro,
  testerStartsPurchase,
  testerCompletesSandboxPurchase,
  testerRestoresPurchase,
  testerAsksForPriceDetails,
  testerContinuesUsingAfterProof,
}

enum PaymentProofNotInterestGateSignalStatus {
  pass,
  fail,
  blocked,
  interestOnly,
}

enum PaymentProofNotInterestGateDecision {
  interestOnly,
  comprehensionOnly,
  proCuriosity,
  purchaseIntent,
  purchaseProof,
  restoreProof,
  notEnoughPaymentEvidence,
}
