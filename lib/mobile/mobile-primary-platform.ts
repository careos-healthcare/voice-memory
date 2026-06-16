import { readFlutter } from "@/lib/mobile/flutter-repo";
import { buildMobileJourneyAudit } from "@/lib/mobile/mobile-journey-audit";
import {
  isCommercialEvidencePassing,
  listCommercialEvidenceIds,
} from "@/lib/mobile/commercial-evidence";
import type {
  MobilePrimaryPlatformReport,
  MobilePrimaryPlatformVerdict,
} from "@/types/mobile-commercial-readiness";

const REQUIRED_EVIDENCE = [
  "ios_signing_tested",
  "android_signing_tested",
  "testflight_tested",
  "play_internal_tested",
  "revenuecat_store_tested",
  "restore_purchases_tested",
  "purchase_journey_tested",
  "offline_sync_tested",
  "native_push_verification",
] as const;

export function collectStructuralCommercialFailures(): string[] {
  const failures: string[] = [];
  const pubspec = readFlutter("pubspec.yaml");
  const router = readFlutter("lib/router/app_router.dart");
  const pricing = readFlutter("lib/screens/pricing_screen.dart");
  const paywall = readFlutter("lib/widgets/value_moment_paywall.dart");

  if (!pubspec.includes("purchases_flutter")) {
    failures.push("RevenueCat missing — purchases_flutter not in pubspec");
  }
  if (!readFlutter("lib/billing/revenuecat_service.dart").includes("RevenueCatService")) {
    failures.push("RevenueCat missing — revenuecat_service.dart");
  }
  if (!router.includes("MobileSubscriptionScreen")) {
    failures.push("MobileSubscriptionScreen not wired in app_router");
  }
  if (!router.includes("RestorePurchasesScreen")) {
    failures.push("RestorePurchasesScreen not wired in app_router");
  }
  if (pricing.includes("launchUrl") && pricing.includes("createCheckoutSession")) {
    failures.push("Browser Stripe checkout still present on pricing screen");
  }
  if (paywall.includes("createCheckoutSession")) {
    failures.push("Browser Stripe checkout still present in value_moment_paywall");
  }

  return failures;
}

export function buildMobilePrimaryPlatformReport(): MobilePrimaryPlatformReport {
  const reasons: string[] = [];
  const evidencePassing: string[] = [];
  const evidenceFailing: string[] = [];

  for (const id of REQUIRED_EVIDENCE) {
    if (isCommercialEvidencePassing(id)) {
      evidencePassing.push(id);
    } else {
      evidenceFailing.push(id);
      reasons.push(`Evidence not passing: ${id}`);
    }
  }

  const structuralFailures = collectStructuralCommercialFailures();
  for (const f of structuralFailures) {
    reasons.push(f);
  }

  const journey = buildMobileJourneyAudit();
  const journeyCompleteOnDevice = journey.completeWithoutWeb;
  if (!journeyCompleteOnDevice) {
    reasons.push(
      `On-device journey incomplete: ${journey.failingStepIds.join(", ")}`,
    );
  }

  const verdict: MobilePrimaryPlatformVerdict =
    reasons.length === 0 && journeyCompleteOnDevice
      ? "PRIMARY_PLATFORM"
      : "COMPANION_APP";

  return {
    generatedAt: new Date().toISOString(),
    verdict,
    verdictLabel: "MOBILE_PRIMARY_PLATFORM_VERDICT",
    reasons,
    evidencePassing,
    evidenceFailing,
    structuralFailures,
    journeyCompleteOnDevice,
  };
}

export function collectMobilePrimaryProductFailures(): string[] {
  const report = buildMobilePrimaryPlatformReport();
  const failures = [...report.structuralFailures, ...report.reasons];

  if (report.verdict === "COMPANION_APP") {
    failures.push(
      `MOBILE_PRIMARY_PLATFORM_VERDICT: ${report.verdict}`,
    );
  }

  return [...new Set(failures)];
}

export { listCommercialEvidenceIds };
