import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/payment_proof_not_interest/payment_proof_not_interest_gate.dart';
import 'package:voicememory_mobile/features/payment_proof_not_interest/payment_proof_not_interest_gate_copy.dart';

const _docsPath = 'docs/payment_proof_not_interest_gate.md';

PaymentProofNotInterestGateInput _input({
  bool testerSaysIdeaInteresting = false,
  bool testerSaysWouldPayMaybe = false,
  bool testerSeesFirstUsefulProof = false,
  bool testerSeesProPromise = false,
  bool testerTapsPro = false,
  bool testerStartsPurchase = false,
  bool testerCompletesSandboxPurchase = false,
  bool testerRestoresPurchase = false,
  bool testerAsksForPriceDetails = false,
  bool testerContinuesUsingAfterProof = false,
}) => PaymentProofNotInterestGateInput(
  testerSaysIdeaInteresting: testerSaysIdeaInteresting,
  testerSaysWouldPayMaybe: testerSaysWouldPayMaybe,
  testerSeesFirstUsefulProof: testerSeesFirstUsefulProof,
  testerSeesProPromise: testerSeesProPromise,
  testerTapsPro: testerTapsPro,
  testerStartsPurchase: testerStartsPurchase,
  testerCompletesSandboxPurchase: testerCompletesSandboxPurchase,
  testerRestoresPurchase: testerRestoresPurchase,
  testerAsksForPriceDetails: testerAsksForPriceDetails,
  testerContinuesUsingAfterProof: testerContinuesUsingAfterProof,
);

PaymentProofNotInterestGateSignal _signal(
  PaymentProofNotInterestGateResult result,
  PaymentProofNotInterestGateSignalId id,
) => result.signals.firstWhere((signal) => signal.id == id);

