import {
  trackReturnExpectationMet,
  trackReturnTriggerReason,
} from "@/lib/metrics/return-trigger-attribution-events";
import { RETURN_TRIGGER_REASON_LABELS } from "@/lib/retention/return-trigger-attribution-copy";
import type {
  ReturnExpectationMet,
  ReturnTriggerAttributionRecord,
  ReturnTriggerReasonId,
} from "@/types/return-trigger-attribution";

export const RETURN_ATTRIBUTION_LAST_OPEN_KEY = "voicememory_return_attribution_last_open";
export const RETURN_ATTRIBUTION_PENDING_REASON_KEY =
  "voicememory_return_attribution_pending_reason";
export const RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY =
  "voicememory_return_attribution_pending_expectation";
export const RETURN_ATTRIBUTION_RECORDS_KEY = "voicememory_return_attribution_records";
export const RETURN_ATTRIBUTION_REASON_DISMISSED_KEY =
  "voicememory_return_attribution_reason_dismissed_visit";

export const MIN_RETURN_ATTRIBUTION_HOURS = 24;
const MAX_RETURN_WINDOW_HOURS = 24 * 30;
const MAX_RECORDS = 200;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function getStorage(): Storage | null {
  if (!isBrowser()) return null;
  return localStorage;
}

function hoursBetween(fromIso: string, toMs: number): number {
  return (toMs - new Date(fromIso).getTime()) / (1000 * 60 * 60);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function readRecords(): ReturnTriggerAttributionRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(RETURN_ATTRIBUTION_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ReturnTriggerAttributionRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRecords(rows: ReturnTriggerAttributionRecord[]): void {
  getStorage()?.setItem(
    RETURN_ATTRIBUTION_RECORDS_KEY,
    JSON.stringify(rows.slice(-MAX_RECORDS)),
  );
}

/** Call on app load — detect 24h+ return and arm the reason prompt once per visit. */
export function observeReturnVisitForAttribution(): void {
  const store = getStorage();
  if (!store) return;

  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const lastOpenRaw = store.getItem(RETURN_ATTRIBUTION_LAST_OPEN_KEY);
  store.setItem(RETURN_ATTRIBUTION_LAST_OPEN_KEY, nowIso);

  if (!lastOpenRaw) return;

  const hoursSinceLastOpen = hoursBetween(lastOpenRaw, nowMs);
  if (hoursSinceLastOpen < MIN_RETURN_ATTRIBUTION_HOURS) return;
  if (hoursSinceLastOpen > MAX_RETURN_WINDOW_HOURS) return;

  const visitKey = nowIso.slice(0, 13);
  const dismissedVisit = store.getItem(RETURN_ATTRIBUTION_REASON_DISMISSED_KEY);
  if (dismissedVisit === visitKey) return;

  const pendingRaw = store.getItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY);
  if (pendingRaw) return;

  store.setItem(
    RETURN_ATTRIBUTION_PENDING_REASON_KEY,
    JSON.stringify({
      visitKey,
      hoursSinceLastOpen: Math.round(hoursSinceLastOpen),
      armedAt: nowIso,
    }),
  );
}

export function shouldShowReturnTriggerReasonPrompt(): boolean {
  const store = getStorage();
  if (!store) return false;
  return Boolean(store.getItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY));
}

export function dismissReturnTriggerReasonPrompt(): void {
  const store = getStorage();
  if (!store) return;
  const pendingRaw = store.getItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY);
  if (pendingRaw) {
    try {
      const pending = JSON.parse(pendingRaw) as { visitKey?: string };
      if (pending.visitKey) {
        store.setItem(RETURN_ATTRIBUTION_REASON_DISMISSED_KEY, pending.visitKey);
      }
    } catch {
      /* ignore */
    }
  }
  store.removeItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY);
}

