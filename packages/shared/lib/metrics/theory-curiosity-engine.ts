import {
  buildTheoryCuriosityReport,
  readTheoryCuriosityRecords,
  saveTheoryCuriosityAnswer,
  THEORY_CURIOSITY_EVENT,
} from "@/lib/metrics/theory-curiosity";

export { saveTheoryCuriosityAnswer, readTheoryCuriosityRecords } from "@/lib/metrics/theory-curiosity";
import { readLocalEvents } from "@/lib/local-analytics";
import { readFunnelState } from "@/lib/retention/first-week-funnel";
import { VALUE_MOMENT_PAYWALL_EVENTS } from "@/lib/billing/value-moment-paywall-metrics";
import { THEORY_EVENTS, readAllTheoryEvents } from "@/lib/theories/theory-events";
import type {
  TheoryCuriosityEngineReport,
  TheoryCuriosityFunnelStep,
} from "@/types/theory-curiosity-engine";
import type { TheoryCuriosityAnswer, TheoryCuriosityRecord } from "@/types/personal-theory";

const MS_DAY = 24 * 60 * 60 * 1000;
const DISCOVER_WINDOW_MS = 14 * MS_DAY;
const RETURN_WINDOW_MS = 7 * MS_DAY;
const CONVERSION_WINDOW_MS = 30 * MS_DAY;
const TREND_RECENT_MS = 30 * MS_DAY;

export const THEORY_CURIOSITY_LEADING_INDICATOR =
  "If curiosity rate rises, treat this as a leading retention indicator.";

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

export function isCuriousAnswer(answer: TheoryCuriosityAnswer): boolean {
  return answer === "yes" || answer === "maybe";
}

function eventAtMs(iso: string): number {
  return new Date(iso).getTime();
}

function hadDiscoverOpenAfter(atMs: number): boolean {
  const end = atMs + DISCOVER_WINDOW_MS;
  const theoryEvents = readAllTheoryEvents().some(
    (e) =>
      e.name === THEORY_EVENTS.discoverOpened &&
      eventAtMs(e.at) >= atMs &&
      eventAtMs(e.at) <= end,
  );
  if (theoryEvents) return true;
  return readLocalEvents().some((e) => {
    const t = eventAtMs(e.at);
    if (t < atMs || t > end) return false;
    return (
      e.name === "activation_discovery_surface_opened" &&
      e.meta?.surface === "discover"
    );
  });
}

function hadReturnWithin7dAfter(atMs: number): boolean {
  const end = atMs + RETURN_WINDOW_MS;
  const funnelAt = readFunnelState().stages.return_within_7d?.at;
  if (funnelAt) {
    const t = eventAtMs(funnelAt);
    if (t >= atMs && t <= end) return true;
  }
  return readLocalEvents().some((e) => {
    if (e.name !== "entry_recorded") return false;
    const t = eventAtMs(e.at);
    return t >= atMs && t <= end;
  });
}

function hadPaywallClickAfter(atMs: number): boolean {
  const end = atMs + CONVERSION_WINDOW_MS;
  return readLocalEvents().some(
    (e) =>
      e.name === VALUE_MOMENT_PAYWALL_EVENTS.ctaClicked &&
      eventAtMs(e.at) >= atMs &&
      eventAtMs(e.at) <= end,
  );
}

function hadSubscriptionAfter(atMs: number): boolean {
  const end = atMs + CONVERSION_WINDOW_MS;
  return readLocalEvents().some(
    (e) =>
      (e.name === "upgrade_clicked" || e.name === "billing_checkout_completed") &&
      eventAtMs(e.at) >= atMs &&
      eventAtMs(e.at) <= end,
  );
}

function correlateCuriousRecord(record: TheoryCuriosityRecord) {
  const atMs = eventAtMs(record.at);
  if (!isCuriousAnswer(record.answer)) {
    return {
      discover: false,
      return7d: false,
      paywall: false,
      subscription: false,
    };
  }
  return {
    discover: hadDiscoverOpenAfter(atMs),
    return7d: hadReturnWithin7dAfter(atMs),
    paywall: hadPaywallClickAfter(atMs),
    subscription: hadSubscriptionAfter(atMs),
  };
}

function curiosityRateInWindow(
  records: TheoryCuriosityRecord[],
  startMs: number,
  endMs: number,
): number | null {
  const inWindow = records.filter((r) => {
    const t = eventAtMs(r.at);
    return t >= startMs && t < endMs;
  });
  if (inWindow.length === 0) return null;
  const curious = inWindow.filter((r) => isCuriousAnswer(r.answer)).length;
  return Math.round((curious / inWindow.length) * 100);
}

function buildFunnel(curiousRecords: TheoryCuriosityRecord[]): TheoryCuriosityFunnelStep[] {
  const correlations = curiousRecords
    .filter((r) => isCuriousAnswer(r.answer))
    .map(correlateCuriousRecord);

  const curiousCount = correlations.length;
  const discoverCount = correlations.filter((c) => c.discover).length;
  const returnCount = correlations.filter((c) => c.return7d).length;
  const paywallCount = correlations.filter((c) => c.paywall).length;
  const subscriptionCount = correlations.filter((c) => c.subscription).length;

  const steps: TheoryCuriosityFunnelStep[] = [
    {
      id: "curiosity",
      label: "Curiosity (yes / maybe)",
      count: curiousCount,
      rateFromCuriousPercent: curiousCount > 0 ? 100 : null,
      rateFromPriorStepPercent: null,
    },
    {
      id: "discover_open",
      label: "Discover open",
      count: discoverCount,
      rateFromCuriousPercent: pct(discoverCount, curiousCount),
      rateFromPriorStepPercent: pct(discoverCount, curiousCount),
    },
    {
      id: "return_7d",
      label: "Return 7 days",
      count: returnCount,
      rateFromCuriousPercent: pct(returnCount, curiousCount),
      rateFromPriorStepPercent: pct(returnCount, discoverCount),
    },
    {
      id: "paywall_click",
      label: "Paywall click",
      count: paywallCount,
      rateFromCuriousPercent: pct(paywallCount, curiousCount),
      rateFromPriorStepPercent: pct(paywallCount, returnCount),
    },
    {
      id: "subscription",
      label: "Subscription",
      count: subscriptionCount,
      rateFromCuriousPercent: pct(subscriptionCount, curiousCount),
      rateFromPriorStepPercent: pct(subscriptionCount, paywallCount),
    },
  ];

  return steps;
}

export function buildTheoryCuriosityEngineReport(
  records = readTheoryCuriosityRecords(),
): TheoryCuriosityEngineReport {
  const base = buildTheoryCuriosityReport(records);
  const curiousRecords = records.filter((r) => isCuriousAnswer(r.answer));
  const funnel = buildFunnel(curiousRecords);

  const now = Date.now();
  const recentRate = curiosityRateInWindow(records, now - TREND_RECENT_MS, now);
  const priorRate = curiosityRateInWindow(
    records,
    now - 2 * TREND_RECENT_MS,
    now - TREND_RECENT_MS,
  );

  let curiosityRateRising: boolean | null = null;
  if (recentRate !== null && priorRate !== null) {
    curiosityRateRising = recentRate > priorRate;
  }

  return {
    ...base,
    curiousCount: curiousRecords.length,
    funnel,
    leadingIndicatorLine: THEORY_CURIOSITY_LEADING_INDICATOR,
    curiosityRateRising,
    measurementNote:
      "Funnel uses device-local timestamps after each curious answer. No streaks or push reminders.",
  };
}