void main() {
  group('PaymentProofNotInterestGate.build', () {
    test('gate tracks ten canonical signals', () {
      final result = PaymentProofNotInterestGate.build(_input());
      expect(result.signals.length, PaymentProofNotInterestGate.signalCount);
      expect(result.signals.map((signal) => signal.id).toList(), [
        PaymentProofNotInterestGateSignalId.testerSaysIdeaInteresting,
        PaymentProofNotInterestGateSignalId.testerSaysWouldPayMaybe,
        PaymentProofNotInterestGateSignalId.testerSeesFirstUsefulProof,
        PaymentProofNotInterestGateSignalId.testerSeesProPromise,
        PaymentProofNotInterestGateSignalId.testerTapsPro,
        PaymentProofNotInterestGateSignalId.testerStartsPurchase,
        PaymentProofNotInterestGateSignalId.testerCompletesSandboxPurchase,
        PaymentProofNotInterestGateSignalId.testerRestoresPurchase,
        PaymentProofNotInterestGateSignalId.testerAsksForPriceDetails,
        PaymentProofNotInterestGateSignalId.testerContinuesUsingAfterProof,
      ]);
    });

    test('no signals -> notEnoughPaymentEvidence', () {
      final result = PaymentProofNotInterestGate.build(_input());
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.notEnoughPaymentEvidence,
      );
      expect(result.hasPaymentProof, isFalse);
    });

    test('idea interesting only -> interestOnly', () {
      final result = PaymentProofNotInterestGate.build(
        _input(testerSaysIdeaInteresting: true),
      );
      expect(result.decision, PaymentProofNotInterestGateDecision.interestOnly);
      expect(result.isInterestOnly, isTrue);
      expect(result.hasPaymentProof, isFalse);
    });

    test('would pay maybe only -> interestOnly not payment proof', () {
      final result = PaymentProofNotInterestGate.build(
        _input(testerSaysWouldPayMaybe: true),
      );
      expect(result.decision, PaymentProofNotInterestGateDecision.interestOnly);
      expect(result.hasPaymentProof, isFalse);
      expect(result.maybeCountedAsPaymentProof, isFalse);
      expect(
        _signal(
          result,
          PaymentProofNotInterestGateSignalId.testerSaysWouldPayMaybe,
        ).status,
        PaymentProofNotInterestGateSignalStatus.interestOnly,
      );
    });

    test('proof seen and continues using -> comprehensionOnly', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSeesFirstUsefulProof: true,
          testerContinuesUsingAfterProof: true,
        ),
      );
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.comprehensionOnly,
      );
      expect(result.hasPaymentProof, isFalse);
    });

    test('proof and pro promise without tap -> comprehensionOnly', () {
      final result = PaymentProofNotInterestGate.build(
        _input(testerSeesFirstUsefulProof: true, testerSeesProPromise: true),
      );
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.comprehensionOnly,
      );
    });

    test('pro tap without purchase start -> proCuriosity', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSeesFirstUsefulProof: true,
          testerSeesProPromise: true,
          testerTapsPro: true,
        ),
      );
      expect(result.decision, PaymentProofNotInterestGateDecision.proCuriosity);
      expect(result.hasPaymentProof, isFalse);
    });

    test('purchase start without completion -> purchaseIntent', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSeesFirstUsefulProof: true,
          testerSeesProPromise: true,
          testerTapsPro: true,
          testerStartsPurchase: true,
        ),
      );
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.purchaseIntent,
      );
      expect(result.hasPaymentProof, isFalse);
    });

    test('sandbox purchase complete -> purchaseProof', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSeesFirstUsefulProof: true,
          testerSeesProPromise: true,
          testerTapsPro: true,
          testerStartsPurchase: true,
          testerCompletesSandboxPurchase: true,
        ),
      );
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.purchaseProof,
      );
      expect(result.hasPaymentProof, isTrue);
    });

    test('sandbox restore -> restoreProof', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSeesFirstUsefulProof: true,
          testerSeesProPromise: true,
          testerTapsPro: true,
          testerRestoresPurchase: true,
        ),
      );
      expect(result.decision, PaymentProofNotInterestGateDecision.restoreProof);
      expect(result.hasPaymentProof, isTrue);
    });

    test('restore beats maybe and purchase intent', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSaysWouldPayMaybe: true,
          testerSeesFirstUsefulProof: true,
          testerSeesProPromise: true,
          testerTapsPro: true,
          testerStartsPurchase: true,
          testerRestoresPurchase: true,
        ),
      );
      expect(result.decision, PaymentProofNotInterestGateDecision.restoreProof);
    });

    test('maybe with purchase proof still counts purchase not maybe', () {
      final result = PaymentProofNotInterestGate.build(
        _input(
          testerSaysWouldPayMaybe: true,
          testerSeesFirstUsefulProof: true,
          testerSeesProPromise: true,
          testerTapsPro: true,
          testerStartsPurchase: true,
          testerCompletesSandboxPurchase: true,
        ),
      );
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.purchaseProof,
      );
      expect(result.maybeCountedAsPaymentProof, isFalse);
    });

    test('report exposes canonical copy', () {
      final report = PaymentProofNotInterestGate.report(
        PaymentProofNotInterestGate.build(
          _input(testerSaysIdeaInteresting: true),
        ),
      );
      expect(report.headline, PaymentProofNotInterestGateCopy.headline);
      expect(report.guardrail, PaymentProofNotInterestGateCopy.guardrail);
    });
  });

  group('PaymentProofNotInterestGate.fromPaidIntentBetaProof', () {
    test('maps maybe response to interest only', () {
      final result = PaymentProofNotInterestGate.build(
        PaymentProofNotInterestGate.fromPaidIntentBetaProof(
          const PaidIntentBetaProofInput(
            firstUsefulProofSeen: true,
            proofAcceptedOrCorrected: true,
            testerWouldPay: PaidIntentBetaWouldPay.maybe,
          ),
        ),
      );
      expect(result.decision, PaymentProofNotInterestGateDecision.interestOnly);
      expect(result.hasPaymentProof, isFalse);
    });

    test('maps purchase completed to purchaseProof', () {
      final result = PaymentProofNotInterestGate.build(
        PaymentProofNotInterestGate.fromPaidIntentBetaProof(
          const PaidIntentBetaProofInput(
            firstUsefulProofSeen: true,
            proPromiseSeen: true,
            proTapped: true,
            purchaseAttempted: true,
            purchaseCompleted: true,
          ),
        ),
      );
      expect(
        result.decision,
        PaymentProofNotInterestGateDecision.purchaseProof,
      );
    });
  });

  group('protected regression', () {
    test('docs describe classification-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('no pricing experiments'));
      expect(doc, contains('no new pro benefits'));
      expect(doc, contains('maybe'));
      expect(doc, contains('payment proof'));
    });

    test('guardrail forbids pricing experiments and new pro benefits', () {
      final lower = PaymentProofNotInterestGateCopy.guardrail.toLowerCase();
      expect(lower, contains('maybe'));
      expect(lower, contains('pricing experiments'));
      expect(lower, contains('pro benefits'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PaymentProofNotInterestGateCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });
  });
}
