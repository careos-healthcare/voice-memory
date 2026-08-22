import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type {
  ReturnExpectationMet,
  ReturnTriggerReasonId,
} from "@/types/return-trigger-attribution";

export const RETURN_TRIGGER_ATTRIBUTION_EVENT_NAMES = {
  reason: "return_trigger_reason" as const,
  expectationMet: "return_expectation_met" as const,
};

export function trackReturnTriggerReason(meta: {
  reason: ReturnTriggerReasonId;
  attributionId: string;
  hoursSinceLastOpen?: number;
}): void {
  trackLocalEvent(RETURN_TRIGGER_ATTRIBUTION_EVENT_NAMES.reason, {
    reason: meta.reason,
    attributionId: meta.attributionId,
    hoursSinceLastOpen:
      meta.hoursSinceLastOpen !== undefined ? String(Math.round(meta.hoursSinceLastOpen)) : "",
  });
}

export function trackReturnExpectationMet(meta: {
  expectation: ReturnExpectationMet;
  attributionId: string;
  reason: ReturnTriggerReasonId;
}): void {
  trackLocalEvent(RETURN_TRIGGER_ATTRIBUTION_EVENT_NAMES.expectationMet, {
    expectation: meta.expectation,
    attributionId: meta.attributionId,
    reason: meta.reason,
  });
}

export function readReturnTriggerAttributionLocalEvents() {
  const names = new Set<string>(Object.values(RETURN_TRIGGER_ATTRIBUTION_EVENT_NAMES));
  return readLocalEvents().filter((e) => names.has(e.name));
}

export function clearReturnTriggerAttributionEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(RETURN_TRIGGER_ATTRIBUTION_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
