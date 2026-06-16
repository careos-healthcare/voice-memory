import { buildArchiveAttachmentReport } from "@/lib/internal/archive-attachment-report";
import { buildPaywallAttributionReport } from "@/lib/internal/paywall-attribution-report";
import { buildReturnTriggerAttributionReport } from "@/lib/internal/return-trigger-attribution-report";
import {
  NORTH_STAR_METRIC_COPY,
} from "@/lib/internal/founder-focus-copy";
import { readLocalEvents } from "@/lib/local-analytics";
import { stageForReflectionCount } from "@/lib/product/archive-value-progress";
import { countCompletedReflections } from "@/lib/mobile/install-prompt-gate";
import { getPlanId } from "@/lib/subscription";
import type {
  NorthStarDashboardView,
  NorthStarMetricId,
  NorthStarMetricView,
} from "@/types/founder-focus";

const CURIOSITY_EVENTS = new Set([
  "discover_opened",
  "returned_to_check_archive_view",
  "archive_belief_viewed",
  "activation_discovery_surface_opened",
]);

function formatRate(value: number | null, suffix = "%"): string {
  if (value === null) return "—";
  return `${value}${suffix}`;
}

function curiosityRate(): { value: number | null; detail: string } {
  const events = readLocalEvents().filter((e) => CURIOSITY_EVENTS.has(e.name));
  const opens = events.length;
  const reflections = Math.max(1, countCompletedReflections());
  const rate =
    opens > 0 ? Math.min(100, Math.round((opens / reflections) * 100)) : null;
  return {
    value: rate,
    detail:
      opens > 0
        ? `${opens} archive-check signals on this device · ${reflections} reflections`
        : "No discover or archive-check opens recorded yet",
  };
}

function activationRate(): { value: number | null; detail: string } {
  const reflections = countCompletedReflections();
  const stage = stageForReflectionCount(reflections);
  const reached =
    reflections >= 5 ||
    stage === "theory_under_review" ||
    stage === "pattern_review_unlocked";
  const rate = reflections > 0 ? (reached ? 100 : Math.round((reflections / 5) * 100)) : null;
  return {
    value: rate,
    detail: reached
      ? "First working belief threshold met on this device"
      : `${reflections}/5 reflections toward first belief · stage ${stage}`,
  };
}

function returnRate(): { value: number | null; detail: string } {
  const report = buildReturnTriggerAttributionReport();
  const changed = report.byReason.find((r) => r.reason === "archive_view_changed");
  const share = changed?.sharePercent ?? null;
  const withReturn = changed?.sevenDayRetentionRate ?? null;
  return {
    value: withReturn ?? share,
    detail:
      changed && (changed.count ?? 0) > 0
        ? `${changed.sharePercent}% cited archive change · ${formatRate(withReturn)} returned within 7 days`
        : report.criticalAnswer,
  };
}

function conversionRate(): { value: number | null; detail: string } {
  const report = buildPaywallAttributionReport();
  const paid = getPlanId() === "pro";
  if (paid) {
    return {
      value: 100,
      detail: "Pro active on this device",
    };
  }
  const denom = report.totalInterest + report.totalConversions;
  const rate =
    denom > 0
      ? Math.round((report.totalConversions / denom) * 100)
      : null;
  return {
    value: rate,
    detail: report.mainAnswer,
  };
}

function attachmentRate(): { value: number | null; detail: string } {
  const report = buildArchiveAttachmentReport();
  return {
    value: report.strongAttachmentPercent,
    detail: report.criticalAnswer,
  };
}

function buildMetric(
  id: NorthStarMetricId,
  value: number | null,
  detail: string,
): NorthStarMetricView {
  const copy = NORTH_STAR_METRIC_COPY[id];
  return {
    id,
    title: copy.title,
    subtitle: copy.subtitle,
    value: formatRate(value),
    detail,
  };
}

/** Exactly five north-star metrics — no extras. */
export function buildNorthStarDashboard(): NorthStarDashboardView {
  const activation = activationRate();
  const returning = returnRate();
  const curiosity = curiosityRate();
  const conversion = conversionRate();
  const attachment = attachmentRate();

  return {
    generatedAt: new Date().toISOString(),
    metrics: [
      buildMetric("activation", activation.value, activation.detail),
      buildMetric("return", returning.value, returning.detail),
      buildMetric("curiosity", curiosity.value, curiosity.detail),
      buildMetric("conversion", conversion.value, conversion.detail),
      buildMetric("attachment", attachment.value, attachment.detail),
    ],
  };
}

/** Guardrail — north star surface must never grow past five metrics. */
export const NORTH_STAR_METRIC_COUNT = 5;

export function assertNorthStarMetricCount(metrics: unknown[]): void {
  if (metrics.length !== NORTH_STAR_METRIC_COUNT) {
    throw new Error(`North star must expose exactly ${NORTH_STAR_METRIC_COUNT} metrics`);
  }
}
