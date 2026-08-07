import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/commercial_proof_executor/commercial_proof_executor.dart';
import 'package:voicememory_mobile/features/commercial_proof_executor/commercial_proof_executor_copy.dart';
import 'package:voicememory_mobile/features/commercial_readiness_gate/commercial_readiness_gate.dart';
import 'package:voicememory_mobile/features/commercial_readiness_gate/commercial_readiness_gate_copy.dart';

const _docsPath = 'docs/COMMERCIAL_PROOF_EXECUTOR.md';

CommercialProofExecutorInput _input({
  bool productPromiseClear = true,
  bool firstJourneyStable = true,
  bool firstProofUseful = true,
  bool proPromiseClear = true,
  bool revenueCatProductsLoad = true,
  bool paywallPriceVisible = true,
  bool sandboxPurchaseWorks = true,
  bool restoreWorks = true,
  bool entitlementPersists = true,
  bool testFlightUploaded = true,
  bool paidIntentBetaComplete = true,
  bool secretsRotationComplete = true,
  bool secretsRotationRepoSafe = true,
}) => CommercialProofExecutorInput(
  productPromiseClear: productPromiseClear,
  firstJourneyStable: firstJourneyStable,
  firstProofUseful: firstProofUseful,
  proPromiseClear: proPromiseClear,
  revenueCatProductsLoad: revenueCatProductsLoad,
  paywallPriceVisible: paywallPriceVisible,
  sandboxPurchaseWorks: sandboxPurchaseWorks,
  restoreWorks: restoreWorks,
  entitlementPersists: entitlementPersists,
  testFlightUploaded: testFlightUploaded,
  paidIntentBetaComplete: paidIntentBetaComplete,
  secretsRotationComplete: secretsRotationComplete,
  secretsRotationRepoSafe: secretsRotationRepoSafe,
);

