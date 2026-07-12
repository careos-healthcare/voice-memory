import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/commercial_proof_executor/commercial_proof_executor.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/release_evidence/release_evidence_pack.dart';
import 'package:voicememory_mobile/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist_copy.dart';

const _docsPath = 'docs/SINGLE_LAUNCH_CHECKLIST.md';

SingleLaunchChecklistInput _input({
  bool? cleanGit = true,
  bool? versionBuildSet = true,
  bool? physicalIphoneSmoke = true,
  bool? physicalIpadSmoke = true,
  bool? productionApiWorks = true,
  bool? voiceSaveWorks = true,
  bool? typedSaveWorks = true,
  bool? firstProofWorks = true,
  bool? proPromiseVisible = true,
  bool? revenueCatProductsLoad = true,
  bool? paywallPriceVisible = true,
  bool? sandboxPurchaseWorks = true,
  bool? entitlementUnlocks = true,
  bool? restoreWorks = true,
  bool? entitlementPersists = true,
  bool? supportPrivacyTermsWork = true,
  bool? screenshotsReady = true,
  bool? testFlightUploaded = true,
  bool? paidIntentBetaComplete = true,
  bool? secretsRotatedBeforeProduction = true,
}) =>
    SingleLaunchChecklistInput(
      cleanGit: cleanGit,
      versionBuildSet: versionBuildSet,
      physicalIphoneSmoke: physicalIphoneSmoke,
      physicalIpadSmoke: physicalIpadSmoke,
      productionApiWorks: productionApiWorks,
      voiceSaveWorks: voiceSaveWorks,
      typedSaveWorks: typedSaveWorks,
      firstProofWorks: firstProofWorks,
      proPromiseVisible: proPromiseVisible,
      revenueCatProductsLoad: revenueCatProductsLoad,
      paywallPriceVisible: paywallPriceVisible,
      sandboxPurchaseWorks: sandboxPurchaseWorks,
      entitlementUnlocks: entitlementUnlocks,
      restoreWorks: restoreWorks,
      entitlementPersists: entitlementPersists,
      supportPrivacyTermsWork: supportPrivacyTermsWork,
      screenshotsReady: screenshotsReady,
      testFlightUploaded: testFlightUploaded,
      paidIntentBetaComplete: paidIntentBetaComplete,
      secretsRotatedBeforeProduction: secretsRotatedBeforeProduction,
    );

ReleaseEvidencePackInput _releaseEvidence({
  bool cleanGitStatus = true,
  bool versionBuildCaptured = true,
  bool physicalIphoneSmokeTest = true,
  bool physicalIpadSmokeTest = true,
  bool productionApiSmokeTest = true,
  bool voiceSavePath = true,
  bool typedSavePath = true,
  bool firstProofPath = true,
  bool proPaywallRoute = true,
  bool revenueCatProductLoad = true,
  bool sandboxPurchase = true,
  bool restorePurchases = true,
  bool entitlementPersistence = true,
  bool supportUrl = true,
  bool privacyUrl = true,
  bool termsUrl = true,
  bool screenshots = true,
  bool testFlightUploaded = true,
  bool secretsRotated = true,
}) =>
    ReleaseEvidencePackInput(
      cleanGitStatus: cleanGitStatus,
      versionBuildCaptured: versionBuildCaptured,
      physicalIphoneSmokeTest: physicalIphoneSmokeTest,
      physicalIpadSmokeTest: physicalIpadSmokeTest,
      productionApiSmokeTest: productionApiSmokeTest,
      voiceSavePath: voiceSavePath,
      typedSavePath: typedSavePath,
      firstProofPath: firstProofPath,
      proPaywallRoute: proPaywallRoute,
      revenueCatProductLoad: revenueCatProductLoad,
      sandboxPurchase: sandboxPurchase,
      restorePurchases: restorePurchases,
      entitlementPersistence: entitlementPersistence,
      supportUrl: supportUrl,
      privacyUrl: privacyUrl,
      termsUrl: termsUrl,
      screenshots: screenshots,
      testFlightUploaded: testFlightUploaded,
      secretsRotated: secretsRotated,
    );

