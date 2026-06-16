import { readReleaseEvidenceRecords } from "@/lib/mobile/release-evidence";
import { readFlutter } from "@/lib/mobile/flutter-repo";
import type { MobilePaywallAudit, PaywallAuditCheck } from "@/types/mobile-first-class";

/** Native paywall / billing structural audit (RevenueCat, restore, entitlements). */
export function buildMobilePaywallAudit(): MobilePaywallAudit {
  const pubspec = readFlutter("pubspec.yaml");
  const pricing = readFlutter("lib/screens/pricing_screen.dart");
  const billing = readFlutter("lib/billing/billing_service.dart");
  const cache = readFlutter("lib/storage/entitlement_cache.dart");
  const evidence = readReleaseEvidenceRecords();

  const hasRevenueCat = pubspec.includes("purchases_flutter");
  const hasRestoreUi =
    /restorePurchases|Restore purchases|restore purchases/i.test(pricing) ||
    readFlutter("lib/billing/billing_service.dart").includes("restore");
  const revenuecatEvidence = evidence.find((e) => e.id === "revenuecat_store_tested");
  const restoreEvidence = evidence.find((e) => e.id === "restore_purchases_tested");

  const checks: PaywallAuditCheck[] = [
    {
      id: "revenuecat",
      label: "RevenueCat",
      passed: hasRevenueCat && revenuecatEvidence?.passed === true,
      note: hasRevenueCat
        ? revenuecatEvidence?.passed
          ? "purchases_flutter + revenuecat_store_tested evidence"
          : "SDK present — commit mobile/evidence/revenuecat_store_tested.json"
        : "Not in pubspec — Stripe browser checkout only",
    },
    {
      id: "restore_purchases",
      label: "Restore purchases",
      passed: hasRestoreUi && restoreEvidence?.passed === true,
      note: hasRestoreUi
        ? restoreEvidence?.passed
          ? "Restore UI + restore_purchases_tested evidence"
          : "Restore UI referenced — evidence file required"
        : "No restore flow in Flutter app",
    },
    {
      id: "subscription_state",
      label: "Subscription state",
      passed:
        billing.includes("getEntitlements") &&
        readFlutter("lib/api/api_client.dart").includes("getEntitlements"),
      note: "Server entitlements via API + BillingService",
    },
    {
      id: "entitlement_refresh",
      label: "Entitlement refresh",
      passed: billing.includes("forceRefresh"),
      note: billing.includes("forceRefresh")
        ? "loadEntitlements({ forceRefresh: true })"
        : "No forceRefresh on billing service",
    },
    {
      id: "offline_purchase_recovery",
      label: "Offline purchase recovery",
      passed: cache.includes("EntitlementCache") && billing.includes("_cache"),
      note: cache.includes("EntitlementCache")
        ? "Cached entitlements survive offline — store restore still required for IAP"
        : "No entitlement cache",
    },
  ];

  const nativeStoreReady = checks.find((c) => c.id === "revenuecat")?.passed === true;
  const purchaseRecoveryComplete =
    checks.find((c) => c.id === "restore_purchases")?.passed === true &&
    checks.find((c) => c.id === "offline_purchase_recovery")?.passed === true;

  return {
    generatedAt: new Date().toISOString(),
    checks,
    nativeStoreReady,
    purchaseRecoveryComplete,
  };
}
