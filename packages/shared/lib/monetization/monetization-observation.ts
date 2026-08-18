import { LAUNCH_EVENTS, readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { readStoredIncidents } from "@/lib/validation/incidents";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  MonetizationObservationEvent,
  MonetizationObservationReport,
  PremiumSurface,
} from "@/types/monetization-validation";

export const PREMIUM_LINE_SEEN = "premium_line_seen";
export const BACKUP_AFTER_PREMIUM = "backup_after_premium";
export const EXPORT_AFTER_PREMIUM = "export_after_premium";
export const REVISIT_AFTER_PREMIUM = "revisit_after_premium";
export const TRUST_DROP_AFTER_PREMIUM = "trust_drop_after_premium";
export const SESSION_ABANDON_AFTER_PREMIUM = "session_abandon_after_premium";
export const LEGITIMACY_SNAPSHOT = "legitimacy_snapshot";

const OBSERVATION_KEY = "voicememory_monetization_observation";
const LAST_PREMIUM_AT_KEY = "voicememory_last_premium_line_at";
const MAX_EVENTS = 200;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readEventsRaw(): MonetizationObservationEvent[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(OBSERVATION_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as MonetizationObservationEvent[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeEventsRaw(events: MonetizationObservationEvent[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(OBSERVATION_KEY, JSON.stringify(events.slice(-MAX_EVENTS)));
}

function pushEvent(
  kind: MonetizationObservationEvent["kind"],
  meta?: Record<string, string>,
): MonetizationObservationEvent {
  const event: MonetizationObservationEvent = {
    id: crypto.randomUUID(),
    kind,
    at: new Date().toISOString(),
    surface: meta?.surface as PremiumSurface | undefined,
    line: meta?.line,
    meta,
  };
  writeEventsRaw([...readEventsRaw(), event]);
  trackLocalEvent(kind, meta);
  return event;
}

function lastPremiumLineAt(): number {
  if (!isBrowser()) return 0;
  const raw = localStorage.getItem(LAST_PREMIUM_AT_KEY);
  return raw ? Number(raw) : 0;
}

function setLastPremiumLineAt(at: number): void {
  if (!isBrowser()) return;
  localStorage.setItem(LAST_PREMIUM_AT_KEY, String(at));
}

function withinWindowHours(hours: number): boolean {
  const last = lastPremiumLineAt();
  if (!last) return false;
  return Date.now() - last < hours * 60 * 60 * 1000;
}

function pushLegitimacySnapshot(phase: "before" | "after", surface?: PremiumSurface): void {
  if (!isBrowser()) return;
  void import("@/lib/debug/emotional-legitimacy-review").then(({ buildEmotionalLegitimacyReport }) => {
    const legitimacy = buildEmotionalLegitimacyReport(getMemoryEligibleEntries()).scores.overall;
    pushEvent(LEGITIMACY_SNAPSHOT, {
      phase,
      score: String(legitimacy),
      ...(surface ? { surface } : {}),
    });
  });
}

export function trackPremiumLineSeen(surface: PremiumSurface, line: string): void {
  setLastPremiumLineAt(Date.now());
  pushEvent(PREMIUM_LINE_SEEN, { surface, line: line.slice(0, 120) });
  pushLegitimacySnapshot("before", surface);
}

export function maybeTrackPostPremiumBehavior(kind: "backup" | "export" | "revisit"): void {
  if (!withinWindowHours(72)) return;

  if (kind === "backup") pushEvent(BACKUP_AFTER_PREMIUM, {});
  if (kind === "export") pushEvent(EXPORT_AFTER_PREMIUM, {});
  if (kind === "revisit") pushEvent(REVISIT_AFTER_PREMIUM, {});

  pushLegitimacySnapshot("after");
}

export function maybeTrackTrustDropAfterPremium(): void {
  if (!withinWindowHours(72)) return;
  const incidents = readStoredIncidents().filter((row) => !row.resolved);
  if (incidents.length === 0) return;
  pushEvent(TRUST_DROP_AFTER_PREMIUM, { detail: incidents[0].kind });
}

export function trackSessionAbandonAfterPremium(): void {
  if (!withinWindowHours(24)) return;
  pushEvent(SESSION_ABANDON_AFTER_PREMIUM, {});
}

export function scanPostPremiumOutcomes(): void {
  if (!withinWindowHours(72)) return;
  const lastAt = lastPremiumLineAt();

  for (const event of readRetentionLoopEvents()) {
    if (new Date(event.at).getTime() <= lastAt) continue;
    if (event.kind === "entry_revisited") {
      maybeTrackPostPremiumBehavior("revisit");
      break;
    }
  }

  for (const event of readLocalEvents()) {
    if (new Date(event.at).getTime() <= lastAt) continue;
    if (event.name === LAUNCH_EVENTS.exportUsed) {
      maybeTrackPostPremiumBehavior("export");
      break;
    }
  }
}

export function buildMonetizationObservationReport(): MonetizationObservationReport {
  scanPostPremiumOutcomes();
  maybeTrackTrustDropAfterPremium();

  const events = readEventsRaw();
  const snapshots = events.filter((event) => event.kind === LEGITIMACY_SNAPSHOT);

  const before = snapshots.find((event) => event.meta?.phase === "before");
  const after = [...snapshots].reverse().find((event) => event.meta?.phase === "after");

  return {
    generatedAt: new Date().toISOString(),
    hasData: events.length > 0,
    premiumLinesSeen: events.filter((event) => event.kind === PREMIUM_LINE_SEEN).length,
    backupAfterPremium: events.filter((event) => event.kind === BACKUP_AFTER_PREMIUM).length,
    exportAfterPremium: events.filter((event) => event.kind === EXPORT_AFTER_PREMIUM).length,
    revisitAfterPremium: events.filter((event) => event.kind === REVISIT_AFTER_PREMIUM).length,
    trustDropAfterPremium: events.filter((event) => event.kind === TRUST_DROP_AFTER_PREMIUM).length,
    sessionAbandonAfterPremium: events.filter(
      (event) => event.kind === SESSION_ABANDON_AFTER_PREMIUM,
    ).length,
    legitimacyBeforeExposure: before?.meta?.score ? Number(before.meta.score) : null,
    legitimacyAfterExposure: after?.meta?.score ? Number(after.meta.score) : null,
    events: events.slice(-40),
  };
}