SingleLaunchChecklistInput _withMissing(SingleLaunchChecklistItemId item) {
  return _input(
    cleanGit: item == SingleLaunchChecklistItemId.cleanGit ? false : true,
    versionBuildSet:
        item == SingleLaunchChecklistItemId.versionBuildSet ? false : true,
    physicalIphoneSmoke:
        item == SingleLaunchChecklistItemId.physicalIphoneSmoke ? false : true,
    physicalIpadSmoke:
        item == SingleLaunchChecklistItemId.physicalIpadSmoke ? false : true,
    productionApiWorks:
        item == SingleLaunchChecklistItemId.productionApiWorks ? false : true,
    voiceSaveWorks:
        item == SingleLaunchChecklistItemId.voiceSaveWorks ? false : true,
    typedSaveWorks:
        item == SingleLaunchChecklistItemId.typedSaveWorks ? false : true,
    firstProofWorks:
        item == SingleLaunchChecklistItemId.firstProofWorks ? false : true,
    proPromiseVisible:
        item == SingleLaunchChecklistItemId.proPromiseVisible ? false : true,
    revenueCatProductsLoad:
        item == SingleLaunchChecklistItemId.revenueCatProductsLoad ? false : true,
    paywallPriceVisible:
        item == SingleLaunchChecklistItemId.paywallPriceVisible ? false : true,
    sandboxPurchaseWorks:
        item == SingleLaunchChecklistItemId.sandboxPurchaseWorks ? false : true,
    entitlementUnlocks:
        item == SingleLaunchChecklistItemId.entitlementUnlocks ? false : true,
    restoreWorks: item == SingleLaunchChecklistItemId.restoreWorks ? false : true,
    entitlementPersists:
        item == SingleLaunchChecklistItemId.entitlementPersists ? false : true,
    supportPrivacyTermsWork:
        item == SingleLaunchChecklistItemId.supportPrivacyTermsWork ? false : true,
    screenshotsReady:
        item == SingleLaunchChecklistItemId.screenshotsReady ? false : true,
    testFlightUploaded:
        item == SingleLaunchChecklistItemId.testFlightUploaded ? false : true,
    paidIntentBetaComplete:
        item == SingleLaunchChecklistItemId.paidIntentBetaComplete ? false : true,
    secretsRotatedBeforeProduction: item ==
            SingleLaunchChecklistItemId.secretsRotatedBeforeProduction
        ? false
        : true,
  );
}

SingleLaunchChecklistCheck _check(
  SingleLaunchChecklistResult result,
  SingleLaunchChecklistItemId id,
) =>
    result.checks.firstWhere((check) => check.id == id);

