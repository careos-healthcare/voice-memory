import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/payment_proof_beta/payment_proof_beta_copy.dart';
import 'package:voicememory_mobile/features/payment_proof_beta/payment_proof_beta_instrument.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';

const _docsPath = 'docs/PAYMENT_PROOF_BETA_INSTRUMENT.md';

PaymentProofBetaInput _input({
  bool firstSave = false,
  bool secondSave = false,
  bool firstUsefulProofSeen = false,
  bool proofAccepted = false,
  bool proofCorrected = false,
  bool proPromiseSeen = false,
  bool proTapped = false,
  bool purchaseStarted = false,
  bool purchaseCompleted = false,
  bool restoreStarted = false,
  bool restoreCompleted = false,
  bool entitlementActive = false,
  bool testerWouldPayYes = false,
  bool testerWouldPayMaybe = false,
  bool testerWouldPayNo = false,
}) => PaymentProofBetaInput(
  firstSave: firstSave,
  secondSave: secondSave,
  firstUsefulProofSeen: firstUsefulProofSeen,
  proofAccepted: proofAccepted,
  proofCorrected: proofCorrected,
  proPromiseSeen: proPromiseSeen,
  proTapped: proTapped,
  purchaseStarted: purchaseStarted,
  purchaseCompleted: purchaseCompleted,
  restoreStarted: restoreStarted,
  restoreCompleted: restoreCompleted,
  entitlementActive: entitlementActive,
  testerWouldPayYes: testerWouldPayYes,
  testerWouldPayMaybe: testerWouldPayMaybe,
  testerWouldPayNo: testerWouldPayNo,
);

PaymentProofBetaInput _proofPath({
  bool proTapped = false,
  bool purchaseStarted = false,
  bool purchaseCompleted = false,
  bool restoreStarted = false,
  bool restoreCompleted = false,
  bool entitlementActive = false,
  bool testerWouldPayYes = false,
  bool testerWouldPayMaybe = false,
  bool testerWouldPayNo = false,
}) => _input(
  firstSave: true,
  secondSave: true,
  firstUsefulProofSeen: true,
  proofAccepted: true,
  proPromiseSeen: true,
  proTapped: proTapped,
  purchaseStarted: purchaseStarted,
  purchaseCompleted: purchaseCompleted,
  restoreStarted: restoreStarted,
  restoreCompleted: restoreCompleted,
  entitlementActive: entitlementActive,
  testerWouldPayYes: testerWouldPayYes,
  testerWouldPayMaybe: testerWouldPayMaybe,
  testerWouldPayNo: testerWouldPayNo,
);

PaymentProofBetaSignal _signal(
  PaymentProofBetaResult result,
  PaymentProofBetaSignalId id,
) => result.signals.firstWhere((signal) => signal.id == id);

