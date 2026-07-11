/// Payment proof beta copy — concrete beta payment evidence separate from interest.
abstract final class PaymentProofBetaCopy {
  PaymentProofBetaCopy._();

  static const headline = 'Payment proof, not interest';

  static const body =
      'A tester liking ArchiveMe is not payment proof. Payment proof starts when '
      'the user sees value, taps Pro, starts purchase, completes sandbox purchase, '
      'or restores.';

  static const trackedLine =
      'Track: first save, second save, first useful proof, proof accepted, proof '
      'corrected, Pro promise, Pro tap, purchase start, purchase complete, restore '
      'start, restore complete, entitlement active, and would-pay yes/maybe/no.';

  static const guardrail = 'Do not count interest as revenue evidence.';

  static const signalFirstSave = 'First save';
  static const signalSecondSave = 'Second save';
  static const signalFirstUsefulProofSeen = 'First useful proof seen';
  static const signalProofAccepted = 'Proof accepted';
  static const signalProofCorrected = 'Proof corrected';
  static const signalProPromiseSeen = 'Pro promise seen';
  static const signalProTapped = 'Pro tapped';
  static const signalPurchaseStarted = 'Purchase started';
  static const signalPurchaseCompleted = 'Purchase completed';
  static const signalRestoreStarted = 'Restore started';
  static const signalRestoreCompleted = 'Restore completed';
  static const signalEntitlementActive = 'Entitlement active';
  static const signalTesterWouldPayYes = 'Tester would pay yes';
  static const signalTesterWouldPayMaybe = 'Tester would pay maybe';
  static const signalTesterWouldPayNo = 'Tester would pay no';

  static const detailObserved = 'Observed';
  static const detailMissing = 'Not observed';
  static const detailInterestOnly = 'Interest only — not payment proof';
  static const detailBlocked = 'Blocked by earlier signal';
  static const detailTracked = 'Tracked only';

  static const interestOnlyLine =
      'Interest only. Maybe or liking the idea is not payment proof.';

  static const proofNotReachedLine =
      'Proof not reached. Paid interpretation stays blocked until first useful proof.';

  static const proofReachedNoProTapLine =
      'Proof reached without Pro tap. Value landed but paywall path not opened.';

  static const proCuriosityLine =
      'Pro curiosity. Tester tapped Pro but has not started purchase yet.';

  static const purchaseIntentLine =
      'Purchase intent. Tester started purchase but sandbox proof is incomplete.';

  static const purchaseProofLine =
      'Purchase proof. Tester completed a sandbox purchase.';

  static const restoreProofLine =
      'Restore proof. Tester completed restore and strengthened payment evidence.';

  static const paidIntentPromisingLine =
      'Paid intent promising. Tester would pay yes after reaching proof value.';

  static const paidIntentWeakLine =
      'Paid intent weak. Tester reached proof but would not pay.';

  static const canonicalTrackedSignals = [
    signalFirstSave,
    signalSecondSave,
    signalFirstUsefulProofSeen,
    signalProofAccepted,
    signalProofCorrected,
    signalProPromiseSeen,
    signalProTapped,
    signalPurchaseStarted,
    signalPurchaseCompleted,
    signalRestoreStarted,
    signalRestoreCompleted,
    signalEntitlementActive,
    signalTesterWouldPayYes,
    signalTesterWouldPayMaybe,
    signalTesterWouldPayNo,
  ];

  static String labelFor(PaymentProofBetaSignalId id) => switch (id) {
        PaymentProofBetaSignalId.firstSave => signalFirstSave,
        PaymentProofBetaSignalId.secondSave => signalSecondSave,
        PaymentProofBetaSignalId.firstUsefulProofSeen =>
          signalFirstUsefulProofSeen,
        PaymentProofBetaSignalId.proofAccepted => signalProofAccepted,
        PaymentProofBetaSignalId.proofCorrected => signalProofCorrected,
        PaymentProofBetaSignalId.proPromiseSeen => signalProPromiseSeen,
        PaymentProofBetaSignalId.proTapped => signalProTapped,
        PaymentProofBetaSignalId.purchaseStarted => signalPurchaseStarted,
        PaymentProofBetaSignalId.purchaseCompleted => signalPurchaseCompleted,
        PaymentProofBetaSignalId.restoreStarted => signalRestoreStarted,
        PaymentProofBetaSignalId.restoreCompleted => signalRestoreCompleted,
        PaymentProofBetaSignalId.entitlementActive => signalEntitlementActive,
        PaymentProofBetaSignalId.testerWouldPayYes => signalTesterWouldPayYes,
        PaymentProofBetaSignalId.testerWouldPayMaybe => signalTesterWouldPayMaybe,
        PaymentProofBetaSignalId.testerWouldPayNo => signalTesterWouldPayNo,
      };

