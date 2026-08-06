import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/commercial_readiness_gate/commercial_readiness_gate.dart';
import 'package:voicememory_mobile/features/commercial_readiness_gate/commercial_readiness_gate_copy.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';
import 'package:voicememory_mobile/features/store_readiness_single_source/store_readiness_single_source.dart';

const _docsPath = 'docs/COMMERCIAL_READINESS_GATE.md';

CommercialReadinessGateInput _input({
  bool productPromiseClear = true,
  bool firstJourneyStable = true,
  bool firstProofUsefulEnough = true,
  bool proPromiseClear = true,
  bool revenueCatProductLoads = true,
  bool paywallPriceVisible = true,
  bool sandboxPurchaseWorks = true,
  bool restoreWorks = true,
  bool entitlementPersists = true,
  bool testFlightBuildUploaded = true,
  bool paidIntentBetaComplete = true,
  bool secretsRotationDone = true,
}) => CommercialReadinessGateInput(
  productPromiseClear: productPromiseClear,
  firstJourneyStable: firstJourneyStable,
  firstProofUsefulEnough: firstProofUsefulEnough,
  proPromiseClear: proPromiseClear,
  revenueCatProductLoads: revenueCatProductLoads,
  paywallPriceVisible: paywallPriceVisible,
  sandboxPurchaseWorks: sandboxPurchaseWorks,
  restoreWorks: restoreWorks,
  entitlementPersists: entitlementPersists,
  testFlightBuildUploaded: testFlightBuildUploaded,
  paidIntentBetaComplete: paidIntentBetaComplete,
  secretsRotationDone: secretsRotationDone,
);

CommercialReadinessGateCheck _check(
  CommercialReadinessGateResult result,
  CommercialReadinessGateCheckId id,
) => result.checks.firstWhere((check) => check.id == id);

StoreReadinessSingleSourceInput _storeInput({
  bool revenueCatProductLoads = true,
  bool purchaseFlowReachable = true,
  bool restoreWorks = true,
  bool entitlementPersists = true,
  bool testFlightBuildUploaded = true,
  bool paidIntentBetaComplete = true,
  bool secretsRotationDone = true,
}) => StoreReadinessSingleSourceInput(
  signingConfigured: true,
  appStoreMetadataReady: true,
  supportUrlSet: true,
  privacyUrlSet: true,
  termsUrlSet: true,
  screenshotsReady: true,
  revenueCatApiKeyProvided: revenueCatProductLoads,
  revenueCatConfigured: revenueCatProductLoads,
  productsLoaded: revenueCatProductLoads,
  proEntitlementConfigured: entitlementPersists,
  purchaseFlowReachable: purchaseFlowReachable,
  restorePurchasesReachable: restoreWorks,
  restoreNoCrashVerified: restoreWorks,
  purchasesUnavailableFallbackVerified: true,
  proStateCanBeRead: entitlementPersists,
  entitlementPersistsAfterRestart: entitlementPersists,
  physicalDeviceSmokePassed: true,
  testFlightUploadReady: testFlightBuildUploaded,
  paidIntentBetaReady: paidIntentBetaComplete,
  secretsRotated: secretsRotationDone,
);

SecretsRotationLaunchGateInput _secretsRotationInput({
  bool? stripeSecretKeyRotated = true,
  bool? stripeWebhookSecretRotated = true,
  bool? productionEnvUpdated = true,
  bool? oldWebhookDisabled = true,
  bool revenueCatApiKeySeparatedFromDocsLogs = true,
  bool noSecretValuesCommitted = true,
  bool noSecretValuesPrintedInLogs = true,
  bool? vercelEnvProductionVerified = true,
}) => SecretsRotationLaunchGateInput(
  stripeSecretKeyRotated: stripeSecretKeyRotated,
  stripeWebhookSecretRotated: stripeWebhookSecretRotated,
  productionEnvUpdated: productionEnvUpdated,
  oldWebhookDisabled: oldWebhookDisabled,
  revenueCatApiKeySeparatedFromDocsLogs: revenueCatApiKeySeparatedFromDocsLogs,
  noSecretValuesCommitted: noSecretValuesCommitted,
  noSecretValuesPrintedInLogs: noSecretValuesPrintedInLogs,
  vercelEnvProductionVerified: vercelEnvProductionVerified,
);

