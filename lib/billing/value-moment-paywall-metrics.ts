import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type {
  ValueMomentPaywallMetricsReport,
  ValueMomentPaywallSurface,
  ValueMomentPaywallSurfaceBreakdown,
} from "@/types/value-moment-paywall";

export const VALUE_MOMENT_PAYWALL_EVENTS = {
  shown: "value_moment_paywall_shown",
  ctaClicked: "value_moment_paywall_cta_clicked",
  dismissed: "value_moment_paywall_dismissed",
} as const;

const SURFACES: ValueMomentPaywallSurface[] = [
  "blind_spot",
  "discover",
  "archive_continuity",
];

function countNamed(name: string): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}

function countNamedWithSurface(name: string, surface: ValueMomentPaywallSurface): number {
  return readLocalEvents().filter(
    (e) => e.name === name && e.meta?.surface === surface,
  ).length;
}

function pct(numerator: number, denominator: number): number | null {
  if (denominator <= 0) return null;
  return Math.round((numerator / denominator) * 1000) / 10;
}

function surfaceBreakdown(name: string): ValueMomentPaywallSurfaceBreakdown {
  return {
    blind_spot: countNamedWithSurface(name, "blind_spot"),
    discover: countNamedWithSurface(name, "discover"),
    archive_continuity: countNamedWithSurface(name, "archive_continuity"),
  };
}

export function trackValueMomentPaywallShown(surface: ValueMomentPaywallSurface): void {
  trackLocalEvent(VALUE_MOMENT_PAYWALL_EVENTS.shown, { surface });
}

export function trackValueMomentPaywallCtaClicked(surface: ValueMomentPaywallSurface): void {
  trackLocalEvent(VALUE_MOMENT_PAYWALL_EVENTS.ctaClicked, { surface });
}

export function trackValueMomentPaywallDismissed(surface: ValueMomentPaywallSurface): void {
  trackLocalEvent(VALUE_MOMENT_PAYWALL_EVENTS.dismissed, { surface });
}

export function buildValueMomentPaywallMetricsReport(): ValueMomentPaywallMetricsReport {
  const shownCount = countNamed(VALUE_MOMENT_PAYWALL_EVENTS.shown);
  const ctaClickedCount = countNamed(VALUE_MOMENT_PAYWALL_EVENTS.ctaClicked);
  const dismissedCount = countNamed(VALUE_MOMENT_PAYWALL_EVENTS.dismissed);
  const shownBreakdown = surfaceBreakdown(VALUE_MOMENT_PAYWALL_EVENTS.shown);

  const lines = [
    `Paywall shown: ${shownCount} (blind spot ${shownBreakdown.blind_spot}, discover ${shownBreakdown.discover}, continuity ${shownBreakdown.archive_continuity}).`,
    `CTA click rate: ${pct(ctaClickedCount, shownCount) ?? "—"}% · Dismiss rate: ${pct(dismissedCount, shownCount) ?? "—"}%.`,
    `Conversion proxy (CTA / shown): ${pct(ctaClickedCount, shownCount) ?? "—"}%.`,
    `Shown after blind spot: ${shownBreakdown.blind_spot} · after discover: ${shownBreakdown.discover}.`,
  ];

  return {
    generatedAt: new Date().toISOString(),
    shownCount,
    ctaClickedCount,
    dismissedCount,
    ctaClickRate: pct(ctaClickedCount, shownCount),
    dismissRate: pct(dismissedCount, shownCount),
    surfaceBreakdown: shownBreakdown,
    shownAfterBlindSpotCount: shownBreakdown.blind_spot,
    shownAfterDiscoverCount: shownBreakdown.discover,
    conversionProxyPercent: pct(ctaClickedCount, shownCount),
    lines,
  };
}

export function clearValueMomentPaywallMetricsForEval(): void {
  if (typeof globalThis.localStorage === "undefined") return;
  const names = new Set<string>(Object.values(VALUE_MOMENT_PAYWALL_EVENTS));
  const kept = readLocalEvents().filter((e) => !names.has(e.name));
  globalThis.localStorage.setItem("voicememory_local_events", JSON.stringify(kept));
}