  static String messageFor(PaymentProofBetaDecision decision) => switch (decision) {
        PaymentProofBetaDecision.interestOnly => interestOnlyLine,
        PaymentProofBetaDecision.proofNotReached => proofNotReachedLine,
        PaymentProofBetaDecision.proofReachedNoProTap =>
          proofReachedNoProTapLine,
        PaymentProofBetaDecision.proCuriosity => proCuriosityLine,
        PaymentProofBetaDecision.purchaseIntent => purchaseIntentLine,
        PaymentProofBetaDecision.purchaseProof => purchaseProofLine,
        PaymentProofBetaDecision.restoreProof => restoreProofLine,
        PaymentProofBetaDecision.paidIntentPromising => paidIntentPromisingLine,
        PaymentProofBetaDecision.paidIntentWeak => paidIntentWeakLine,
      };

  static String recommendationFor(PaymentProofBetaDecision decision) =>
      switch (decision) {
        PaymentProofBetaDecision.interestOnly =>
          'Keep measuring. Maybe is not payment proof.',
        PaymentProofBetaDecision.proofNotReached =>
          'Wait for first useful proof before interpreting paid intent.',
        PaymentProofBetaDecision.proofReachedNoProTap =>
          'Proof landed. Watch for Pro tap or purchase start.',
        PaymentProofBetaDecision.proCuriosity =>
          'Pro tap is curiosity, not payment proof.',
        PaymentProofBetaDecision.purchaseIntent =>
          'Purchase start is intent. Finish sandbox purchase or restore.',
        PaymentProofBetaDecision.purchaseProof =>
          'Sandbox purchase counts as payment proof.',
        PaymentProofBetaDecision.restoreProof =>
          'Restore success strengthens payment proof.',
        PaymentProofBetaDecision.paidIntentPromising =>
          'Would-pay yes is promising but not sandbox proof.',
        PaymentProofBetaDecision.paidIntentWeak =>
          'Would-pay no is weak paid intent after proof.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield trackedLine;
    yield guardrail;
    for (final label in canonicalTrackedSignals) {
      yield label;
    }
    yield detailObserved;
    yield detailMissing;
    yield detailInterestOnly;
    yield detailBlocked;
    yield detailTracked;
    yield interestOnlyLine;
    yield proofNotReachedLine;
    yield proofReachedNoProTapLine;
    yield proCuriosityLine;
    yield purchaseIntentLine;
    yield purchaseProofLine;
    yield restoreProofLine;
    yield paidIntentPromisingLine;
    yield paidIntentWeakLine;
    for (final decision in PaymentProofBetaDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum PaymentProofBetaSignalId {
  firstSave,
  secondSave,
  firstUsefulProofSeen,
  proofAccepted,
  proofCorrected,
  proPromiseSeen,
  proTapped,
  purchaseStarted,
  purchaseCompleted,
  restoreStarted,
  restoreCompleted,
  entitlementActive,
  testerWouldPayYes,
  testerWouldPayMaybe,
  testerWouldPayNo,
}

enum PaymentProofBetaSignalStatus {
  pass,
  fail,
  blocked,
  interestOnly,
  tracked,
}

enum PaymentProofBetaDecision {
  interestOnly,
  proofNotReached,
  proofReachedNoProTap,
  proCuriosity,
  purchaseIntent,
  purchaseProof,
  restoreProof,
  paidIntentPromising,
  paidIntentWeak,
}
