import 'package:archiveme_mobile/billing/revenuecat_diagnostics.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v2_copy.dart';

/// Pro access enforcement audit v2 — developer dashboard wiring + CI bundle.
abstract final class ProAccessEnforcementAuditV2 {
  ProAccessEnforcementAuditV2._();

  static const ciTestBundle = [
    'test/pro_access_enforcement_audit_test.dart',
    'test/store_readiness_single_source_test.dart',
    'test/revenuecat_sandbox_proof_test.dart',
  ];

  static ProAccessEnforcementDashboard buildFromLocalSignals(
    ProAccessEnforcementLocalSignals signals,
  ) {
    final auditInput = toAuditInput(signals);
    final result = ProAccessEnforcementAudit.build(auditInput);
    final rows = [
      for (final item in result.items)
        ProAccessEnforcementDashboardRow(
          id: item.id,
          label: item.label,
          classification: item.classification,
          classificationLabel: item.classificationLabel,
          detailLabel: item.detailLabel,
        ),
    ];

    return ProAccessEnforcementDashboard(
      headline: ProAccessEnforcementAuditV2Copy.headline,
      body: ProAccessEnforcementAuditV2Copy.body,
      guardrail: ProAccessEnforcementAuditV2Copy.guardrail,
      decision: result.decision,
      decisionLabel: decisionLabelFor(result.decision),
      message: result.message,
      rows: rows,
      productionBlockerCount: rows
          .where(
            (row) =>
                row.classification ==
                ProAccessEnforcementClassification.productionBlocker,
          )
          .length,
      documentedGapCount: rows
          .where(
            (row) =>
                row.classification ==
                    ProAccessEnforcementClassification.notEnforcedYet ||
                row.classification ==
                    ProAccessEnforcementClassification.acceptableForTestFlight,
          )
          .length,
      appLockEnabled: signals.appLockEnabled,
      proEntitlementActive: signals.proEntitlementActive,
      revenueCatConfigured: auditInput.revenueCatConfigured,
    );
  }

  static ProAccessEnforcementAuditInput toAuditInput(
    ProAccessEnforcementLocalSignals signals,
  ) {
    final revenueCatConfigured =
        signals.revenueCatConfigured && !signals.revenueCatApiKeyMissing;
    final staleCachedProRisk =
        signals.cachedProOnDisk &&
        revenueCatConfigured &&
        !signals.proEntitlementActive;

    return ProAccessEnforcementAuditInput(
      revenueCatConfigured: revenueCatConfigured,
      proEntitlementReadable:
          revenueCatConfigured &&
          signals.proStateReadable &&
          signals.productsLoaded,
      restorePurchasesReachable: signals.restorePurchasesReachable,
      restoreNoCrashVerified: signals.restoreNoCrashVerified,
      localCachePreventsStalePro: !staleCachedProRisk,
      entitlementPersistsAfterRestart:
          signals.entitlementPersistsAfterRestart ||
          (signals.cachedProOnDisk && signals.proEntitlementActive),
      revenueCatLinkedToAccount: signals.revenueCatLinkedToAccount,
      serverSideEntitlementCheckPresent: signals.backendConfigured,
      privacyLockIndependentOfPro: signals.privacyLockIndependentOfPro,
      deviceSharingPrevented: signals.deviceSharingPrevented,
    );
  }

