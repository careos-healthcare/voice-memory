import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type {
  ConversionReasonId,
  PaywallInterestReasonId,
  PaywallRejectionReasonId,
} from "@/types/paywall-attribution";

export const PAYWALL_ATTRIBUTION_EVENT_NAMES = {
  rejection: "paywall_rejection_reason" as const,
  interest: "paywall_interest_reason" as const,
  conversion: "conversion_reason" as const,
};

export function trackPaywallRejectionReason(meta: {
  reason: PaywallRejectionReasonId;
  attributionId: string;
  surface?: string;
  source?: string;
}): void {
  trackLocalEvent(PAYWALL_ATTRIBUTION_EVENT_NAMES.rejection, {
    reason: meta.reason,
    attributionId: meta.attributionId,
    surface: meta.surface ?? "",
    source: meta.source ?? "",
  });
}

export function trackPaywallInterestReason(meta: {
  reason: PaywallInterestReasonId;
  attributionId: string;
  surface?: string;
  source?: string;
}): void {
  trackLocalEvent(PAYWALL_ATTRIBUTION_EVENT_NAMES.interest, {
    reason: meta.reason,
    attributionId: meta.attributionId,
    surface: meta.surface ?? "",
    source: meta.source ?? "",
  });
}

export function trackConversionReason(meta: {
  reason: ConversionReasonId;
  attributionId: string;
  source?: string;
}): void {
  trackLocalEvent(PAYWALL_ATTRIBUTION_EVENT_NAMES.conversion, {
    reason: meta.reason,
    attributionId: meta.attributionId,
    source: meta.source ?? "",
  });
}

export function clearPaywallAttributionEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(PAYWALL_ATTRIBUTION_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}

export function readPaywallAttributionLocalEvents() {
  const names = new Set<string>(Object.values(PAYWALL_ATTRIBUTION_EVENT_NAMES));
  return readLocalEvents().filter((e) => names.has(e.name));
}