void main() {
  group('SingleLaunchChecklist.build', () {
    test('checklist has twenty canonical items in order', () {
      final result = SingleLaunchChecklist.build(_input());
      expect(result.checks.length, SingleLaunchChecklist.itemCount);
      expect(
        result.checks.map((check) => check.id).toList(),
        SingleLaunchChecklist.canonicalChecklistOrder,
      );
    });

    test('all items pass with secrets -> readyForSubmission', () {
      final result = SingleLaunchChecklist.build(_input());
      expect(result.status, SingleLaunchChecklistStatus.readyForSubmission);
      expect(result.readyForSubmission, isTrue);
      expect(result.readyForTestFlight, isTrue);
      expect(result.earliestBlocker, isNull);
    });

    test('all items pass without secrets -> readyForTestFlight', () {
      final result = SingleLaunchChecklist.build(
        _input(secretsRotatedBeforeProduction: false),
      );
      expect(result.status, SingleLaunchChecklistStatus.readyForTestFlight);
      expect(result.readyForTestFlight, isTrue);
      expect(result.readyForSubmission, isFalse);
    });

    test('missing item -> notReady with earliest blocker', () {
      final result = SingleLaunchChecklist.build(
        _input(paywallPriceVisible: false),
      );
      expect(result.status, SingleLaunchChecklistStatus.notReady);
      expect(
        result.earliestBlocker,
        SingleLaunchChecklistItemId.paywallPriceVisible,
      );
    });

    test('each required item blocks readiness when false', () {
      for (final item in SingleLaunchChecklist.testFlightRequiredItems) {
        final result = SingleLaunchChecklist.build(_withMissing(item));
        expect(
          result.status,
          SingleLaunchChecklistStatus.notReady,
          reason: item.name,
        );
        expect(result.earliestBlocker, item, reason: item.name);
      }
    });

    test('pending paywall price blocks TestFlight readiness', () {
      final result = SingleLaunchChecklist.build(
        _input(paywallPriceVisible: null),
      );
      expect(result.status, SingleLaunchChecklistStatus.notReady);
      expect(
        _check(result, SingleLaunchChecklistItemId.paywallPriceVisible).status,
        SingleLaunchChecklistCheckStatus.pending,
      );
    });

    test('entitlement unlock and persist are separate checks', () {
      final unlockOnly = SingleLaunchChecklist.build(
        _input(entitlementUnlocks: true, entitlementPersists: false),
      );
      expect(
        unlockOnly.earliestBlocker,
        SingleLaunchChecklistItemId.entitlementPersists,
      );

      final persistOnly = SingleLaunchChecklist.build(
        _input(entitlementUnlocks: false, entitlementPersists: true),
      );
      expect(
        persistOnly.earliestBlocker,
        SingleLaunchChecklistItemId.entitlementUnlocks,
      );
    });

    test('report exposes canonical copy', () {
      final report = SingleLaunchChecklist.report(
        SingleLaunchChecklist.build(_input()),
      );
      expect(report.headline, SingleLaunchChecklistCopy.headline);
      expect(report.guardrail, SingleLaunchChecklistCopy.guardrail);
      expect(report.orderLine, SingleLaunchChecklistCopy.orderLine);
    });
  });

  group('SingleLaunchChecklist bridges', () {
    test('fromReleaseEvidencePackInput maps release evidence fields', () {
      final input = SingleLaunchChecklist.fromReleaseEvidencePackInput(
        _releaseEvidence(),
        paywallPriceVisible: true,
        paidIntentBetaComplete: true,
      );
      final result = SingleLaunchChecklist.build(input);
      expect(result.status, SingleLaunchChecklistStatus.readyForSubmission);
      expect(
        _check(result, SingleLaunchChecklistItemId.cleanGit).status,
        SingleLaunchChecklistCheckStatus.pass,
      );
      expect(
        _check(result, SingleLaunchChecklistItemId.paywallPriceVisible).status,
        SingleLaunchChecklistCheckStatus.pass,
      );
    });

    test('fromCommercialProofExecutorInput bridges commercial checks', () {
      final input = SingleLaunchChecklist.fromCommercialProofExecutorInput(
        const CommercialProofExecutorInput(
          productPromiseClear: true,
          firstJourneyStable: true,
          firstProofUseful: true,
          proPromiseClear: true,
          revenueCatProductsLoad: true,
          paywallPriceVisible: true,
          sandboxPurchaseWorks: true,
          restoreWorks: true,
          entitlementPersists: true,
          testFlightUploaded: true,
          paidIntentBetaComplete: true,
          secretsRotationComplete: true,
        ),
        releaseEvidence: _releaseEvidence(),
      );
      final result = SingleLaunchChecklist.build(input);
      expect(result.status, SingleLaunchChecklistStatus.readyForSubmission);
    });

    test('composeInput bridges RevenueCat live proof fields', () {
      final input = SingleLaunchChecklist.composeInput(
        releaseEvidence: _releaseEvidence(secretsRotated: false),
        revenueCatLiveProof: const RevenueCatLiveProofInput(
          offeringLoads: true,
          priceVisible: true,
          sandboxPurchaseSucceeds: true,
          proGateUnlocks: true,
          restorePurchasesSucceeds: true,
          appRestartKeepsEntitlement: true,
        ),
        paidIntentBeta: PaidIntentBetaProof.build(
          PaidIntentBetaProof.fromAttribution(
            firstSaveCompleted: true,
            firstUsefulProofSeen: true,
            proofAcceptedOrCorrected: true,
            proPromiseSeen: true,
            proTapped: true,
            purchaseAttempted: true,
            purchaseCompleted: true,
          ),
        ),
      );
      final result = SingleLaunchChecklist.build(input);
      expect(result.status, SingleLaunchChecklistStatus.readyForTestFlight);
      expect(
        _check(result, SingleLaunchChecklistItemId.paywallPriceVisible).status,
        SingleLaunchChecklistCheckStatus.pass,
      );
      expect(
        _check(result, SingleLaunchChecklistItemId.entitlementUnlocks).status,
        SingleLaunchChecklistCheckStatus.pass,
      );
    });

    test('composeInput maps secrets rotation gate to submission readiness', () {
      final input = SingleLaunchChecklist.composeInput(
        releaseEvidence: _releaseEvidence(secretsRotated: false),
        commercial: const CommercialProofExecutorInput(
          productPromiseClear: true,
          firstJourneyStable: true,
          firstProofUseful: true,
          proPromiseClear: true,
          revenueCatProductsLoad: true,
          paywallPriceVisible: true,
          sandboxPurchaseWorks: true,
          restoreWorks: true,
          entitlementPersists: true,
          testFlightUploaded: true,
          paidIntentBetaComplete: true,
          secretsRotationComplete: false,
        ),
        secretsRotation: SecretsRotationLaunchGateResult(
          status: SecretsRotationLaunchGateStatus.readyForProductionSubmission,
          message: 'ready',
          recommendation: 'ready',
          checks: const [],
          earliestBlocker: null,
          productionSubmissionReady: true,
          testFlightAllowed: true,
        ),
      );
      final result = SingleLaunchChecklist.build(input);
      expect(result.status, SingleLaunchChecklistStatus.readyForSubmission);
    });
  });

  group('protected regression', () {
    test('docs describe checklist aggregator scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('checklist aggregator'));
      expect(doc, contains('do not change product ui'));
      expect(doc, contains('do not change purchase logic'));
    });

    test('guardrail forbids product and purchase changes', () {
      final guardrail = SingleLaunchChecklistCopy.guardrail.toLowerCase();
      expect(guardrail, contains('do not change product ui'));
      expect(guardrail, contains('purchase logic'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in SingleLaunchChecklistCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import billing or purchases_flutter', () {
      for (final path in [
        'lib/features/single_launch_checklist/single_launch_checklist.dart',
        'lib/features/single_launch_checklist/single_launch_checklist_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers single launch checklist copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('SingleLaunchChecklistCopy.allVisibleStrings()'),
      );
    });
  });
}
