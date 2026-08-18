import { readAllBreakthroughEvents } from "@/lib/breakthrough/breakthrough-events";
import {
  conversionLabel,
  interestLabel,
  readPaywallAttributionRecords,
  rejectionLabel,
} from "@/lib/billing/paywall-attribution";
import { PAYWALL_ATTRIBUTION_EVENT_NAMES } from "@/lib/metrics/paywall-attribution-events";
import { LAUNCH_EVENTS, readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import { getPlanId } from "@/lib/subscription";
import {
  CONVERSION_REASON_IDS,
  PAYWALL_INTEREST_REASON_IDS,
  PAYWALL_REJECTION_REASON_IDS,
  type ConversionReasonId,
  type PaywallAttributionReasonRow,
  type PaywallAttributionReport,
  type PaywallInterestReasonId,
  type PaywallRejectionReasonId,
} from "@/types/paywall-attribution";

const OUTCOME_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const CONVERSION_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;

const ACTIVITY_EVENTS = new Set<string>([
  RETENTION_EVENTS.entryRecorded,
  RETENTION_EVENTS.insightViewed,
  RETENTION_EVENTS.pricingViewed,
  LAUNCH_EVENTS.memoryPageOpened,
  "discover_opened",
  "archive_belief_viewed",
]);

function eventAtMs(iso: string): number {
  return new Date(iso).getTime();
}

function rate(count: number, total: number): number | null {
  if (total === 0) return null;
  return Math.round((count / total) * 100);
}

function hadEventInWindow(anchorAt: string, names: Set<string>, windowMs: number): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + windowMs;
  return readLocalEvents().some((event) => {
    if (!names.has(event.name)) return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}

function hadBreakthroughInWindow(anchorAt: string, windowMs: number): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + windowMs;
  return readAllBreakthroughEvents().some((event) => {
    const at = eventAtMs(event.createdAt);
    return at > start && at <= end;
  });
}

function hadConversionAfter(anchorAt: string): boolean {
  if (getPlanId() === "pro") {
    const conversions = readPaywallAttributionRecords().filter((r) => r.kind === "conversion");
    const anchorMs = eventAtMs(anchorAt);
    if (conversions.some((c) => eventAtMs(c.at) >= anchorMs)) return true;
  }
  return hadEventInWindow(
    anchorAt,
    new Set<string>([PAYWALL_ATTRIBUTION_EVENT_NAMES.conversion, LAUNCH_EVENTS.upgradeClicked]),
    CONVERSION_WINDOW_MS,
  );
}

function buildRows(
  ids: readonly string[],
  labelFn: (id: string) => string,
  records: ReturnType<typeof readPaywallAttributionRecords>,
  kind: "rejection" | "interest" | "conversion",
  correlateSubscription: boolean,
): PaywallAttributionReasonRow[] {
  const subset = records.filter((r) => r.kind === kind);
  const total = subset.length;

  return ids
    .map((reason) => {
      const matching = subset.filter((r) => r.reason === reason);
      const count = matching.length;
      let subscription = 0;
      let retention = 0;
      let breakthrough = 0;

      for (const row of matching) {
        if (correlateSubscription && hadConversionAfter(row.at)) subscription += 1;
        if (hadEventInWindow(row.at, ACTIVITY_EVENTS, OUTCOME_WINDOW_MS)) retention += 1;
        if (hadBreakthroughInWindow(row.at, OUTCOME_WINDOW_MS)) breakthrough += 1;
      }

      return {
        reason,
        label: labelFn(reason),
        count,
        sharePercent: rate(count, total) ?? 0,
        subscriptionRate: correlateSubscription ? rate(subscription, count) : null,
        retentionRate: rate(retention, count),
        breakthroughRate: rate(breakthrough, count),
      };
    })
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count);
}

function buildMainAnswer(
  conversions: PaywallAttributionReasonRow[],
  rejections: PaywallAttributionReasonRow[],
): string {
  if (conversions.length === 0 && rejections.length === 0) {
    return "No paywall attribution responses on this device yet.";
  }
  const parts: string[] = [];
  const topConvert = conversions[0];
  const topReject = rejections[0];
  if (topConvert) {
    parts.push(
      `Top conversion driver: ${topConvert.label} (${topConvert.sharePercent}% of subscriber responses).`,
    );
  }
  if (topReject) {
    parts.push(
      `Top rejection blocker: ${topReject.label} (${topReject.sharePercent}% of dismiss responses).`,
    );
  }
  return parts.join(" ");
}

export function buildPaywallAttributionReport(): PaywallAttributionReport {
  const records = readPaywallAttributionRecords();
  const rejections = records.filter((r) => r.kind === "rejection");
  const interests = records.filter((r) => r.kind === "interest");
  const conversions = records.filter((r) => r.kind === "conversion");

  const topRejectionReasons = buildRows(
    PAYWALL_REJECTION_REASON_IDS,
    (id) => rejectionLabel(id as PaywallRejectionReasonId),
    records,
    "rejection",
    false,
  );

  const topConversionDrivers = buildRows(
    CONVERSION_REASON_IDS,
    (id) => conversionLabel(id as ConversionReasonId),
    records,
    "conversion",
    false,
  );

  const interestByOutcome = buildRows(
    PAYWALL_INTEREST_REASON_IDS,
    (id) => interestLabel(id as PaywallInterestReasonId),
    records,
    "interest",
    true,
  );

  return {
    mainQuestion: "What makes people pay?",
    mainAnswer: buildMainAnswer(topConversionDrivers, topRejectionReasons),
    totalRejections: rejections.length,
    totalInterest: interests.length,
    totalConversions: conversions.length,
    topConversionDrivers,
    topRejectionReasons,
    interestByOutcome,
    recentRecords: records.slice(0, 15),
  };
}
