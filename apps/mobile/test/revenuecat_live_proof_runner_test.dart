import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_diagnostics.dart';
import 'package:archiveme_mobile/billing/revenuecat_purchase_journey.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/pro_value/pro_value_copy.dart';
import 'package:archiveme_mobile/features/revenuecat_live_proof/revenuecat_live_proof_copy.dart';
import 'package:archiveme_mobile/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart';
import 'package:flutter_test/flutter_test.dart';

const _docsPath = 'docs/REVENUECAT_LIVE_PROOF_RUNNER.md';

RevenueCatLiveProofInput _input({
  bool iosApiKeyPresent = true,
  bool offeringLoads = true,
  bool? productIdentifierMatches = true,
  bool? priceVisible = true,
  bool? paywallRouteOpens = true,
  bool? purchaseButtonEnabled = true,
  bool? storeKitSheetAppears = true,
  bool? sandboxPurchaseSucceeds = true,
  bool? entitlementActiveAfterPurchase = true,
  bool? proGateUnlocks = true,
  bool? appRestartKeepsEntitlement = true,
  bool? restorePurchasesSucceeds = true,
  bool? restoreAfterReinstallSucceeds = true,
  bool? calmFallbackOnFailure = true,
  bool? noCrash = true,
}) => RevenueCatLiveProofInput(
  iosApiKeyPresent: iosApiKeyPresent,
  offeringLoads: offeringLoads,
  productIdentifierMatches: productIdentifierMatches,
  priceVisible: priceVisible,
  paywallRouteOpens: paywallRouteOpens,
  purchaseButtonEnabled: purchaseButtonEnabled,
  storeKitSheetAppears: storeKitSheetAppears,
  sandboxPurchaseSucceeds: sandboxPurchaseSucceeds,
  entitlementActiveAfterPurchase: entitlementActiveAfterPurchase,
  proGateUnlocks: proGateUnlocks,
  appRestartKeepsEntitlement: appRestartKeepsEntitlement,
  restorePurchasesSucceeds: restorePurchasesSucceeds,
  restoreAfterReinstallSucceeds: restoreAfterReinstallSucceeds,
  calmFallbackOnFailure: calmFallbackOnFailure,
  noCrash: noCrash,
);

RevenueCatLiveProofCheck _check(
  RevenueCatLiveProofResult result,
  RevenueCatLiveProofCheckId id,
) => result.checks.firstWhere((check) => check.id == id);