void main() {
  group('CommercialReadinessGate.build', () {
    test('gate has twelve canonical checks', () {
      final result = CommercialReadinessGate.build(_input());
      expect(result.checks.length, CommercialReadinessGate.checkCount);
      expect(result.checks.map((check) => check.id).toList(), [
        CommercialReadinessGateCheckId.productPromiseClear,
        CommercialReadinessGateCheckId.firstJourneyStable,
        CommercialReadinessGateCheckId.firstProofUsefulEnough,
        CommercialReadinessGateCheckId.proPromiseClear,
        CommercialReadinessGateCheckId.revenueCatProductLoads,
        CommercialReadinessGateCheckId.paywallPriceVisible,
        CommercialReadinessGateCheckId.sandboxPurchaseWorks,
        CommercialReadinessGateCheckId.restoreWorks,
        CommercialReadinessGateCheckId.entitlementPersists,
        CommercialReadinessGateCheckId.testFlightBuildUploaded,
        CommercialReadinessGateCheckId.paidIntentBetaComplete,
        CommercialReadinessGateCheckId.secretsRotationDone,
      ]);
    });

    test('all checks pass -> commerciallyReady', () {
      final result = CommercialReadinessGate.build(_input());
      expect(result.status, CommercialReadinessGateStatus.commerciallyReady);
      expect(result.commerciallyReady, isTrue);
      expect(result.earliestBlocker, isNull);
    });

    test('product promise missing -> productReadyOnly', () {
      final result = CommercialReadinessGate.build(
        _input(productPromiseClear: false),
      );
      expect(result.status, CommercialReadinessGateStatus.productReadyOnly);
      expect(result.productReadyOnly, isTrue);
      expect(
        _check(
          result,
          CommercialReadinessGateCheckId.revenueCatProductLoads,
        ).status,
        CommercialReadinessGateCheckStatus.blocked,
      );
    });

    test('first journey unstable -> productReadyOnly', () {
      final result = CommercialReadinessGate.build(
        _input(firstJourneyStable: false),
      );
      expect(result.status, CommercialReadinessGateStatus.productReadyOnly);
    });

    test('first proof not useful enough -> productReadyOnly', () {
      final result = CommercialReadinessGate.build(
        _input(firstProofUsefulEnough: false),
      );
      expect(result.status, CommercialReadinessGateStatus.productReadyOnly);
    });

    test('Pro promise unclear -> productReadyOnly', () {
      final result = CommercialReadinessGate.build(
        _input(proPromiseClear: false),
      );
      expect(result.status, CommercialReadinessGateStatus.productReadyOnly);
    });

    test('RevenueCat products missing -> storeBlocked', () {
      final result = CommercialReadinessGate.build(
        _input(revenueCatProductLoads: false),
      );
      expect(result.status, CommercialReadinessGateStatus.storeBlocked);
      expect(
        result.earliestBlocker?.id,
        CommercialReadinessGateCheckId.revenueCatProductLoads,
      );
    });

    test('TestFlight missing -> storeBlocked', () {
      final result = CommercialReadinessGate.build(
        _input(testFlightBuildUploaded: false),
      );
      expect(result.status, CommercialReadinessGateStatus.storeBlocked);
    });

    test('paywall price hidden -> purchaseBlocked', () {
      final result = CommercialReadinessGate.build(
        _input(paywallPriceVisible: false),
      );
      expect(result.status, CommercialReadinessGateStatus.purchaseBlocked);
    });

    test('sandbox purchase fails -> purchaseBlocked', () {
      final result = CommercialReadinessGate.build(
        _input(sandboxPurchaseWorks: false),
      );
      expect(result.status, CommercialReadinessGateStatus.purchaseBlocked);
    });

    test('restore fails -> restoreBlocked', () {
      final result = CommercialReadinessGate.build(_input(restoreWorks: false));
      expect(result.status, CommercialReadinessGateStatus.restoreBlocked);
    });

    test('entitlement does not persist -> entitlementBlocked', () {
      final result = CommercialReadinessGate.build(
        _input(entitlementPersists: false),
      );
      expect(result.status, CommercialReadinessGateStatus.entitlementBlocked);
    });

    test('paid-intent beta incomplete -> betaBlocked', () {
      final result = CommercialReadinessGate.build(
        _input(paidIntentBetaComplete: false),
      );
      expect(result.status, CommercialReadinessGateStatus.betaBlocked);
    });

    test('secrets not rotated -> productionBlockedBySecrets', () {
      final result = CommercialReadinessGate.build(
        _input(secretsRotationDone: false),
      );
      expect(
        result.status,
        CommercialReadinessGateStatus.productionBlockedBySecrets,
      );
    });

    test('report exposes canonical copy', () {
      final report = CommercialReadinessGate.report(
        CommercialReadinessGate.build(_input()),
      );
      expect(report.headline, CommercialReadinessGateCopy.headline);
      expect(report.guardrail, CommercialReadinessGateCopy.guardrail);
    });
  });

  group('CommercialReadinessGate.fromStoreReadinessInput', () {
    test('full store input with purchase proof -> commerciallyReady', () {
      final result = CommercialReadinessGate.build(
        CommercialReadinessGate.fromStoreReadinessInput(
          _storeInput(),
          paywallPriceVisible: true,
          sandboxPurchaseWorks: true,
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.commerciallyReady);
    });

    test('store input without purchase proof -> purchaseBlocked', () {
      final result = CommercialReadinessGate.build(
        CommercialReadinessGate.fromStoreReadinessInput(
          _storeInput(),
          paywallPriceVisible: false,
          sandboxPurchaseWorks: false,
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.purchaseBlocked);
    });
  });

  group('CommercialReadinessGate.buildFromSources', () {
    PaidIntentBetaProofInput paidIntentInput({
      bool purchaseCompleted = true,
      bool purchaseMechanicsBlocked = false,
      PaidIntentBetaWouldPay? testerWouldPay = PaidIntentBetaWouldPay.yes,
    }) => PaidIntentBetaProofInput(
      firstSaveCompleted: true,
      firstUsefulProofSeen: true,
      proofAcceptedOrCorrected: true,
      proPromiseSeen: true,
      proTapped: true,
      purchaseAttempted: true,
      purchaseCompleted: purchaseCompleted,
      purchaseMechanicsBlocked: purchaseMechanicsBlocked,
      testerWouldPay: testerWouldPay,
    );

    RevenueCatSandboxProofInput sandboxInput({
      bool sandboxPurchaseSucceeds = true,
      bool restorePurchasesSucceeds = true,
      bool entitlementPersistsAfterRestart = true,
    }) => RevenueCatSandboxProofInput(
      iosApiKeyPresent: true,
      offeringLoads: true,
      productTitlePriceVisible: true,
      sandboxPurchaseSucceeds: sandboxPurchaseSucceeds,
      restorePurchasesSucceeds: restorePurchasesSucceeds,
      entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    );

    test('integrated sources -> commerciallyReady', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(),
          sandbox: sandboxInput(),
          paidIntent: paidIntentInput(),
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.commerciallyReady);
    });

    test('sandbox purchase failure -> purchaseBlocked', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(),
          sandbox: sandboxInput(sandboxPurchaseSucceeds: false),
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.purchaseBlocked);
      expect(
        result.earliestBlocker?.id,
        CommercialReadinessGateCheckId.sandboxPurchaseWorks,
      );
    });

    test('paid intent purchase mechanics blocked -> purchaseBlocked', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(paidIntentBetaComplete: false),
          sandbox: sandboxInput(),
          paidIntent: paidIntentInput(
            purchaseCompleted: false,
            purchaseMechanicsBlocked: true,
          ),
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.purchaseBlocked);
    });

    test('paid intent weak without purchase -> betaBlocked', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(paidIntentBetaComplete: false),
          sandbox: sandboxInput(),
          paidIntent: paidIntentInput(
            purchaseCompleted: false,
            testerWouldPay: PaidIntentBetaWouldPay.no,
          ),
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.betaBlocked);
    });

    test('product promise failure prioritizes earliest product blocker', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(),
          sandbox: sandboxInput(),
          productPromiseClear: false,
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.productReadyOnly);
      expect(
        result.earliestBlocker?.id,
        CommercialReadinessGateCheckId.productPromiseClear,
      );
    });

    test('launch gate ready -> commerciallyReady', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(),
          sandbox: sandboxInput(),
          paidIntent: paidIntentInput(),
          secretsRotation: _secretsRotationInput(),
        ),
      );
      expect(result.status, CommercialReadinessGateStatus.commerciallyReady);
    });

    test(
      'launch gate pending rotation overrides store secretsRotated flag',
      () {
        final result = CommercialReadinessGate.buildFromSources(
          CommercialReadinessGateSources(
            store: _storeInput(secretsRotationDone: true),
            sandbox: sandboxInput(),
            paidIntent: paidIntentInput(),
            secretsRotation: _secretsRotationInput(
              stripeSecretKeyRotated: null,
              stripeWebhookSecretRotated: null,
              productionEnvUpdated: null,
              oldWebhookDisabled: null,
              vercelEnvProductionVerified: null,
            ),
          ),
        );
        expect(
          result.status,
          CommercialReadinessGateStatus.productionBlockedBySecrets,
        );
        expect(
          _check(
            result,
            CommercialReadinessGateCheckId.secretsRotationDone,
          ).status,
          CommercialReadinessGateCheckStatus.fail,
        );
      },
    );

    test('launch gate repo safety failure -> productionBlockedBySecrets', () {
      final result = CommercialReadinessGate.buildFromSources(
        CommercialReadinessGateSources(
          store: _storeInput(),
          sandbox: sandboxInput(),
          paidIntent: paidIntentInput(),
          secretsRotation: _secretsRotationInput(
            noSecretValuesCommitted: false,
          ),
        ),
      );
      expect(
        result.status,
        CommercialReadinessGateStatus.productionBlockedBySecrets,
      );
    });
  });

  group('CommercialReadinessGate.secretsRotationLaunchGate bridge', () {
    test('maps ready launch gate to secretsRotationDone', () {
      final launchResult = SecretsRotationLaunchGate.build(
        _secretsRotationInput(),
      );
      expect(
        CommercialReadinessGate.secretsRotationDoneFromLaunchGate(launchResult),
        isTrue,
      );
      expect(
        launchResult.status,
        SecretsRotationLaunchGateStatus.readyForProductionSubmission,
      );
    });

    test('maps pending launch gate to secretsRotationDone false', () {
      final launchResult = SecretsRotationLaunchGate.build(
        _secretsRotationInput(stripeSecretKeyRotated: null),
      );
      expect(
        CommercialReadinessGate.secretsRotationDoneFromLaunchGate(launchResult),
        isFalse,
      );
      expect(
        launchResult.status,
        SecretsRotationLaunchGateStatus.safeForInternalTestFlight,
      );
    });
  });

  group('CommercialReadinessGate.fromRepoSignals', () {
    late String proEvidenceValueCopySource;
    late String featureNoiseReductionCopySource;
    late String archiveEvidenceGateSource;
    late String proSinglePromiseCopySource;
    late String paywallScreenSource;

    setUpAll(() {
      proEvidenceValueCopySource = File(
        'lib/features/pro_evidence_value/pro_evidence_value_copy.dart',
      ).readAsStringSync();
      featureNoiseReductionCopySource = File(
        'lib/features/feature_noise_reduction/feature_noise_reduction_copy.dart',
      ).readAsStringSync();
      archiveEvidenceGateSource = File(
        'lib/features/archive_evidence/archive_evidence_quality_gate.dart',
      ).readAsStringSync();
      proSinglePromiseCopySource = File(
        'lib/features/pro_single_promise/pro_single_promise_copy.dart',
      ).readAsStringSync();
      paywallScreenSource = File(
        'lib/screens/paywall_screen.dart',
      ).readAsStringSync();
    });

    test('repo signals detect product and Pro promise copy', () {
      expect(
        CommercialReadinessGate.detectProductPromiseCopyPresent(
          proEvidenceValueCopySource,
        ),
        isTrue,
      );
      expect(
        CommercialReadinessGate.detectFirstJourneyCopyPresent(
          featureNoiseReductionCopySource,
        ),
        isTrue,
      );
      expect(
        CommercialReadinessGate.detectFirstProofThresholdGuarded(
          archiveEvidenceGateSource,
        ),
        isTrue,
      );
      expect(
        CommercialReadinessGate.detectProPromiseCopyPresent(
          proSinglePromiseCopySource,
        ),
        isTrue,
      );
      expect(
        CommercialReadinessGate.detectPaywallPriceKeyPresent(
          paywallScreenSource,
        ),
        isTrue,
      );
    });

    test('paid intent promising counts as beta complete', () {
      expect(
        CommercialReadinessGate.paidIntentBetaCompleteFromDecision(
          PaidIntentBetaProofDecision.paidIntentPromising,
        ),
        isTrue,
      );
      expect(
        CommercialReadinessGate.paidIntentBetaCompleteFromDecision(
          PaidIntentBetaProofDecision.paidIntentWeak,
        ),
        isFalse,
      );
    });
  });

  group('protected regression', () {
    test('docs describe classification-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('no product features'));
      expect(doc, contains('no paywall mechanics changes'));
      expect(doc, contains('commercially ready'));
    });

    test('guardrail forbids feature and paywall redesign', () {
      final lower = CommercialReadinessGateCopy.guardrail.toLowerCase();
      expect(lower, contains('no product features'));
      expect(lower, contains('no paywall mechanics changes'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in CommercialReadinessGateCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });
  });
}