export function saveReturnTriggerReason(reason: ReturnTriggerReasonId): ReturnTriggerAttributionRecord {
  const store = getStorage();
  const pendingRaw = store?.getItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY);
  let hoursSinceLastOpen: number | null = null;
  if (pendingRaw) {
    try {
      const pending = JSON.parse(pendingRaw) as { hoursSinceLastOpen?: number };
      hoursSinceLastOpen =
        typeof pending.hoursSinceLastOpen === "number" ? pending.hoursSinceLastOpen : null;
    } catch {
      /* ignore */
    }
  }

  const record: ReturnTriggerAttributionRecord = {
    id: newId("rta"),
    reason,
    answeredAt: new Date().toISOString(),
    hoursSinceLastOpen,
  };

  const rows = readRecords();
  rows.push(record);
  writeRecords(rows);

  trackReturnTriggerReason({
    reason,
    attributionId: record.id,
    hoursSinceLastOpen: hoursSinceLastOpen ?? undefined,
  });

  store?.removeItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY);
  store?.setItem(
    RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY,
    JSON.stringify({ attributionId: record.id, reason: record.reason }),
  );

  return record;
}

/** Call when Discover opens (after discover_opened) — arms expectation prompt if reason was captured. */
export function markReturnExpectationPromptEligible(): void {
  const store = getStorage();
  if (!store) return;
  const pending = store.getItem(RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY);
  if (!pending) return;
  try {
    const parsed = JSON.parse(pending) as {
      attributionId: string;
      reason: ReturnTriggerReasonId;
      discoverOpenedAt?: string;
    };
    if (parsed.discoverOpenedAt) return;
    store.setItem(
      RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY,
      JSON.stringify({ ...parsed, discoverOpenedAt: new Date().toISOString(), show: true }),
    );
  } catch {
    /* ignore */
  }
}

export function shouldShowReturnExpectationPrompt(): {
  attributionId: string;
  reason: ReturnTriggerReasonId;
} | null {
  const store = getStorage();
  if (!store) return null;
  const raw = store.getItem(RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as {
      attributionId: string;
      reason: ReturnTriggerReasonId;
      show?: boolean;
      answered?: boolean;
    };
    if (!parsed.show || parsed.answered) return null;
    if (!parsed.attributionId || !parsed.reason) return null;
    const record = readRecords().find((r) => r.id === parsed.attributionId);
    if (record?.expectationMet) return null;
    return { attributionId: parsed.attributionId, reason: parsed.reason };
  } catch {
    return null;
  }
}

export function dismissReturnExpectationPrompt(): void {
  const store = getStorage();
  if (!store) return;
  const raw = store.getItem(RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY);
  if (!raw) return;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    store.setItem(
      RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY,
      JSON.stringify({ ...parsed, answered: true, dismissed: true }),
    );
  } catch {
    store.removeItem(RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY);
  }
}

export function saveReturnExpectationMet(
  expectation: ReturnExpectationMet,
  context: { attributionId: string; reason: ReturnTriggerReasonId },
): void {
  const rows = readRecords();
  const idx = rows.findIndex((r) => r.id === context.attributionId);
  const answeredAt = new Date().toISOString();
  if (idx >= 0) {
    rows[idx] = {
      ...rows[idx]!,
      expectationMet: expectation,
      expectationAnsweredAt: answeredAt,
    };
    writeRecords(rows);
  }

  trackReturnExpectationMet({
    expectation,
    attributionId: context.attributionId,
    reason: context.reason,
  });

  const store = getStorage();
  store?.removeItem(RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY);
}

export function readReturnTriggerAttributionRecords(): ReturnTriggerAttributionRecord[] {
  return readRecords().slice().reverse();
}

export function reasonLabel(reason: ReturnTriggerReasonId): string {
  return RETURN_TRIGGER_REASON_LABELS[reason];
}

export function clearReturnTriggerAttributionForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(RETURN_ATTRIBUTION_LAST_OPEN_KEY);
  store.removeItem(RETURN_ATTRIBUTION_PENDING_REASON_KEY);
  store.removeItem(RETURN_ATTRIBUTION_PENDING_EXPECTATION_KEY);
  store.removeItem(RETURN_ATTRIBUTION_RECORDS_KEY);
  store.removeItem(RETURN_ATTRIBUTION_REASON_DISMISSED_KEY);
}
