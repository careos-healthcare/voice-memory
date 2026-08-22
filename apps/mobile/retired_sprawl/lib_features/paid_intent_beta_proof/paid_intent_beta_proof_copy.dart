/// Paid intent beta proof copy — measure real paid intent after first useful proof.
abstract final class PaidIntentBetaProofCopy {
  PaidIntentBetaProofCopy._();

  static const headline = 'Paid intent beta proof';

  static const body =
      'Measure real paid intent after first useful proof using the existing paywall '
      'and Pro path. Do not add features, pricing experiments, or new Pro benefits.';

  static const trackedLine =
      'Track only: first save, first useful proof, proof accepted or corrected, '
      'Pro promise seen, Pro tapped, purchase attempted, purchase completed, '
      'restore attempted, and tester would-pay yes/maybe/no.';

  static const signalFirstSaveCompleted = 'First save completed';
  static const signalFirstUsefulProofSeen = 'First useful proof seen';
  static const signalProofAcceptedOrCorrected = 'Proof accepted or corrected';
  static const signalProPromiseSeen = 'Pro promise seen';
  static const signalProTapped = 'Pro tapped';
  static const signalPurchaseAttempted = 'Purchase attempted';
  static const signalPurchaseCompleted = 'Purchase completed';
  static const signalRestoreAttempted = 'Restore attempted';
  static const signalTesterWouldPay = 'Tester would-pay response';

  static const detailPass = 'Observed';
  static const detailFail = 'Missing';
  static const detailPending = 'Not yet observed';
  static const detailBlocked = 'Blocked by earlier step';
  static const detailNotRequired = 'Tracked only';

  static const insufficientDataLine =
      'Insufficient data. Wait for first save and the first useful proof funnel.';

  static const proofNotReachedLine =
      'Proof not reached. Tester saved but has not seen first useful proof yet.';

  static const proofNotUsefulLine =
      'Proof not useful. Tester saw proof but did not accept or correct it.';

  static const proNotSeenLine =
      'Pro not seen. Proof landed but the existing Pro promise was not shown.';

  static const proNotTappedLine =
      'Pro not tapped. Pro promise was shown but tester did not open paywall.';

  static const purchaseBlockedLine =
      'Purchase blocked. Tester tapped Pro but purchase mechanics failed.';

  static const paidIntentWeakLine =
      'Paid intent weak. Tester reached Pro path but would not pay or backed out.';

  static const paidIntentPromisingLine =
      'Paid intent promising. Tester would pay, maybe pay, or completed purchase.';

  static const guardrail =
      'Paid intent beta proof measures funnel completion only. Do not add product '
      'surfaces, pricing experiments, or new Pro benefits.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield trackedLine;
    yield signalFirstSaveCompleted;
    yield signalFirstUsefulProofSeen;
    yield signalProofAcceptedOrCorrected;
    yield signalProPromiseSeen;
    yield signalProTapped;
    yield signalPurchaseAttempted;
    yield signalPurchaseCompleted;
    yield signalRestoreAttempted;
    yield signalTesterWouldPay;
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield detailBlocked;
    yield detailNotRequired;
    yield insufficientDataLine;
    yield proofNotReachedLine;
    yield proofNotUsefulLine;
    yield proNotSeenLine;
    yield proNotTappedLine;
    yield purchaseBlockedLine;
    yield paidIntentWeakLine;
    yield paidIntentPromisingLine;
  }
}