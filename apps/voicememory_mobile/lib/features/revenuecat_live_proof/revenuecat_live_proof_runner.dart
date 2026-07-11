import '../../billing/archive_loop_entitlement_ids.dart';
import '../../billing/revenuecat_diagnostics.dart';
import '../../billing/revenuecat_purchase_journey.dart';
import 'revenuecat_live_proof_copy.dart';

/// RevenueCat live proof runner — fifteen-step iOS sandbox checklist.
abstract final class RevenueCatLiveProofRunner {
  RevenueCatLiveProofRunner._();

  static const checkCount = 15;

  static const expectedStoreProductIds = [
    'archive_loop_pro_monthly',
    'archive_loop_pro_yearly',
  ];

  static RevenueCatLiveProofResult build(RevenueCatLiveProofInput input) {
    final checks = _buildChecks(input);
    final decision = _resolveDecision(input, checks);
    return RevenueCatLiveProofResult(
      decision: decision,
      message: _messageFor(decision),
      checks: checks,
      earliestBlocker: checks
          .where((check) => check.status == RevenueCatLiveProofStatus.fail)
          .map((check) => check.id)
          .firstOrNull,
      allPassed: decision == RevenueCatLiveProofDecision.proved,
    );
  }

  static RevenueCatLiveProofReport report(RevenueCatLiveProofResult result) =>
      RevenueCatLiveProofReport(
        headline: RevenueCatLiveProofCopy.headline,
        body: RevenueCatLiveProofCopy.body,
        manualNote: RevenueCatLiveProofCopy.manualNote,
        guardrail: RevenueCatLiveProofCopy.guardrail,
        scopeLine: RevenueCatLiveProofCopy.scopeLine,
        result: result,
      );

