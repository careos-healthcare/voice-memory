import { readAllBreakthroughEvents } from "@/lib/breakthrough/breakthrough-events";
import { VALUE_MOMENT_PAYWALL_EVENTS } from "@/lib/billing/value-moment-paywall-metrics";
import { LAUNCH_EVENTS, readLocalEvents, RETENTION_EVENTS } from "@/lib/local-analytics";
import { reasonLabel, readReturnTriggerAttributionRecords } from "@/lib/retention/return-trigger-attribution";
import {
  RETURN_EXPECTATION_MET_VALUES,
  RETURN_TRIGGER_REASON_IDS,
  type ReturnExpectationMet,
  type ReturnTriggerAttributionReport,
  type ReturnTriggerReasonId,
} from "@/types/return-trigger-attribution";

const OUTCOME_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

const ACTIVITY_EVENTS = new Set<string>([
  RETENTION_EVENTS.entryRecorded,
  RETENTION_EVENTS.insightViewed,
  RETENTION_EVENTS.pricingViewed,
  LAUNCH_EVENTS.memoryPageOpened,
  LAUNCH_EVENTS.secondReflectionCreated,
  "discover_opened",
  "returned_to_check_archive_view",
  "archive_belief_viewed",
  "session_movement_summary_seen",
]);

const PAYWALL_EVENTS = new Set<string>([
  VALUE_MOMENT_PAYWALL_EVENTS.shown,
  VALUE_MOMENT_PAYWALL_EVENTS.ctaClicked,
  VALUE_MOMENT_PAYWALL_EVENTS.dismissed,
]);

const SUBSCRIPTION_EVENTS = new Set<string>([
  LAUNCH_EVENTS.upgradeClicked,
  "stripe_checkout_completed",
  "customer.subscription.created",
]);

function eventAtMs(iso: string): number {
  return new Date(iso).getTime();
}

function rate(count: number, total: number): number | null {
  if (total === 0) return null;
  return Math.round((count / total) * 100);
}

function hadEventInWindow(
  anchorAt: string,
  names: Set<string>,
  windowMs = OUTCOME_WINDOW_MS,
): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + windowMs;
  return readLocalEvents().some((event) => {
    if (!names.has(event.name)) return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}

function hadBreakthroughInWindow(anchorAt: string): boolean {
  const start = eventAtMs(anchorAt);
  const end = start + OUTCOME_WINDOW_MS;
  return readAllBreakthroughEvents().some((event) => {
    const at = eventAtMs(event.createdAt);
    return at > start && at <= end;
  });
}

function buildCriticalAnswer(
  rows: ReturnTriggerAttributionReport["byReason"],
  total: number,
): string {
  if (total === 0) return "No self-reported return reasons yet on this device.";
  const lead = rows[0];
  if (!lead) return "Insufficient data.";
  const parts = [
    `Most often: ${lead.label} (${lead.sharePercent}% of responses).`,
  ];
  if (lead.reason === "archive_view_changed" && (lead.sharePercent ?? 0) >= 25) {
    parts.push("Users are returning to see whether the archive changed its view.");
  }
  if (lead.reason === "wanted_to_record" && (lead.sharePercent ?? 0) >= 30) {
    parts.push("A large share still returns primarily to capture — archive-check positioning may not be landing.");
  }
  return parts.join(" ");
}

export function buildReturnTriggerAttributionReport(): ReturnTriggerAttributionReport {
  const records = readReturnTriggerAttributionRecords();
  const withReason = records.filter((r) => r.reason);
  const totalReason = withReason.length;
  const totalExpectation = records.filter((r) => r.expectationMet).length;

  const counts = new Map<ReturnTriggerReasonId, number>();
  for (const id of RETURN_TRIGGER_REASON_IDS) counts.set(id, 0);
  for (const row of withReason) {
    counts.set(row.reason, (counts.get(row.reason) ?? 0) + 1);
  }

  let mostCommonReason: ReturnTriggerReasonId | null = null;
  let maxCount = 0;
  for (const [reason, count] of counts) {
    if (count > maxCount) {
      maxCount = count;
      mostCommonReason = reason;
    }
  }

  const byReason = RETURN_TRIGGER_REASON_IDS.map((reason) => {
    const subset = withReason.filter((r) => r.reason === reason);
    const count = subset.length;
    let sevenDay = 0;
    let paywall = 0;
    let subscription = 0;
    let breakthrough = 0;

    for (const row of subset) {
      if (hadEventInWindow(row.answeredAt, ACTIVITY_EVENTS)) sevenDay += 1;
      if (hadEventInWindow(row.answeredAt, PAYWALL_EVENTS)) paywall += 1;
      if (hadEventInWindow(row.answeredAt, SUBSCRIPTION_EVENTS)) subscription += 1;
      if (hadBreakthroughInWindow(row.answeredAt)) breakthrough += 1;
    }

    return {
      reason,
      label: reasonLabel(reason),
      count,
      sharePercent: rate(count, totalReason) ?? 0,
      sevenDayRetentionRate: rate(sevenDay, count),
      paywallClickRate: rate(paywall, count),
      subscriptionRate: rate(subscription, count),
      breakthroughRate: rate(breakthrough, count),
    };
  })
    .filter((row) => row.count > 0)
    .sort((a, b) => b.count - a.count);

  const expectationCounts = new Map<ReturnExpectationMet, number>();
  for (const met of RETURN_EXPECTATION_MET_VALUES) expectationCounts.set(met, 0);
  for (const row of records) {
    if (!row.expectationMet) continue;
    expectationCounts.set(
      row.expectationMet,
      (expectationCounts.get(row.expectationMet) ?? 0) + 1,
    );
  }

  const expectationBreakdown = RETURN_EXPECTATION_MET_VALUES.map((met) => ({
    met,
    count: expectationCounts.get(met) ?? 0,
    sharePercent: rate(expectationCounts.get(met) ?? 0, totalExpectation) ?? 0,
  })).filter((row) => row.count > 0);

  return {
    criticalQuestion: "Why do people actually come back?",
    criticalAnswer: buildCriticalAnswer(byReason, totalReason),
    totalReasonResponses: totalReason,
    totalExpectationResponses: totalExpectation,
    mostCommonReason,
    mostCommonReasonLabel: mostCommonReason ? reasonLabel(mostCommonReason) : null,
    byReason,
    expectationBreakdown,
    recentRecords: records.slice(0, 12),
  };
}