  static ProAccessEnforcementLocalSignals fromDiagnostics(
    RevenueCatDiagnostics diagnostics, {
    bool proEntitlementActive = false,
    bool proStateReadable = false,
    bool cachedProOnDisk = false,
    bool restorePurchasesReachable = true,
    bool restoreNoCrashVerified = true,
    bool entitlementPersistsAfterRestart = false,
    bool revenueCatLinkedToAccount = false,
    bool backendConfigured = false,
    bool appLockEnabled = false,
    bool privacyLockIndependentOfPro = true,
    bool deviceSharingPrevented = false,
  }) => ProAccessEnforcementLocalSignals(
    revenueCatConfigured: diagnostics.revenueCatConfigured,
    revenueCatApiKeyMissing: diagnostics.apiKeyMissing,
    productsLoaded: diagnostics.offeringsLoaded && diagnostics.packageCount > 0,
    proStateReadable: proStateReadable || diagnostics.revenueCatConfigured,
    proEntitlementActive: proEntitlementActive,
    cachedProOnDisk: cachedProOnDisk,
    restorePurchasesReachable: restorePurchasesReachable,
    restoreNoCrashVerified: restoreNoCrashVerified,
    entitlementPersistsAfterRestart: entitlementPersistsAfterRestart,
    revenueCatLinkedToAccount: revenueCatLinkedToAccount,
    backendConfigured: backendConfigured,
    appLockEnabled: appLockEnabled,
    privacyLockIndependentOfPro: privacyLockIndependentOfPro,
    deviceSharingPrevented: deviceSharingPrevented,
  );

  static String decisionLabelFor(ProAccessEnforcementAuditDecision decision) =>
      switch (decision) {
        ProAccessEnforcementAuditDecision.testFlightAcceptable =>
          ProAccessEnforcementAuditV2Copy.decisionTestFlightAcceptable,
        ProAccessEnforcementAuditDecision.productionBlocked =>
          ProAccessEnforcementAuditV2Copy.decisionProductionBlocked,
        ProAccessEnforcementAuditDecision.enforcementDocumented =>
          ProAccessEnforcementAuditV2Copy.decisionEnforcementDocumented,
      };
}

class ProAccessEnforcementLocalSignals {
  const ProAccessEnforcementLocalSignals({
    this.revenueCatConfigured = false,
    this.revenueCatApiKeyMissing = true,
    this.productsLoaded = false,
    this.proStateReadable = false,
    this.proEntitlementActive = false,
    this.cachedProOnDisk = false,
    this.restorePurchasesReachable = true,
    this.restoreNoCrashVerified = true,
    this.entitlementPersistsAfterRestart = false,
    this.revenueCatLinkedToAccount = false,
    this.backendConfigured = false,
    this.appLockEnabled = false,
    this.privacyLockIndependentOfPro = true,
    this.deviceSharingPrevented = false,
  });

  final bool revenueCatConfigured;
  final bool revenueCatApiKeyMissing;
  final bool productsLoaded;
  final bool proStateReadable;
  final bool proEntitlementActive;
  final bool cachedProOnDisk;
  final bool restorePurchasesReachable;
  final bool restoreNoCrashVerified;
  final bool entitlementPersistsAfterRestart;
  final bool revenueCatLinkedToAccount;
  final bool backendConfigured;
  final bool appLockEnabled;
  final bool privacyLockIndependentOfPro;
  final bool deviceSharingPrevented;
}

class ProAccessEnforcementDashboardRow {
  const ProAccessEnforcementDashboardRow({
    required this.id,
    required this.label,
    required this.classification,
    required this.classificationLabel,
    required this.detailLabel,
  });

  final ProAccessEnforcementAuditItemId id;
  final String label;
  final ProAccessEnforcementClassification classification;
  final String classificationLabel;
  final String detailLabel;
}

class ProAccessEnforcementDashboard {
  const ProAccessEnforcementDashboard({
    required this.headline,
    required this.body,
    required this.guardrail,
    required this.decision,
    required this.decisionLabel,
    required this.message,
    required this.rows,
    required this.productionBlockerCount,
    required this.documentedGapCount,
    required this.appLockEnabled,
    required this.proEntitlementActive,
    required this.revenueCatConfigured,
  });

  final String headline;
  final String body;
  final String guardrail;
  final ProAccessEnforcementAuditDecision decision;
  final String decisionLabel;
  final String message;
  final List<ProAccessEnforcementDashboardRow> rows;
  final int productionBlockerCount;
  final int documentedGapCount;
  final bool appLockEnabled;
  final bool proEntitlementActive;
  final bool revenueCatConfigured;
}