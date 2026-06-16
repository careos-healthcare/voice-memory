import { buildDistributionMetricRates } from "@/lib/distribution/distribution-metrics";
import { buildActivationMetricsReport } from "@/lib/product/activation-metrics";
import { buildMobileProductionReadinessReport } from "@/lib/mobile/mobile-production-readiness";
import { isLiveBillingAvailable } from "@/lib/entitlement/payment-stack";
import { getPlanId } from "@/lib/subscription";
import type { LaunchReadinessReport, LaunchReadinessVerdict } from "@/types/internal-archive";

function verdictFromFlags(flags: boolean[]): LaunchReadinessVerdict {
  const ready = flags.filter(Boolean).length;
  if (ready >= 5) return "READY";
  if (ready >= 3) return "ALMOST_READY";
  return "NOT_READY";
}

export function buildLaunchReadinessReport(): LaunchReadinessReport {
  const mobile = buildMobileProductionReadinessReport();
  const activation = buildActivationMetricsReport();
  const distribution = buildDistributionMetricRates();

  const mobileReady =
    mobile.productReadiness.status === "PASSING" ||
    mobile.passingCount >= Math.ceil(mobile.items.length * 0.5);
  const storeReady = mobile.storeReadiness.status === "PASSING";
  const distributionReady =
    distribution.distributionScore >= 25 ||
    (distribution.shareRate ?? 0) > 0 ||
    (distribution.referralRate ?? 0) > 0;
  const revenueReady = isLiveBillingAvailable() || getPlanId() === "pro";
  const activationReady =
    activation.hasReachedFiveLocally ||
    (activation.fiveReflectionsRate ?? 0) >= 50;

  const flags = [mobileReady, storeReady, distributionReady, revenueReady, activationReady];

  return {
    generatedAt: new Date().toISOString(),
    verdict: verdictFromFlags(flags),
    mobileReadiness: {
      label: "Mobile readiness",
      ready: mobileReady,
      detail: mobile.productReadiness.summary,
    },
    storeReadiness: {
      label: "Store readiness",
      ready: storeReady,
      detail: mobile.storeReadiness.summary,
    },
    distributionReadiness: {
      label: "Distribution readiness",
      ready: distributionReady,
      detail: `Distribution score ${distribution.distributionScore}`,
    },
    revenueReadiness: {
      label: "Revenue readiness",
      ready: revenueReady,
      detail: revenueReady ? "Billing path available" : "Billing not live on this device",
    },
    activationReadiness: {
      label: "Activation readiness",
      ready: activationReady,
      detail: activation.lines[0] ?? "Activation metrics on this device",
    },
  };
}
