import { LAUNCH_EVENTS, countLocalEvents, readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import { readLastBackupAt } from "@/lib/sync/status-storage";
import { readStoredIncidents } from "@/lib/validation/incidents";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { getOrCreateParticipantId } from "@/lib/research/retention-observation";
import type {
  PilotFounderLabel,
  PilotFounderLabelRecord,
  PilotInterestEvent,
  PilotInterestKind,
  PilotInterestReport,
} from "@/types/pilot-system";

export const PILOT_PAGE_VIEW = "pilot_page_viewed";
export const PILOT_PRICING_OPEN = "pilot_pricing_opened";
export const PILOT_PAYMENT_ASK = "pilot_payment_asked";
export const PILOT_REVISIT_AFTER = "pilot_revisit_after_view";
export const PILOT_TRUST_DROP = "pilot_trust_drop_after_view";
export const PILOT_ABANDON = "pilot_abandon_after_view";

const LABELS_KEY = "voicememory_pilot_founder_labels";
const LAST_PILOT_VIEW_KEY = "voicememory_last_pilot_view_at";
const MAX_LABELS = 80;
const MAX_EVENTS = 200;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readLabelsRaw(): PilotFounderLabelRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(LABELS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as PilotFounderLabelRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeLabelsRaw(rows: PilotFounderLabelRecord[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(LABELS_KEY, JSON.stringify(rows.slice(-MAX_LABELS)));
}

function pushInterest(kind: PilotInterestKind, meta?: Record<string, string>): PilotInterestEvent {
  const event: PilotInterestEvent = {
    id: crypto.randomUUID(),
    kind,
    at: new Date().toISOString(),
    meta,
  };
  trackLocalEvent(kind, meta);
  return event;
}

function lastPilotViewAt(): number {
  if (!isBrowser()) return 0;
  const raw = localStorage.getItem(LAST_PILOT_VIEW_KEY);
  return raw ? Number(raw) : 0;
}

function setLastPilotViewAt(at: number): void {
  if (!isBrowser()) return;
  localStorage.setItem(LAST_PILOT_VIEW_KEY, String(at));
}

function withinHoursAfterPilot(hours: number): boolean {
  const last = lastPilotViewAt();
  if (!last) return false;
  return Date.now() - last < hours * 60 * 60 * 1000;
}

export function readPilotFounderLabels(participantId?: string): PilotFounderLabelRecord[] {
  const rows = readLabelsRaw().sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  if (!participantId) return rows;
  return rows.filter((row) => row.participantId === participantId);
}

export function savePilotFounderLabel(input: {
  participantId: string;
  label: PilotFounderLabel;
  note?: string;
}): PilotFounderLabelRecord {
  const record: PilotFounderLabelRecord = {
    id: crypto.randomUUID(),
    participantId: input.participantId,
    label: input.label,
    note: input.note?.trim() || undefined,
    createdAt: new Date().toISOString(),
  };
  writeLabelsRaw([...readLabelsRaw(), record]);
  return record;
}

export function trackPilotPageViewed(): void {
  setLastPilotViewAt(Date.now());
  pushInterest("viewed_pilot_page");
  trackLocalEvent(PILOT_PAGE_VIEW);

  if (readLastBackupAt()) {
    pushInterest("backup_before_interest", { at: readLastBackupAt()! });
  }
  if (countLocalEvents(LAUNCH_EVENTS.exportUsed) > 0) {
    pushInterest("export_before_interest", {
      count: String(countLocalEvents(LAUNCH_EVENTS.exportUsed)),
    });
  }
}

export function trackPilotPricingOpened(): void {
  pushInterest("opened_pricing_explanation");
  trackLocalEvent(PILOT_PRICING_OPEN);
}

export function trackPilotPaymentAsked(source?: string): void {
  pushInterest("asked_about_payment", { source: source ?? "pilot" });
  trackLocalEvent(PILOT_PAYMENT_ASK, { source: source ?? "pilot" });
}

export function scanPilotPostViewOutcomes(): void {
  if (!withinHoursAfterPilot(72)) return;
  const lastAt = lastPilotViewAt();

  for (const event of readRetentionLoopEvents()) {
    if (new Date(event.at).getTime() <= lastAt) continue;
    if (event.kind === "entry_revisited") {
      pushInterest("revisit_after_pilot");
      trackLocalEvent(PILOT_REVISIT_AFTER);
      break;
    }
  }

  const incidents = readStoredIncidents().filter((row) => !row.resolved);
  if (incidents.some((row) => new Date(row.detectedAt).getTime() > lastAt)) {
    pushInterest("trust_drop_after_pilot");
    trackLocalEvent(PILOT_TRUST_DROP);
  }
}

export function trackPilotAbandonment(): void {
  if (!withinHoursAfterPilot(24)) return;
  pushInterest("abandon_after_pilot");
  trackLocalEvent(PILOT_ABANDON);
}

export function buildPilotInterestReport(): PilotInterestReport {
  scanPilotPostViewOutcomes();

  const events: PilotInterestEvent[] = [];
  const localEvents = readLocalEvents();

  for (const event of localEvents) {
    const kindMap: Record<string, PilotInterestKind> = {
      [PILOT_PAGE_VIEW]: "viewed_pilot_page",
      [PILOT_PRICING_OPEN]: "opened_pricing_explanation",
      [PILOT_PAYMENT_ASK]: "asked_about_payment",
      [PILOT_REVISIT_AFTER]: "revisit_after_pilot",
      [PILOT_TRUST_DROP]: "trust_drop_after_pilot",
      [PILOT_ABANDON]: "abandon_after_pilot",
      backup_before_interest: "backup_before_interest",
      export_before_interest: "export_before_interest",
    };

    const kind = kindMap[event.name];
    if (kind) {
      events.push({
        id: event.at,
        kind,
        at: event.at,
        meta: event.meta,
      });
    }
  }

  const founderLabels = readPilotFounderLabels();

  return {
    generatedAt: new Date().toISOString(),
    hasData: events.length > 0 || founderLabels.length > 0,
    events: events.slice(-MAX_EVENTS),
    founderLabels,
    summary: {
      pageViews: events.filter((e) => e.kind === "viewed_pilot_page").length,
      pricingOpens: events.filter((e) => e.kind === "opened_pricing_explanation").length,
      paymentQuestions: events.filter((e) => e.kind === "asked_about_payment").length,
      revisitAfterPilot: events.filter((e) => e.kind === "revisit_after_pilot").length,
      trustDrops: events.filter((e) => e.kind === "trust_drop_after_pilot").length,
      abandons: events.filter((e) => e.kind === "abandon_after_pilot").length,
    },
  };
}

export function latestPilotFounderLabel(
  participantId: string = getOrCreateParticipantId(),
): PilotFounderLabel | null {
  return readPilotFounderLabels(participantId)[0]?.label ?? null;
}
