import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/revenuecat_diagnostics.dart';
import 'package:archiveme_mobile/billing/revenuecat_purchase_journey.dart';
import 'package:archiveme_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof_copy.dart';

/// RevenueCat sandbox proof — ten-step iOS purchase/restore/entitlement checklist.
abstract final class RevenueCatSandboxProof {
  RevenueCatSandboxProof._();

  static RevenueCatSandboxProofResult build(RevenueCatSandboxProofInput input) {
    final checks = _buildChecks(input);
    final decision = _resolveDecision(input, checks);
    final message = _messageFor(decision);
    final earliestBlocker = checks
        .where((check) => check.status == RevenueCatSandboxProofStatus.fail)
        .map((check) => check.id)
        .firstOrNull;

    return RevenueCatSandboxProofResult(
      decision: decision,
      message: message,
      checks: checks,
      earliestBlocker: earliestBlocker,
      allPassed: checks.every(
        (check) =>
            check.status == RevenueCatSandboxProofStatus.pass ||
            check.status == RevenueCatSandboxProofStatus.skipped,
      ),
    );
  }

  static RevenueCatSandboxProofReport report(
    RevenueCatSandboxProofResult result,
  ) => RevenueCatSandboxProofReport(
    headline: RevenueCatSandboxProofCopy.headline,
    body: RevenueCatSandboxProofCopy.body,
    manualNote: RevenueCatSandboxProofCopy.manualNote,
    provedLine: RevenueCatSandboxProofCopy.provedLine,
    manualRequiredLine: RevenueCatSandboxProofCopy.manualRequiredLine,
    fallbackVerifiedLine: RevenueCatSandboxProofCopy.fallbackVerifiedLine,
    blockedLine: RevenueCatSandboxProofCopy.blockedLine,
    guardrail: RevenueCatSandboxProofCopy.guardrail,
    result: result,
  );

  static RevenueCatSandboxProofInput fromDiagnostics(
    RevenueCatDiagnostics diagnostics, {
    bool productTitlePriceVisible = false,
    bool? storeKitSheetAppears,
    bool? sandboxPurchaseSucceeds,
    bool? proEntitlementActive,
    bool? proGateUnlocks,
    bool? restorePurchasesSucceeds,
    bool? entitlementPersistsAfterRestart,
    bool? missingKeyNoCrash,
    List<String> activeEntitlementIds = const [],
  }) => RevenueCatSandboxProofInput(
    iosApiKeyPresent:
        diagnostics.revenueCatConfigured && !diagnostics.apiKeyMissing,
    offeringLoads: diagnostics.offeringsLoaded,
    productTitlePriceVisible: productTitlePriceVisible,
    storeKitSheetAppears: storeKitSheetAppears,
    sandboxPurchaseSucceeds: sandboxPurchaseSucceeds,
    proEntitlementActive:
        proEntitlementActive ??
        (recognizesProEntitlement(activeEntitlementIds) ? true : null),
    proGateUnlocks: proGateUnlocks,
    restorePurchasesSucceeds: restorePurchasesSucceeds,
    entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    missingKeyNoCrash: missingKeyNoCrash,
    activeEntitlementIds: activeEntitlementIds,
  );

  static RevenueCatSandboxProofInput fromPurchaseJourney(
    RevenueCatPurchaseJourney journey, {
    required RevenueCatDiagnostics diagnostics,
    bool iosApiKeyPresent = true,
    bool productTitlePriceVisible = false,
    bool? storeKitSheetAppears,
    bool? proGateUnlocks,
    bool? entitlementPersistsAfterRestart,
    bool? missingKeyNoCrash,
  }) => RevenueCatSandboxProofInput(
    iosApiKeyPresent: iosApiKeyPresent && !diagnostics.apiKeyMissing,
    offeringLoads: journey.offeringLoaded || diagnostics.offeringsLoaded,
    productTitlePriceVisible: productTitlePriceVisible,
    storeKitSheetAppears: storeKitSheetAppears,
    sandboxPurchaseSucceeds: journey.purchaseCompleted ? true : null,
    proEntitlementActive: journey.entitlementReceived
        ? true
        : recognizesProEntitlement(journey.entitlementIds)
        ? true
        : null,
    proGateUnlocks: proGateUnlocks,
    restorePurchasesSucceeds: journey.restoreCompleted ? true : null,
    entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    missingKeyNoCrash: missingKeyNoCrash,
    activeEntitlementIds: journey.entitlementIds,
  );