  static bool productIdentifiersMatchStoreConfig(List<String> productIds) {
    if (productIds.isEmpty) return false;
    for (final id in productIds) {
      if (expectedStoreProductIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  static bool recognizesProEntitlement(List<String> entitlementIds) {
    for (final id in entitlementIds) {
      if (ArchiveLoopEntitlementIds.revenueCatEntitlementIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  static bool detectCalmFallbackCopy(String proValueCopySource) =>
      proValueCopySource.contains('purchaseUnavailableNote') &&
      proValueCopySource.contains('Purchases are not available yet');

  static RevenueCatLiveProofInput fromDiagnostics(
    RevenueCatDiagnostics diagnostics, {
    bool? productIdentifierMatches,
    bool? priceVisible,
    bool? paywallRouteOpens,
    bool? purchaseButtonEnabled,
    bool? storeKitSheetAppears,
    bool? sandboxPurchaseSucceeds,
    bool? entitlementActiveAfterPurchase,
    bool? proGateUnlocks,
    bool? appRestartKeepsEntitlement,
    bool? restorePurchasesSucceeds,
    bool? restoreAfterReinstallSucceeds,
    bool? calmFallbackOnFailure,
    bool? noCrash,
    List<String> activeEntitlementIds = const [],
  }) =>
      RevenueCatLiveProofInput(
        iosApiKeyPresent:
            diagnostics.revenueCatConfigured && !diagnostics.apiKeyMissing,
        offeringLoads: diagnostics.offeringsLoaded,
        productIdentifierMatches: productIdentifierMatches ??
            (diagnostics.productIdentifiers.isNotEmpty
                ? productIdentifiersMatchStoreConfig(
                    diagnostics.productIdentifiers,
                  )
                : null),
        priceVisible: priceVisible,
        paywallRouteOpens: paywallRouteOpens,
        purchaseButtonEnabled: purchaseButtonEnabled,
        storeKitSheetAppears: storeKitSheetAppears,
        sandboxPurchaseSucceeds: sandboxPurchaseSucceeds,
        entitlementActiveAfterPurchase: entitlementActiveAfterPurchase ??
            (recognizesProEntitlement(activeEntitlementIds) ? true : null),
        proGateUnlocks: proGateUnlocks,
        appRestartKeepsEntitlement: appRestartKeepsEntitlement,
        restorePurchasesSucceeds: restorePurchasesSucceeds,
        restoreAfterReinstallSucceeds: restoreAfterReinstallSucceeds,
        calmFallbackOnFailure: calmFallbackOnFailure,
        noCrash: noCrash,
        activeEntitlementIds: activeEntitlementIds,
      );

  static RevenueCatLiveProofInput fromPurchaseJourney(
    RevenueCatPurchaseJourney journey, {
    required RevenueCatDiagnostics diagnostics,
    bool iosApiKeyPresent = true,
    bool? productIdentifierMatches,
    bool? priceVisible,
    bool? paywallRouteOpens,
    bool? purchaseButtonEnabled,
    bool? storeKitSheetAppears,
    bool? proGateUnlocks,
    bool? appRestartKeepsEntitlement,
    bool? restoreAfterReinstallSucceeds,
    bool? calmFallbackOnFailure,
    bool? noCrash,
  }) =>
      RevenueCatLiveProofInput(
        iosApiKeyPresent: iosApiKeyPresent && !diagnostics.apiKeyMissing,
        offeringLoads: journey.offeringLoaded || diagnostics.offeringsLoaded,
        productIdentifierMatches: productIdentifierMatches ??
            (journey.productIds.isNotEmpty
                ? productIdentifiersMatchStoreConfig(journey.productIds)
                : null),
        priceVisible: priceVisible,
        paywallRouteOpens: paywallRouteOpens,
        purchaseButtonEnabled: purchaseButtonEnabled,
        storeKitSheetAppears: storeKitSheetAppears,
        sandboxPurchaseSucceeds:
            journey.purchaseCompleted ? true : null,
        entitlementActiveAfterPurchase: journey.entitlementReceived
            ? true
            : recognizesProEntitlement(journey.entitlementIds)
                ? true
                : null,
        proGateUnlocks: proGateUnlocks,
        appRestartKeepsEntitlement: appRestartKeepsEntitlement,
        restorePurchasesSucceeds:
            journey.restoreCompleted ? true : null,
        restoreAfterReinstallSucceeds: restoreAfterReinstallSucceeds,
        calmFallbackOnFailure: calmFallbackOnFailure,
        noCrash: noCrash,
        activeEntitlementIds: journey.entitlementIds,
      );

  static List<RevenueCatLiveProofCheck> _buildChecks(
    RevenueCatLiveProofInput input,
  ) {
    RevenueCatLiveProofStatus triState(bool? value) {
      if (value == null) return RevenueCatLiveProofStatus.pending;
      return value
          ? RevenueCatLiveProofStatus.pass
          : RevenueCatLiveProofStatus.fail;
    }

    RevenueCatLiveProofStatus gatedStatus({
      required bool prerequisite,
      required bool? value,
    }) {
      if (!prerequisite) return RevenueCatLiveProofStatus.blocked;
      return triState(value);
    }

    final keyOk = input.iosApiKeyPresent;
    final offeringOk = keyOk && input.offeringLoads;
    final productOk = offeringOk && input.productIdentifierMatches == true;
    final priceOk = productOk && input.priceVisible == true;
    final paywallOk = priceOk && input.paywallRouteOpens == true;
    final buttonOk = paywallOk && input.purchaseButtonEnabled == true;
    final purchaseOk = buttonOk && input.sandboxPurchaseSucceeds == true;
    final entitlementOk =
        purchaseOk && input.entitlementActiveAfterPurchase == true;
    final gateOk = entitlementOk && input.proGateUnlocks == true;
    final restartOk = gateOk && input.appRestartKeepsEntitlement == true;
    final restoreOk = restartOk && input.restorePurchasesSucceeds == true;
    final reinstallRestoreOk =
        restoreOk && input.restoreAfterReinstallSucceeds == true;

    return [
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.iosApiKeyPresent,
        label: RevenueCatLiveProofCopy.checkIosApiKeyPresent,
        status: triState(input.iosApiKeyPresent),
        detailLabel: input.iosApiKeyPresent
            ? RevenueCatLiveProofCopy.detailKeyPresent
            : RevenueCatLiveProofCopy.detailKeyMissing,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.offeringLoads,
        label: RevenueCatLiveProofCopy.checkOfferingLoads,
        status: gatedStatus(
          prerequisite: keyOk,
          value: input.offeringLoads,
        ),
        detailLabel: !keyOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.offeringLoads
                ? RevenueCatLiveProofCopy.detailOfferingLoaded
                : RevenueCatLiveProofCopy.detailOfferingMissing,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.productIdentifierMatches,
        label: RevenueCatLiveProofCopy.checkProductIdentifierMatches,
        status: gatedStatus(
          prerequisite: offeringOk,
          value: input.productIdentifierMatches,
        ),
        detailLabel: !offeringOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.productIdentifierMatches == true
                ? RevenueCatLiveProofCopy.detailProductMatch
                : input.productIdentifierMatches == false
                    ? RevenueCatLiveProofCopy.detailProductMismatch
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.priceVisible,
        label: RevenueCatLiveProofCopy.checkPriceVisible,
        status: gatedStatus(
          prerequisite: productOk,
          value: input.priceVisible,
        ),
        detailLabel: !productOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.priceVisible == true
                ? RevenueCatLiveProofCopy.detailPriceVisible
                : input.priceVisible == false
                    ? RevenueCatLiveProofCopy.detailPriceMissing
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.paywallRouteOpens,
        label: RevenueCatLiveProofCopy.checkPaywallRouteOpens,
        status: gatedStatus(
          prerequisite: priceOk,
          value: input.paywallRouteOpens,
        ),
        detailLabel: !priceOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.paywallRouteOpens == true
                ? RevenueCatLiveProofCopy.detailPaywallOpens
                : input.paywallRouteOpens == false
                    ? RevenueCatLiveProofCopy.detailPaywallBlocked
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.purchaseButtonEnabled,
        label: RevenueCatLiveProofCopy.checkPurchaseButtonEnabled,
        status: gatedStatus(
          prerequisite: paywallOk,
          value: input.purchaseButtonEnabled,
        ),
        detailLabel: !paywallOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.purchaseButtonEnabled == true
                ? RevenueCatLiveProofCopy.detailButtonEnabled
                : input.purchaseButtonEnabled == false
                    ? RevenueCatLiveProofCopy.detailButtonDisabled
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.storeKitSheetAppears,
        label: RevenueCatLiveProofCopy.checkStoreKitSheetAppears,
        status: gatedStatus(
          prerequisite: buttonOk,
          value: input.storeKitSheetAppears,
        ),
        detailLabel: !buttonOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.storeKitSheetAppears == true
                ? RevenueCatLiveProofCopy.detailSheetSeen
                : input.storeKitSheetAppears == false
                    ? RevenueCatLiveProofCopy.detailSheetNotSeen
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.sandboxPurchaseSucceeds,
        label: RevenueCatLiveProofCopy.checkSandboxPurchaseSucceeds,
        status: gatedStatus(
          prerequisite: buttonOk,
          value: input.sandboxPurchaseSucceeds,
        ),
        detailLabel: !buttonOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.sandboxPurchaseSucceeds == true
                ? RevenueCatLiveProofCopy.detailPurchaseOk
                : input.sandboxPurchaseSucceeds == false
                    ? RevenueCatLiveProofCopy.detailPurchaseFailed
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.entitlementActiveAfterPurchase,
        label: RevenueCatLiveProofCopy.checkEntitlementActiveAfterPurchase,
        status: gatedStatus(
          prerequisite: purchaseOk,
          value: input.entitlementActiveAfterPurchase,
        ),
        detailLabel: !purchaseOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.entitlementActiveAfterPurchase == true
                ? RevenueCatLiveProofCopy.detailEntitlementOk
                : input.entitlementActiveAfterPurchase == false
                    ? RevenueCatLiveProofCopy.detailEntitlementMissing
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.proGateUnlocks,
        label: RevenueCatLiveProofCopy.checkProGateUnlocks,
        status: gatedStatus(
          prerequisite: entitlementOk,
          value: input.proGateUnlocks,
        ),
        detailLabel: !entitlementOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.proGateUnlocks == true
                ? RevenueCatLiveProofCopy.detailGateUnlocked
                : input.proGateUnlocks == false
                    ? RevenueCatLiveProofCopy.detailGateLocked
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.appRestartKeepsEntitlement,
        label: RevenueCatLiveProofCopy.checkAppRestartKeepsEntitlement,
        status: gatedStatus(
          prerequisite: gateOk,
          value: input.appRestartKeepsEntitlement,
        ),
        detailLabel: !gateOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.appRestartKeepsEntitlement == true
                ? RevenueCatLiveProofCopy.detailRestartOk
                : input.appRestartKeepsEntitlement == false
                    ? RevenueCatLiveProofCopy.detailRestartFailed
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.restorePurchasesSucceeds,
        label: RevenueCatLiveProofCopy.checkRestorePurchasesSucceeds,
        status: gatedStatus(
          prerequisite: restartOk,
          value: input.restorePurchasesSucceeds,
        ),
        detailLabel: !restartOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.restorePurchasesSucceeds == true
                ? RevenueCatLiveProofCopy.detailRestoreOk
                : input.restorePurchasesSucceeds == false
                    ? RevenueCatLiveProofCopy.detailRestoreFailed
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.restoreAfterReinstallSucceeds,
        label: RevenueCatLiveProofCopy.checkRestoreAfterReinstallSucceeds,
        status: gatedStatus(
          prerequisite: restoreOk,
          value: input.restoreAfterReinstallSucceeds,
        ),
        detailLabel: !restoreOk
            ? RevenueCatLiveProofCopy.detailBlocked
            : input.restoreAfterReinstallSucceeds == true
                ? RevenueCatLiveProofCopy.detailReinstallRestoreOk
                : input.restoreAfterReinstallSucceeds == false
                    ? RevenueCatLiveProofCopy.detailReinstallRestoreFailed
                    : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.calmFallbackOnFailure,
        label: RevenueCatLiveProofCopy.checkCalmFallbackOnFailure,
        status: triState(input.calmFallbackOnFailure),
        detailLabel: input.calmFallbackOnFailure == true
            ? RevenueCatLiveProofCopy.detailFallbackOk
            : input.calmFallbackOnFailure == false
                ? RevenueCatLiveProofCopy.detailFallbackFailed
                : RevenueCatLiveProofCopy.detailPending,
      ),
      RevenueCatLiveProofCheck(
        id: RevenueCatLiveProofCheckId.noCrash,
        label: RevenueCatLiveProofCopy.checkNoCrash,
        status: triState(input.noCrash),
        detailLabel: input.noCrash == true
            ? RevenueCatLiveProofCopy.detailNoCrashOk
            : input.noCrash == false
                ? RevenueCatLiveProofCopy.detailNoCrashFailed
                : RevenueCatLiveProofCopy.detailPending,
      ),
    ];
  }

  static RevenueCatLiveProofDecision _resolveDecision(
    RevenueCatLiveProofInput input,
    List<RevenueCatLiveProofCheck> checks,
  ) {
    if (!input.iosApiKeyPresent &&
        input.noCrash == true &&
        input.calmFallbackOnFailure == true &&
        checks
            .where(
              (check) =>
                  check.id != RevenueCatLiveProofCheckId.noCrash &&
                  check.id != RevenueCatLiveProofCheckId.calmFallbackOnFailure,
            )
            .every(
              (check) =>
                  check.status == RevenueCatLiveProofStatus.blocked ||
                  check.id == RevenueCatLiveProofCheckId.iosApiKeyPresent,
            )) {
      return RevenueCatLiveProofDecision.safeInternalState;
    }

    if (checks.any(
      (check) => check.status == RevenueCatLiveProofStatus.fail,
    )) {
      return RevenueCatLiveProofDecision.blocked;
    }

    if (reinstallRestoreOkChecks(checks)) {
      return RevenueCatLiveProofDecision.proved;
    }

    if (checks.every(
      (check) =>
          check.status == RevenueCatLiveProofStatus.pass ||
          check.status == RevenueCatLiveProofStatus.skipped,
    )) {
      return RevenueCatLiveProofDecision.proved;
    }

    return RevenueCatLiveProofDecision.manualRequired;
  }

  static bool reinstallRestoreOkChecks(List<RevenueCatLiveProofCheck> checks) {
    final required = {
      RevenueCatLiveProofCheckId.iosApiKeyPresent,
      RevenueCatLiveProofCheckId.offeringLoads,
      RevenueCatLiveProofCheckId.productIdentifierMatches,
      RevenueCatLiveProofCheckId.priceVisible,
      RevenueCatLiveProofCheckId.paywallRouteOpens,
      RevenueCatLiveProofCheckId.purchaseButtonEnabled,
      RevenueCatLiveProofCheckId.storeKitSheetAppears,
      RevenueCatLiveProofCheckId.sandboxPurchaseSucceeds,
      RevenueCatLiveProofCheckId.entitlementActiveAfterPurchase,
      RevenueCatLiveProofCheckId.proGateUnlocks,
      RevenueCatLiveProofCheckId.appRestartKeepsEntitlement,
      RevenueCatLiveProofCheckId.restorePurchasesSucceeds,
      RevenueCatLiveProofCheckId.restoreAfterReinstallSucceeds,
      RevenueCatLiveProofCheckId.calmFallbackOnFailure,
      RevenueCatLiveProofCheckId.noCrash,
    };

    return checks
        .where((check) => required.contains(check.id))
        .every((check) => check.status == RevenueCatLiveProofStatus.pass);
  }

  static String _messageFor(RevenueCatLiveProofDecision decision) =>
      switch (decision) {
        RevenueCatLiveProofDecision.proved => RevenueCatLiveProofCopy.provedLine,
        RevenueCatLiveProofDecision.manualRequired =>
          RevenueCatLiveProofCopy.manualRequiredLine,
        RevenueCatLiveProofDecision.safeInternalState =>
          RevenueCatLiveProofCopy.safeInternalStateLine,
        RevenueCatLiveProofDecision.blocked =>
          RevenueCatLiveProofCopy.blockedLine,
      };
}

class RevenueCatLiveProofInput {
  const RevenueCatLiveProofInput({
    this.iosApiKeyPresent = false,
    this.offeringLoads = false,
    this.productIdentifierMatches,
    this.priceVisible,
    this.paywallRouteOpens,
    this.purchaseButtonEnabled,
    this.storeKitSheetAppears,
    this.sandboxPurchaseSucceeds,
    this.entitlementActiveAfterPurchase,
    this.proGateUnlocks,
    this.appRestartKeepsEntitlement,
    this.restorePurchasesSucceeds,
    this.restoreAfterReinstallSucceeds,
    this.calmFallbackOnFailure,
    this.noCrash,
    this.activeEntitlementIds = const [],
  });

  final bool iosApiKeyPresent;
  final bool offeringLoads;
  final bool? productIdentifierMatches;
  final bool? priceVisible;
  final bool? paywallRouteOpens;
  final bool? purchaseButtonEnabled;
  final bool? storeKitSheetAppears;
  final bool? sandboxPurchaseSucceeds;
  final bool? entitlementActiveAfterPurchase;
  final bool? proGateUnlocks;
  final bool? appRestartKeepsEntitlement;
  final bool? restorePurchasesSucceeds;
  final bool? restoreAfterReinstallSucceeds;
  final bool? calmFallbackOnFailure;
  final bool? noCrash;
  final List<String> activeEntitlementIds;
}

class RevenueCatLiveProofCheck {
  const RevenueCatLiveProofCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final RevenueCatLiveProofCheckId id;
  final String label;
  final RevenueCatLiveProofStatus status;
  final String detailLabel;
}

class RevenueCatLiveProofResult {
  const RevenueCatLiveProofResult({
    required this.decision,
    required this.message,
    required this.checks,
    required this.earliestBlocker,
    required this.allPassed,
  });

  final RevenueCatLiveProofDecision decision;
  final String message;
  final List<RevenueCatLiveProofCheck> checks;
  final RevenueCatLiveProofCheckId? earliestBlocker;
  final bool allPassed;
}

class RevenueCatLiveProofReport {
  const RevenueCatLiveProofReport({
    required this.headline,
    required this.body,
    required this.manualNote,
    required this.guardrail,
    required this.scopeLine,
    required this.result,
  });

  final String headline;
  final String body;
  final String manualNote;
  final String guardrail;
  final String scopeLine;
  final RevenueCatLiveProofResult result;

  List<String> get allDisplayedText => [
        headline,
        body,
        manualNote,
        guardrail,
        scopeLine,
        for (final check in result.checks) ...[
          check.label,
          check.detailLabel,
          check.status.label,
        ],
        result.message,
      ];
}
