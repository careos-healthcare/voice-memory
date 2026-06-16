import { buildMobileArchiveReview } from "@/lib/mobile/mobile-archive-review";
import { buildMobileJourneyAudit } from "@/lib/mobile/mobile-journey-audit";
import { auditMobileIndependence } from "@/lib/mobile/mobile-independence";
import {
  collectMobilePrimaryProductFailures,
  buildMobilePrimaryPlatformReport,
} from "@/lib/mobile/mobile-primary-platform";
import { buildMobileParityReport } from "@/lib/mobile/mobile-parity-report";
import { buildMobilePaywallAudit } from "@/lib/mobile/mobile-paywall-audit";
import { buildMobileProductionReadinessReport } from "@/lib/mobile/mobile-production-readiness";
import type {
  FounderPlatformVerdict,
  MobileDistributionPillar,
  MobileFirstClassReport,
} from "@/types/mobile-first-class";

function pillarFromProduction(
  label: string,
  key: "productReadiness" | "storeReadiness" | "distributionReadiness",
): MobileDistributionPillar {
  const report = buildMobileProductionReadinessReport();
  const p = report[key];
  return {
    label,
    status: p.status,
    passing: p.passing,
    total: p.total,
    summary: p.summary,
  };
}

function computeVerdict(
  _report: Omit<MobileFirstClassReport, "verdict" | "verdictReasons" | "validationFailures">,
): {
  verdict: FounderPlatformVerdict;
  verdictReasons: string[];
} {
  const platform = buildMobilePrimaryPlatformReport();
  return {
    verdict: platform.verdict,
    verdictReasons: platform.reasons,
  };
}

export function collectMobilePrimaryValidationFailures(
  _report: MobileFirstClassReport,
): string[] {
  return collectMobilePrimaryProductFailures();
}

export function buildMobileFirstClassReport(): MobileFirstClassReport {
  const journey = buildMobileJourneyAudit();
  const parity = buildMobileParityReport();
  const independence = auditMobileIndependence();
  const paywall = buildMobilePaywallAudit();
  const archiveReview = buildMobileArchiveReview();

  const partial = {
    generatedAt: new Date().toISOString(),
    journey,
    parity,
    independence,
    paywall,
    archiveReview,
    productReadiness: pillarFromProduction("Product Readiness", "productReadiness"),
    storeReadiness: pillarFromProduction("Store Readiness", "storeReadiness"),
    distributionReadiness: pillarFromProduction(
      "Distribution Readiness",
      "distributionReadiness",
    ),
  };

  const { verdict, verdictReasons } = computeVerdict(partial);

  const report: MobileFirstClassReport = {
    ...partial,
    verdict,
    verdictReasons,
    validationFailures: [],
  };

  report.validationFailures = collectMobilePrimaryValidationFailures(report);

  return report;
}