  static bool recognizesProEntitlement(List<String> entitlementIds) {
    for (final id in entitlementIds) {
      if (ArchiveLoopEntitlementIds.revenueCatEntitlementIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  static List<RevenueCatSandboxProofCheck> _buildChecks(
    RevenueCatSandboxProofInput input,
  ) {
    RevenueCatSandboxProofStatus triState(bool? value) {
      if (value == null) return RevenueCatSandboxProofStatus.pending;
      return value
          ? RevenueCatSandboxProofStatus.pass
          : RevenueCatSandboxProofStatus.fail;
    }

    RevenueCatSandboxProofStatus gatedStatus({
      required bool prerequisite,
      required bool? value,
    }) {
      if (!prerequisite) return RevenueCatSandboxProofStatus.blocked;
      return triState(value);
    }

    final keyOk = input.iosApiKeyPresent;
    final offeringOk = keyOk && input.offeringLoads;
    final productOk = offeringOk && input.productTitlePriceVisible;
    final purchaseOk = productOk && input.sandboxPurchaseSucceeds == true;
    final entitlementOk = purchaseOk && input.proEntitlementActive == true;
    final restoreOk = entitlementOk && input.restorePurchasesSucceeds == true;

    return [
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.iosApiKeyPresent,
        label: RevenueCatSandboxProofCopy.checkIosApiKeyPresent,
        status: triState(input.iosApiKeyPresent),
        detailLabel: input.iosApiKeyPresent
            ? RevenueCatSandboxProofCopy.detailKeyPresent
            : RevenueCatSandboxProofCopy.detailKeyMissing,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.offeringLoads,
        label: RevenueCatSandboxProofCopy.checkOfferingLoads,
        status: gatedStatus(prerequisite: keyOk, value: input.offeringLoads),
        detailLabel: !keyOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.offeringLoads
            ? RevenueCatSandboxProofCopy.detailOfferingLoaded
            : RevenueCatSandboxProofCopy.detailOfferingMissing,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.productTitlePriceVisible,
        label: RevenueCatSandboxProofCopy.checkProductTitlePriceVisible,
        status: gatedStatus(
          prerequisite: offeringOk,
          value: input.productTitlePriceVisible,
        ),
        detailLabel: !offeringOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.productTitlePriceVisible
            ? RevenueCatSandboxProofCopy.detailProductVisible
            : RevenueCatSandboxProofCopy.detailProductMissing,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.storeKitSheetAppears,
        label: RevenueCatSandboxProofCopy.checkStoreKitSheetAppears,
        status: gatedStatus(
          prerequisite: productOk,
          value: input.storeKitSheetAppears,
        ),
        detailLabel: !productOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.storeKitSheetAppears == true
            ? RevenueCatSandboxProofCopy.detailSheetSeen
            : input.storeKitSheetAppears == false
            ? RevenueCatSandboxProofCopy.detailSheetNotSeen
            : RevenueCatSandboxProofCopy.detailPending,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.sandboxPurchaseSucceeds,
        label: RevenueCatSandboxProofCopy.checkSandboxPurchaseSucceeds,
        status: gatedStatus(
          prerequisite: productOk,
          value: input.sandboxPurchaseSucceeds,
        ),
        detailLabel: !productOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.sandboxPurchaseSucceeds == true
            ? RevenueCatSandboxProofCopy.detailPurchaseOk
            : input.sandboxPurchaseSucceeds == false
            ? RevenueCatSandboxProofCopy.detailPurchaseFailed
            : RevenueCatSandboxProofCopy.detailPending,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.proEntitlementActive,
        label: RevenueCatSandboxProofCopy.checkProEntitlementActive,
        status: gatedStatus(
          prerequisite: purchaseOk,
          value: input.proEntitlementActive,
        ),
        detailLabel: !purchaseOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.proEntitlementActive == true
            ? RevenueCatSandboxProofCopy.detailEntitlementOk
            : input.proEntitlementActive == false
            ? RevenueCatSandboxProofCopy.detailEntitlementMissing
            : RevenueCatSandboxProofCopy.detailPending,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.proGateUnlocks,
        label: RevenueCatSandboxProofCopy.checkProGateUnlocks,
        status: gatedStatus(
          prerequisite: entitlementOk,
          value: input.proGateUnlocks,
        ),
        detailLabel: !entitlementOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.proGateUnlocks == true
            ? RevenueCatSandboxProofCopy.detailGateUnlocked
            : input.proGateUnlocks == false
            ? RevenueCatSandboxProofCopy.detailGateLocked
            : RevenueCatSandboxProofCopy.detailPending,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.restorePurchasesSucceeds,
        label: RevenueCatSandboxProofCopy.checkRestorePurchasesSucceeds,
        status: gatedStatus(
          prerequisite: entitlementOk,
          value: input.restorePurchasesSucceeds,
        ),
        detailLabel: !entitlementOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.restorePurchasesSucceeds == true
            ? RevenueCatSandboxProofCopy.detailRestoreOk
            : input.restorePurchasesSucceeds == false
            ? RevenueCatSandboxProofCopy.detailRestoreFailed
            : RevenueCatSandboxProofCopy.detailPending,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.entitlementPersistsAfterRestart,
        label: RevenueCatSandboxProofCopy.checkEntitlementPersistsAfterRestart,
        status: gatedStatus(
          prerequisite: restoreOk,
          value: input.entitlementPersistsAfterRestart,
        ),
        detailLabel: !restoreOk
            ? RevenueCatSandboxProofCopy.detailBlocked
            : input.entitlementPersistsAfterRestart == true
            ? RevenueCatSandboxProofCopy.detailPersistOk
            : input.entitlementPersistsAfterRestart == false
            ? RevenueCatSandboxProofCopy.detailPersistFailed
            : RevenueCatSandboxProofCopy.detailPending,
      ),
      RevenueCatSandboxProofCheck(
        id: RevenueCatSandboxProofCheckId.missingKeyNoCrash,
        label: RevenueCatSandboxProofCopy.checkMissingKeyNoCrash,
        status: input.iosApiKeyPresent
            ? RevenueCatSandboxProofStatus.skipped
            : triState(input.missingKeyNoCrash),
        detailLabel: input.iosApiKeyPresent
            ? RevenueCatSandboxProofCopy.detailSkipped
            : input.missingKeyNoCrash == true
            ? RevenueCatSandboxProofCopy.detailNoCrashOk
            : input.missingKeyNoCrash == false
            ? RevenueCatSandboxProofCopy.detailNoCrashFailed
            : RevenueCatSandboxProofCopy.detailPending,
      ),
    ];
  }

  static RevenueCatSandboxProofDecision _resolveDecision(
    RevenueCatSandboxProofInput input,
    List<RevenueCatSandboxProofCheck> checks,
  ) {
    if (!input.iosApiKeyPresent &&
        input.missingKeyNoCrash == true &&
        checks
            .where(
              (check) =>
                  check.id != RevenueCatSandboxProofCheckId.missingKeyNoCrash,
            )
            .every(
              (check) =>
                  check.status == RevenueCatSandboxProofStatus.blocked ||
                  check.status == RevenueCatSandboxProofStatus.skipped ||
                  check.id == RevenueCatSandboxProofCheckId.iosApiKeyPresent,
            )) {
      return RevenueCatSandboxProofDecision.fallbackVerified;
    }

    if (checks.any(
      (check) => check.status == RevenueCatSandboxProofStatus.fail,
    )) {
      return RevenueCatSandboxProofDecision.blocked;
    }

    if (checks.every(
      (check) =>
          check.status == RevenueCatSandboxProofStatus.pass ||
          check.status == RevenueCatSandboxProofStatus.skipped,
    )) {
      return RevenueCatSandboxProofDecision.proved;
    }

    return RevenueCatSandboxProofDecision.manualRequired;
  }

  static String _messageFor(RevenueCatSandboxProofDecision decision) =>
      switch (decision) {
        RevenueCatSandboxProofDecision.proved =>
          RevenueCatSandboxProofCopy.provedLine,
        RevenueCatSandboxProofDecision.manualRequired =>
          RevenueCatSandboxProofCopy.manualRequiredLine,
        RevenueCatSandboxProofDecision.fallbackVerified =>
          RevenueCatSandboxProofCopy.fallbackVerifiedLine,
        RevenueCatSandboxProofDecision.blocked =>
          RevenueCatSandboxProofCopy.blockedLine,
      };
}

enum RevenueCatSandboxProofCheckId {
  iosApiKeyPresent,
  offeringLoads,
  productTitlePriceVisible,
  storeKitSheetAppears,
  sandboxPurchaseSucceeds,
  proEntitlementActive,
  proGateUnlocks,
  restorePurchasesSucceeds,
  entitlementPersistsAfterRestart,
  missingKeyNoCrash,
}

enum RevenueCatSandboxProofStatus {
  pass,
  fail,
  pending,
  blocked,
  skipped;

  String get label => switch (this) {
    RevenueCatSandboxProofStatus.pass => RevenueCatSandboxProofCopy.statusPass,
    RevenueCatSandboxProofStatus.fail => RevenueCatSandboxProofCopy.statusFail,
    RevenueCatSandboxProofStatus.pending =>
      RevenueCatSandboxProofCopy.statusPending,
    RevenueCatSandboxProofStatus.blocked =>
      RevenueCatSandboxProofCopy.statusBlocked,
    RevenueCatSandboxProofStatus.skipped =>
      RevenueCatSandboxProofCopy.statusSkipped,
  };
}

enum RevenueCatSandboxProofDecision {
  proved,
  manualRequired,
  fallbackVerified,
  blocked,
}

class RevenueCatSandboxProofInput {
  const RevenueCatSandboxProofInput({
    this.iosApiKeyPresent = false,
    this.offeringLoads = false,
    this.productTitlePriceVisible = false,
    this.storeKitSheetAppears,
    this.sandboxPurchaseSucceeds,
    this.proEntitlementActive,
    this.proGateUnlocks,
    this.restorePurchasesSucceeds,
    this.entitlementPersistsAfterRestart,
    this.missingKeyNoCrash,
    this.activeEntitlementIds = const [],
  });

  final bool iosApiKeyPresent;
  final bool offeringLoads;
  final bool productTitlePriceVisible;
  final bool? storeKitSheetAppears;
  final bool? sandboxPurchaseSucceeds;
  final bool? proEntitlementActive;
  final bool? proGateUnlocks;
  final bool? restorePurchasesSucceeds;
  final bool? entitlementPersistsAfterRestart;
  final bool? missingKeyNoCrash;
  final List<String> activeEntitlementIds;
}

class RevenueCatSandboxProofCheck {
  const RevenueCatSandboxProofCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final RevenueCatSandboxProofCheckId id;
  final String label;
  final RevenueCatSandboxProofStatus status;
  final String detailLabel;
}

class RevenueCatSandboxProofResult {
  const RevenueCatSandboxProofResult({
    required this.decision,
    required this.message,
    required this.checks,
    required this.earliestBlocker,
    required this.allPassed,
  });

  final RevenueCatSandboxProofDecision decision;
  final String message;
  final List<RevenueCatSandboxProofCheck> checks;
  final RevenueCatSandboxProofCheckId? earliestBlocker;
  final bool allPassed;
}

class RevenueCatSandboxProofReport {
  const RevenueCatSandboxProofReport({
    required this.headline,
    required this.body,
    required this.manualNote,
    required this.provedLine,
    required this.manualRequiredLine,
    required this.fallbackVerifiedLine,
    required this.blockedLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String manualNote;
  final String provedLine;
  final String manualRequiredLine;
  final String fallbackVerifiedLine;
  final String blockedLine;
  final String guardrail;
  final RevenueCatSandboxProofResult result;

  List<String> get allDisplayedText => [
    headline,
    body,
    manualNote,
    provedLine,
    manualRequiredLine,
    fallbackVerifiedLine,
    blockedLine,
    for (final check in result.checks) ...[
      check.label,
      check.detailLabel,
      check.status.label,
    ],
    result.message,
  ];
}