void main() {
  group('PaymentProofBetaInstrument.build', () {
    test('instrument tracks fifteen canonical signals', () {
      final result = PaymentProofBetaInstrument.build(_input());
      expect(result.signals.length, PaymentProofBetaInstrument.signalCount);
      expect(PaymentProofBetaCopy.canonicalTrackedSignals, hasLength(15));
    });

    test('maybe alone returns interestOnly', () {
      final result = PaymentProofBetaInstrument.build(
        _input(testerWouldPayMaybe: true),
      );
      expect(result.decision, PaymentProofBetaDecision.interestOnly);
      expect(result.hasPaymentProof, isFalse);
      expect(result.maybeCountedAsPaymentProof, isFalse);
      expect(
        _signal(result, PaymentProofBetaSignalId.testerWouldPayMaybe).status,
        PaymentProofBetaSignalStatus.interestOnly,
      );
    });

    test('Pro tap returns proCuriosity', () {
      final result = PaymentProofBetaInstrument.build(
        _proofPath(proTapped: true),
      );
      expect(result.decision, PaymentProofBetaDecision.proCuriosity);
      expect(result.hasPaymentProof, isFalse);
    });

    test('purchase started returns purchaseIntent', () {
      final result = PaymentProofBetaInstrument.build(
        _proofPath(proTapped: true, purchaseStarted: true),
      );
      expect(result.decision, PaymentProofBetaDecision.purchaseIntent);
      expect(result.hasPaymentProof, isFalse);
    });

    test('purchase completed returns purchaseProof', () {
      final result = PaymentProofBetaInstrument.build(
        _proofPath(
          proTapped: true,
          purchaseStarted: true,
          purchaseCompleted: true,
          entitlementActive: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.purchaseProof);
      expect(result.hasPaymentProof, isTrue);
    });

    test('restore completed returns restoreProof', () {
      final result = PaymentProofBetaInstrument.build(
        _proofPath(
          proTapped: true,
          restoreStarted: true,
          restoreCompleted: true,
          entitlementActive: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.restoreProof);
      expect(result.hasPaymentProof, isTrue);
    });

    test('restore beats maybe and purchase intent', () {
      final result = PaymentProofBetaInstrument.build(
        _proofPath(
          proTapped: true,
          purchaseStarted: true,
          restoreStarted: true,
          restoreCompleted: true,
          testerWouldPayMaybe: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.restoreProof);
    });

    test('proof not reached blocks paid interpretation', () {
      final withoutProof = PaymentProofBetaInstrument.build(
        _input(proTapped: true, testerWouldPayYes: true),
      );
      expect(withoutProof.decision, PaymentProofBetaDecision.proofNotReached);
      expect(withoutProof.blocksPaidInterpretation, isTrue);
      expect(withoutProof.hasPaymentProof, isFalse);

      final maybeBeforeProof = PaymentProofBetaInstrument.build(
        _input(testerWouldPayMaybe: true),
      );
      expect(maybeBeforeProof.decision, PaymentProofBetaDecision.interestOnly);
      expect(maybeBeforeProof.blocksPaidInterpretation, isTrue);
    });

    test('proof reached without Pro tap returns proofReachedNoProTap', () {
      final result = PaymentProofBetaInstrument.build(
        _input(
          firstSave: true,
          secondSave: true,
          firstUsefulProofSeen: true,
          proofAccepted: true,
          proPromiseSeen: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.proofReachedNoProTap);
    });

    test('would pay yes after proof returns paidIntentPromising', () {
      final result = PaymentProofBetaInstrument.build(
        _input(
          firstSave: true,
          secondSave: true,
          firstUsefulProofSeen: true,
          proofAccepted: true,
          proPromiseSeen: true,
          testerWouldPayYes: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.paidIntentPromising);
      expect(result.hasPaymentProof, isFalse);
    });

    test('would pay no after proof returns paidIntentWeak', () {
      final result = PaymentProofBetaInstrument.build(
        _input(
          firstSave: true,
          secondSave: true,
          firstUsefulProofSeen: true,
          proofAccepted: true,
          proPromiseSeen: true,
          testerWouldPayNo: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.paidIntentWeak);
    });

    test('report exposes canonical copy', () {
      final report = PaymentProofBetaInstrument.report(
        PaymentProofBetaInstrument.build(_input(testerWouldPayMaybe: true)),
      );
      expect(report.headline, PaymentProofBetaCopy.headline);
      expect(report.body, PaymentProofBetaCopy.body);
      expect(report.guardrail, PaymentProofBetaCopy.guardrail);
    });
  });

  group('PaymentProofBetaInstrument.fromPaidIntentBetaProof', () {
    test('maps maybe response to interest only', () {
      final result = PaymentProofBetaInstrument.build(
        PaymentProofBetaInstrument.fromPaidIntentBetaProof(
          const PaidIntentBetaProofInput(
            testerWouldPay: PaidIntentBetaWouldPay.maybe,
          ),
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.interestOnly);
    });

    test('maps purchase completed to purchaseProof', () {
      final result = PaymentProofBetaInstrument.build(
        PaymentProofBetaInstrument.fromPaidIntentBetaProof(
          const PaidIntentBetaProofInput(
            firstSaveCompleted: true,
            firstUsefulProofSeen: true,
            proofAcceptedOrCorrected: true,
            proPromiseSeen: true,
            proTapped: true,
            purchaseAttempted: true,
            purchaseCompleted: true,
          ),
          entitlementActive: true,
        ),
      );
      expect(result.decision, PaymentProofBetaDecision.purchaseProof);
    });
  });

  group('protected regression', () {
    test('module does not import paywall screens or purchases_flutter', () {
      for (final path in [
        'lib/features/payment_proof_beta/payment_proof_beta_instrument.dart',
        'lib/features/payment_proof_beta/payment_proof_beta_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('PaywallScreen'), isFalse);
        expect(source.contains('screens/'), isFalse);
      }
    });

    test('no new product surfaces', () {
      expect(
        ReleaseCandidateFreeze.build(
          const ReleaseCandidateFreezeInput(
            changeType: ReleaseCandidateChangeType.newProductFeature,
            blocksRelease: false,
            blocksPurchase: false,
            blocksRestore: false,
            blocksEntitlement: false,
            causesCrash: false,
            risksAppStoreRejection: false,
            affectsSecuritySecrets: false,
            fixesFirstJourneyComprehension: false,
            fixesCriticalProofTrust: false,
            addsNewUserFacingSurface: false,
            changesPricingOrPaywall: false,
            changesProofThresholds: false,
            changesRecordLayout: false,
          ),
        ).allowed,
        isFalse,
      );
    });

    test('docs describe tracked signals and payment proof rules', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('maybe'));
      expect(doc, contains('payment proof'));
      expect(doc, contains('no pricing experiments'));
      expect(doc, contains('no new pro benefits'));
      for (final label in PaymentProofBetaCopy.canonicalTrackedSignals) {
        expect(doc, contains(label.toLowerCase()), reason: label);
      }
    });

    test('guardrail forbids counting interest as revenue evidence', () {
      expect(
        PaymentProofBetaCopy.guardrail.toLowerCase(),
        contains('do not count interest as revenue evidence'),
      );
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PaymentProofBetaCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });
  });
}