void main() {
  group('CommercialProofExecutor.build', () {
    test('executor has twelve canonical checklist items', () {
      final result = CommercialProofExecutor.build(_input());
      expect(result.checks.length, CommercialProofExecutor.checkCount);
      expect(
        result.checks.map((check) => check.id).toList(),
        CommercialProofExecutor.canonicalChecklistOrder,
      );
    });

    test('all checks pass -> commerciallyReady', () {
      final result = CommercialProofExecutor.build(_input());
      expect(result.status, CommercialProofExecutorStatus.commerciallyReady);
      expect(result.commerciallyReady, isTrue);
      expect(result.internalTestFlightReady, isTrue);
      expect(result.productionSubmissionReady, isTrue);
      expect(result.earliestBlocker, isNull);
    });

    test('product promise missing -> productReadyOnly', () {
      final result = CommercialProofExecutor.build(
        _input(productPromiseClear: false),
      );
      expect(result.status, CommercialProofExecutorStatus.productReadyOnly);
      expect(
        result.earliestBlocker,
        CommercialProofExecutorCheckId.productPromiseClear,
      );
    });

    test('RevenueCat products missing -> storeBlocked', () {
      final result = CommercialProofExecutor.build(
        _input(revenueCatProductsLoad: false),
      );
      expect(result.status, CommercialProofExecutorStatus.storeBlocked);
    });

    test('paywall price hidden -> purchaseBlocked', () {
      final result = CommercialProofExecutor.build(
        _input(paywallPriceVisible: false),
      );
      expect(result.status, CommercialProofExecutorStatus.purchaseBlocked);
    });

    test('sandbox purchase fails -> purchaseBlocked', () {
      final result = CommercialProofExecutor.build(
        _input(sandboxPurchaseWorks: false),
      );
      expect(result.status, CommercialProofExecutorStatus.purchaseBlocked);
    });

    test('restore fails -> restoreBlocked', () {
      final result = CommercialProofExecutor.build(_input(restoreWorks: false));
      expect(result.status, CommercialProofExecutorStatus.restoreBlocked);
    });

    test('entitlement does not persist -> entitlementBlocked', () {
      final result = CommercialProofExecutor.build(
        _input(entitlementPersists: false),
      );
      expect(result.status, CommercialProofExecutorStatus.entitlementBlocked);
    });

    test('TestFlight missing -> testFlightBlocked', () {
      final result = CommercialProofExecutor.build(
        _input(testFlightUploaded: false),
      );
      expect(result.status, CommercialProofExecutorStatus.testFlightBlocked);
      expect(
        result.earliestBlocker,
        CommercialProofExecutorCheckId.testFlightUploaded,
      );
    });

    test('paid-intent beta incomplete -> betaBlocked', () {
      final result = CommercialProofExecutor.build(
        _input(paidIntentBetaComplete: false),
      );
      expect(result.status, CommercialProofExecutorStatus.betaBlocked);
    });

    test('secrets incomplete blocks production only when repo safe', () {
      final result = CommercialProofExecutor.build(
        _input(secretsRotationComplete: false),
      );
      expect(
        result.status,
        CommercialProofExecutorStatus.productionBlockedBySecrets,
      );
      expect(result.commerciallyReady, isFalse);
      expect(result.productionSubmissionReady, isFalse);
      expect(result.internalTestFlightReady, isTrue);
    });

    test('secrets repo unsafe blocks internal TestFlight too', () {
      final result = CommercialProofExecutor.build(
        _input(secretsRotationComplete: false, secretsRotationRepoSafe: false),
      );
      expect(
        result.status,
        CommercialProofExecutorStatus.productionBlockedBySecrets,
      );
      expect(result.internalTestFlightReady, isFalse);
    });

    test('report exposes canonical copy', () {
      final report = CommercialProofExecutor.report(
        CommercialProofExecutor.build(_input()),
      );
      expect(report.headline, CommercialProofExecutorCopy.headline);
      expect(report.guardrail, CommercialProofExecutorCopy.guardrail);
    });
  });

  group('CommercialProofExecutor.fromCommercialReadinessGateInput', () {
    test('maps commercial readiness input to executor result', () {
      final result = CommercialProofExecutor.fromCommercialReadinessGateInput(
        CommercialReadinessGateInput(
          productPromiseClear: true,
          firstJourneyStable: true,
          firstProofUsefulEnough: true,
          proPromiseClear: true,
          revenueCatProductLoads: true,
          paywallPriceVisible: true,
          sandboxPurchaseWorks: true,
          restoreWorks: true,
          entitlementPersists: true,
          testFlightBuildUploaded: true,
          paidIntentBetaComplete: true,
          secretsRotationDone: true,
        ),
      );
      expect(result.status, CommercialProofExecutorStatus.commerciallyReady);
    });

    test('splits TestFlight blocker from store blocker', () {
      final gateResult = CommercialReadinessGate.build(
        CommercialReadinessGateInput(
          productPromiseClear: true,
          firstJourneyStable: true,
          firstProofUsefulEnough: true,
          proPromiseClear: true,
          revenueCatProductLoads: true,
          paywallPriceVisible: true,
          sandboxPurchaseWorks: true,
          restoreWorks: true,
          entitlementPersists: true,
          testFlightBuildUploaded: false,
        ),
      );
      expect(gateResult.status, CommercialReadinessGateStatus.storeBlocked);

      final executorResult =
          CommercialProofExecutor.fromCommercialReadinessGateInput(
            CommercialReadinessGateInput(
              productPromiseClear: true,
              firstJourneyStable: true,
              firstProofUsefulEnough: true,
              proPromiseClear: true,
              revenueCatProductLoads: true,
              paywallPriceVisible: true,
              sandboxPurchaseWorks: true,
              restoreWorks: true,
              entitlementPersists: true,
              testFlightBuildUploaded: false,
            ),
          );
      expect(
        executorResult.status,
        CommercialProofExecutorStatus.testFlightBlocked,
      );
    });
  });

  group('protected regression', () {
    test('module does not import feature surfaces', () {
      for (final path in [
        'lib/features/commercial_proof_executor/commercial_proof_executor.dart',
        'lib/features/commercial_proof_executor/commercial_proof_executor_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('screens/record_screen'), isFalse);
        expect(source.contains('widgets/'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
        expect(source.contains('package:purchases_flutter'), isFalse);
      }
    });

    test('docs include one canonical checklist', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('canonical checklist'));
      expect(doc, contains('product promise clear'));
      expect(doc, contains('secrets rotation complete'));
      expect(doc, contains('no product features'));
      expect(doc, contains('no pricing changes'));
    });

    test(
      'guardrail requires real purchase restore entitlement beta evidence',
      () {
        final lower = CommercialProofExecutorCopy.guardrail.toLowerCase();
        expect(lower, contains('purchase'));
        expect(lower, contains('restore'));
        expect(lower, contains('entitlement'));
        expect(lower, contains('beta evidence'));
      },
    );

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in CommercialProofExecutorCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });
  });
}