void main() {
  group('RevenueCatLiveProofRunner.build', () {
    test('runner has fifteen canonical checklist items', () {
      expect(RevenueCatLiveProofRunner.checkCount, 15);
      expect(RevenueCatLiveProofCopy.canonicalChecklistOrder, hasLength(15));
      final result = RevenueCatLiveProofRunner.build(_input());
      expect(result.checks, hasLength(15));
    });

    test('all checks pass -> proved', () {
      final result = RevenueCatLiveProofRunner.build(_input());
      expect(result.decision, RevenueCatLiveProofDecision.proved);
      expect(result.allPassed, isTrue);
      expect(result.earliestBlocker, isNull);
    });

    test('incomplete checklist blocks', () {
      final result = RevenueCatLiveProofRunner.build(
        _input(
          storeKitSheetAppears: null,
          sandboxPurchaseSucceeds: null,
          entitlementActiveAfterPurchase: null,
          proGateUnlocks: null,
          appRestartKeepsEntitlement: null,
          restorePurchasesSucceeds: null,
          restoreAfterReinstallSucceeds: null,
        ),
      );

      expect(result.decision, RevenueCatLiveProofDecision.manualRequired);
      expect(
        _check(result, RevenueCatLiveProofCheckId.storeKitSheetAppears).status,
        RevenueCatLiveProofStatus.pending,
      );
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.restorePurchasesSucceeds,
        ).status,
        RevenueCatLiveProofStatus.blocked,
      );
    });

    test('purchase without restore blocks', () {
      final result = RevenueCatLiveProofRunner.build(
        _input(
          restorePurchasesSucceeds: false,
          restoreAfterReinstallSucceeds: null,
        ),
      );

      expect(result.decision, RevenueCatLiveProofDecision.blocked);
      expect(
        result.earliestBlocker,
        RevenueCatLiveProofCheckId.restorePurchasesSucceeds,
      );
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.restoreAfterReinstallSucceeds,
        ).status,
        RevenueCatLiveProofStatus.blocked,
      );
    });

    test('restore without entitlement persistence blocks', () {
      final result = RevenueCatLiveProofRunner.build(
        _input(
          appRestartKeepsEntitlement: false,
          restorePurchasesSucceeds: null,
        ),
      );

      expect(result.decision, RevenueCatLiveProofDecision.blocked);
      expect(
        result.earliestBlocker,
        RevenueCatLiveProofCheckId.appRestartKeepsEntitlement,
      );
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.restorePurchasesSucceeds,
        ).status,
        RevenueCatLiveProofStatus.blocked,
      );
    });

    test('missing key returns safe internal state', () {
      final result = RevenueCatLiveProofRunner.build(
        const RevenueCatLiveProofInput(
          calmFallbackOnFailure: true,
          noCrash: true,
        ),
      );

      expect(result.decision, RevenueCatLiveProofDecision.safeInternalState);
      expect(
        _check(result, RevenueCatLiveProofCheckId.iosApiKeyPresent).status,
        RevenueCatLiveProofStatus.fail,
      );
      expect(
        _check(result, RevenueCatLiveProofCheckId.offeringLoads).status,
        RevenueCatLiveProofStatus.blocked,
      );
      expect(
        _check(result, RevenueCatLiveProofCheckId.noCrash).status,
        RevenueCatLiveProofStatus.pass,
      );
    });

    test('offering missing blocks purchase path', () {
      final result = RevenueCatLiveProofRunner.build(
        _input(offeringLoads: false, priceVisible: null),
      );

      expect(result.decision, RevenueCatLiveProofDecision.blocked);
      expect(result.earliestBlocker, RevenueCatLiveProofCheckId.offeringLoads);
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.sandboxPurchaseSucceeds,
        ).status,
        RevenueCatLiveProofStatus.blocked,
      );
    });

    test('sandbox purchase failure blocks entitlement checks', () {
      final result = RevenueCatLiveProofRunner.build(
        _input(
          sandboxPurchaseSucceeds: false,
          entitlementActiveAfterPurchase: null,
        ),
      );

      expect(result.decision, RevenueCatLiveProofDecision.blocked);
      expect(
        result.earliestBlocker,
        RevenueCatLiveProofCheckId.sandboxPurchaseSucceeds,
      );
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.entitlementActiveAfterPurchase,
        ).status,
        RevenueCatLiveProofStatus.blocked,
      );
    });

    test('fromDiagnostics maps configured offering state', () {
      final input = RevenueCatLiveProofRunner.fromDiagnostics(
        const RevenueCatDiagnostics(
          revenueCatConfigured: true,
          apiKeyMissing: false,
          offeringsLoaded: true,
          offeringCount: 1,
          packageCount: 1,
          currentOfferingId: 'default',
          productIdentifiers: ['archive_loop_pro_monthly'],
        ),
        priceVisible: true,
        paywallRouteOpens: true,
        purchaseButtonEnabled: true,
      );
      final result = RevenueCatLiveProofRunner.build(input);

      expect(
        _check(result, RevenueCatLiveProofCheckId.iosApiKeyPresent).status,
        RevenueCatLiveProofStatus.pass,
      );
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.productIdentifierMatches,
        ).status,
        RevenueCatLiveProofStatus.pass,
      );
    });

    test('fromPurchaseJourney maps purchase and restore success', () {
      final journey = RevenueCatPurchaseJourney()
        ..offeringLoaded = true
        ..purchaseCompleted = true
        ..entitlementReceived = true
        ..restoreCompleted = true
        ..productIds = ['archive_loop_pro_monthly']
        ..entitlementIds = [ArchiveLoopEntitlementIds.archiveLoopPro];

      final input = RevenueCatLiveProofRunner.fromPurchaseJourney(
        journey,
        diagnostics: const RevenueCatDiagnostics(
          revenueCatConfigured: true,
          apiKeyMissing: false,
          offeringsLoaded: true,
          offeringCount: 1,
          packageCount: 1,
        ),
        priceVisible: true,
        paywallRouteOpens: true,
        purchaseButtonEnabled: true,
        storeKitSheetAppears: true,
        proGateUnlocks: true,
        appRestartKeepsEntitlement: true,
        restoreAfterReinstallSucceeds: true,
        calmFallbackOnFailure: true,
        noCrash: true,
      );
      final result = RevenueCatLiveProofRunner.build(input);

      expect(result.decision, RevenueCatLiveProofDecision.proved);
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.sandboxPurchaseSucceeds,
        ).status,
        RevenueCatLiveProofStatus.pass,
      );
      expect(
        _check(
          result,
          RevenueCatLiveProofCheckId.restorePurchasesSucceeds,
        ).status,
        RevenueCatLiveProofStatus.pass,
      );
    });

    test('report exposes canonical copy', () {
      final report = RevenueCatLiveProofRunner.report(
        RevenueCatLiveProofRunner.build(_input()),
      );
      expect(report.headline, RevenueCatLiveProofCopy.headline);
      expect(report.body, RevenueCatLiveProofCopy.body);
      expect(report.guardrail, RevenueCatLiveProofCopy.guardrail);
    });
  });

  group('RevenueCatLiveProofCopy', () {
    test('guardrail rejects automated purchase proof', () {
      expect(
        RevenueCatLiveProofCopy.guardrail.toLowerCase(),
        contains('do not treat automated tests as purchase proof'),
      );
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final text in RevenueCatLiveProofCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Release smoke', () {
    test('missing RevenueCat key does not crash initialize', () async {
      final rc = RevenueCatService.instance;
      await rc.initialize();
      expect(rc.isConfigured, isFalse);
      expect(rc.diagnostics.apiKeyMissing, isTrue);
    });
  });

  group('Protected regression', () {
    test('module does not import purchases_flutter or billing UI', () {
      for (final path in [
        'lib/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart',
        'lib/features/revenuecat_live_proof/revenuecat_live_proof_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('pro_value_engine'), isFalse);
      }
    });

    test('no price or product copy changes', () {
      expect(
        ProValueCopy.purchaseUnavailableNote,
        'Purchases are not available yet. The free archive flow remains usable.',
      );
      expect(ProValueCopy.headline, 'You saw the first useful repeat.');

      final proValueSource = File(
        'lib/features/pro_value/pro_value_copy.dart',
      ).readAsStringSync();
      expect(
        RevenueCatLiveProofRunner.detectCalmFallbackCopy(proValueSource),
        isTrue,
      );

      for (final path in [
        'lib/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart',
        'lib/features/revenuecat_live_proof/revenuecat_live_proof_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('Deeper long-term evidence history'), isFalse);
        expect(
          source.contains('Purchases are not available yet. The free archive'),
          isFalse,
        );
      }
      expect(
        File(
          'lib/features/revenuecat_live_proof/revenuecat_live_proof_runner.dart',
        ).readAsStringSync().contains('archive_loop_pro_monthly'),
        isTrue,
      );
    });

    test('docs include one canonical checklist', () {
      final docs = File(_docsPath).readAsStringSync();
      for (final label in RevenueCatLiveProofCopy.canonicalChecklistOrder) {
        expect(docs, contains(label), reason: label);
      }
      expect(docs, contains('## Canonical checklist'));
    });
  });
}