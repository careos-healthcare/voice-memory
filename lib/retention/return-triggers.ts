import {
  LAUNCH_EVENTS,
  readLocalEvents,
  RETENTION_EVENTS,
  trackLocalEvent,
} from "@/lib/local-analytics";
import { observeMagicReturnAfterCallback } from "@/lib/retention/first-magic-moment";
import type {
  ReturnTriggerEventName,
  ReturnTriggerKind,
  ReturnTriggerReturnRow,
} from "@/types/return-triggers";

export const RETURN_TRIGGER_EVENTS = {
  returnAfterPhoto: "return_after_photo",
  returnAfterRevisit: "return_after_revisit",
  returnAfterRoundup: "return_after_roundup",
  returnAfterTerritory: "return_after_territory",
  returnAfterSilence: "return_after_silence",
  returnAfterBackup: "return_after_backup",
  returnAfterArchiveExport: "return_after_archive_export",
  returnAfterFirstCallback: "return_after_first_callback",
  returnAfterPrompt: "return_after_prompt",
  returnWithoutPrompt: "return_without_prompt",
} as const satisfies Record<string, ReturnTriggerEventName>;

/** @deprecated Use RETURN_TRIGGER_EVENTS.returnAfterSilence */
export const RETURN_AFTER_SILENCE = RETURN_TRIGGER_EVENTS.returnAfterSilence;

interface ReturnTriggerAnchor {
  id: string;
  kind: ReturnTriggerKind;
  at: string;
  meta?: Record<string, string>;
}

const ANCHORS_KEY = "voicememory_return_trigger_anchors";
const LAST_OPEN_KEY = "voicememory_return_trigger_last_open";
const RECORDED_ANCHORS_KEY = "voicememory_return_trigger_recorded";
const MAX_ANCHORS = 48;
const MIN_RETURN_GAP_HOURS = 1;
const MAX_RETURN_WINDOW_HOURS = 24 * 7;
const OUTCOME_WINDOW_HOURS = 24;

const KIND_TO_EVENT: Record<ReturnTriggerKind, ReturnTriggerEventName> = {
  photo: RETURN_TRIGGER_EVENTS.returnAfterPhoto,
  revisit: RETURN_TRIGGER_EVENTS.returnAfterRevisit,
  roundup: RETURN_TRIGGER_EVENTS.returnAfterRoundup,
  territory: RETURN_TRIGGER_EVENTS.returnAfterTerritory,
  silence: RETURN_TRIGGER_EVENTS.returnAfterSilence,
  backup: RETURN_TRIGGER_EVENTS.returnAfterBackup,
  archive_export: RETURN_TRIGGER_EVENTS.returnAfterArchiveExport,
  first_callback: RETURN_TRIGGER_EVENTS.returnAfterFirstCallback,
  prompt: RETURN_TRIGGER_EVENTS.returnAfterPrompt,
};

const REFLECTION_EVENTS = new Set([
  RETENTION_EVENTS.entryRecorded,
  LAUNCH_EVENTS.firstReflectionCreated,
  LAUNCH_EVENTS.secondReflectionCreated,
  "followup_recording_completed",
  "reflection_after_prompt",
]);

const REVISIT_EVENTS = new Set([
  "revisit_opened",
  "entry_revisited",
  RETURN_TRIGGER_EVENTS.returnAfterRevisit,
]);

const EXPORT_BACKUP_EVENTS = new Set([
  LAUNCH_EVENTS.exportUsed,
  "backup_after_premium",
  "photo_exported",
]);

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readAnchors(): ReturnTriggerAnchor[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(ANCHORS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ReturnTriggerAnchor[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAnchors(rows: ReturnTriggerAnchor[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(ANCHORS_KEY, JSON.stringify(rows.slice(-MAX_ANCHORS)));
}

function readRecordedAnchorIds(): Set<string> {
  if (!isBrowser()) return new Set();
  try {
    const raw = localStorage.getItem(RECORDED_ANCHORS_KEY);
    if (!raw) return new Set();
    const parsed = JSON.parse(raw) as string[];
    return new Set(Array.isArray(parsed) ? parsed : []);
  } catch {
    return new Set();
  }
}

function markAnchorRecorded(anchorId: string): void {
  if (!isBrowser()) return;
  const recorded = readRecordedAnchorIds();
  recorded.add(anchorId);
  localStorage.setItem(
    RECORDED_ANCHORS_KEY,
    JSON.stringify([...recorded].slice(-MAX_ANCHORS * 2)),
  );
}

function hoursBetween(fromIso: string, toMs: number): number {
  return (toMs - new Date(fromIso).getTime()) / (1000 * 60 * 60);
}

function returnWindowLabel(hoursSinceTrigger: number): "24h" | "7d" | null {
  if (hoursSinceTrigger <= 24) return "24h";
  if (hoursSinceTrigger <= MAX_RETURN_WINDOW_HOURS) return "7d";
  return null;
}

/** Register a prior surface that may explain a later return — internal only. */
export function recordReturnTriggerAnchor(
  kind: ReturnTriggerKind,
  meta?: Record<string, string>,
): void {
  if (!isBrowser()) return;
  const anchors = readAnchors();
  anchors.push({
    id: `trigger-${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
    kind,
    at: new Date().toISOString(),
    meta,
  });
  writeAnchors(anchors);
}

function pickBestAnchor(nowMs: number): ReturnTriggerAnchor | null {
  const recorded = readRecordedAnchorIds();
  const candidates = readAnchors()
    .filter((anchor) => !recorded.has(anchor.id))
    .map((anchor) => ({
      anchor,
      hoursSinceTrigger: hoursBetween(anchor.at, nowMs),
    }))
    .filter(
      ({ hoursSinceTrigger }) =>
        hoursSinceTrigger >= MIN_RETURN_GAP_HOURS &&
        hoursSinceTrigger <= MAX_RETURN_WINDOW_HOURS,
    )
    .sort((a, b) => b.anchor.at.localeCompare(a.anchor.at));

  return candidates[0]?.anchor ?? null;
}

function emitReturnAfterAnchor(
  anchor: ReturnTriggerAnchor,
  hoursSinceLastOpen: number,
  nowMs: number,
): void {
  const hoursSinceTrigger = hoursBetween(anchor.at, nowMs);
  const window = returnWindowLabel(hoursSinceTrigger);
  if (!window) return;

  trackLocalEvent(KIND_TO_EVENT[anchor.kind], {
    triggerId: anchor.id,
    triggerKind: anchor.kind,
    hoursSinceTrigger: String(Math.round(hoursSinceTrigger)),
    hoursSinceLastOpen: String(Math.round(hoursSinceLastOpen)),
    window,
    ...(anchor.meta ?? {}),
  });
  if (anchor.kind === "first_callback" && anchor.meta?.noteId) {
    observeMagicReturnAfterCallback(anchor.meta.noteId, anchor.meta.entryId);
  }
  markAnchorRecorded(anchor.id);
}

/** Detect a return visit and attribute it to the strongest recent trigger — internal only. */
export function maybeDetectReturnTriggers(): void {
  if (!isBrowser()) return;

  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const lastOpenRaw = localStorage.getItem(LAST_OPEN_KEY);
  localStorage.setItem(LAST_OPEN_KEY, nowIso);

  if (!lastOpenRaw) return;

  const hoursSinceLastOpen = hoursBetween(lastOpenRaw, nowMs);
  if (hoursSinceLastOpen < MIN_RETURN_GAP_HOURS) return;
  if (hoursSinceLastOpen > MAX_RETURN_WINDOW_HOURS) return;

  const anchor = pickBestAnchor(nowMs);
  if (anchor) {
    emitReturnAfterAnchor(anchor, hoursSinceLastOpen, nowMs);
    return;
  }

  trackLocalEvent(RETURN_TRIGGER_EVENTS.returnWithoutPrompt, {
    hoursSinceLastOpen: String(Math.round(hoursSinceLastOpen)),
    window: returnWindowLabel(hoursSinceLastOpen) ?? "7d",
  });
}

export function trackReturnAfterSilence(state: string): void {
  trackLocalEvent(RETURN_TRIGGER_EVENTS.returnAfterSilence, { state });
}

export function registerPhotoReturnTrigger(entryId: string): void {
  recordReturnTriggerAnchor("photo", { entryId });
}

export function registerRevisitReturnTrigger(entryId: string, sources = ""): void {
  recordReturnTriggerAnchor("revisit", { entryId, sources });
}

export function registerRoundupReturnTrigger(periodSlug: string): void {
  recordReturnTriggerAnchor("roundup", { periodSlug });
}

export function registerTerritoryReturnTrigger(territoryId: string, slug: string): void {
  recordReturnTriggerAnchor("territory", { territoryId, slug });
}

export function registerBackupReturnTrigger(): void {
  recordReturnTriggerAnchor("backup");
}

export function registerArchiveExportReturnTrigger(surface: string): void {
  recordReturnTriggerAnchor("archive_export", { surface });
}

export function registerFirstCallbackReturnTrigger(noteId: string, entryId: string): void {
  recordReturnTriggerAnchor("first_callback", { noteId, entryId });
}

export function registerPromptReturnTrigger(promptId: string): void {
  recordReturnTriggerAnchor("prompt", { promptId });
}

function eventAtMs(at: string): number {
  return new Date(at).getTime();
}

function hadOutcomeWithinWindow(
  returnAt: string,
  eventNames: Set<string>,
  windowHours = OUTCOME_WINDOW_HOURS,
): boolean {
  const start = eventAtMs(returnAt);
  const end = start + windowHours * 60 * 60 * 1000;
  return readLocalEvents().some((event) => {
    if (!eventNames.has(event.name)) return false;
    const at = eventAtMs(event.at);
    return at > start && at <= end;
  });
}

function hadBackupWithinWindow(returnAt: string, windowHours = OUTCOME_WINDOW_HOURS): boolean {
  if (!isBrowser()) return false;
  try {
    const raw = localStorage.getItem("voicememory_sync_last_backup_at");
    if (!raw) return false;
    const backupAt = eventAtMs(raw);
    const start = eventAtMs(returnAt);
    const end = start + windowHours * 60 * 60 * 1000;
    return backupAt > start && backupAt <= end;
  } catch {
    return false;
  }
}

export function countReturnTriggerEvents(): Record<string, number> {
  const names = Object.values(RETURN_TRIGGER_EVENTS);
  const events = readLocalEvents();
  return Object.fromEntries(
    names.map((name) => [name, events.filter((event) => event.name === name).length]),
  );
}

function resolveTriggerKind(
  eventName: string,
  rawKind?: string,
): ReturnTriggerKind | "voluntary" | null {
  if (eventName === RETURN_TRIGGER_EVENTS.returnWithoutPrompt) return "voluntary";
  if (!rawKind) return null;
  const kinds: ReturnTriggerKind[] = [
    "photo",
    "revisit",
    "roundup",
    "territory",
    "silence",
    "backup",
    "archive_export",
    "first_callback",
    "prompt",
  ];
  return kinds.includes(rawKind as ReturnTriggerKind)
    ? (rawKind as ReturnTriggerKind)
    : null;
}

export function buildReturnTriggerRows(): ReturnTriggerReturnRow[] {
  const returnNames = new Set<string>(Object.values(RETURN_TRIGGER_EVENTS));
  return readLocalEvents()
    .filter((event) => returnNames.has(event.name))
    .map((event) => {
      const hoursSinceTrigger = event.meta?.hoursSinceTrigger
        ? Number(event.meta.hoursSinceTrigger)
        : null;
      const hoursSinceLastOpen = event.meta?.hoursSinceLastOpen
        ? Number(event.meta.hoursSinceLastOpen)
        : null;

      return {
        eventName: event.name as ReturnTriggerEventName,
        at: event.at,
        triggerKind: resolveTriggerKind(event.name, event.meta?.triggerKind),
        hoursSinceTrigger,
        hoursSinceLastOpen,
        window: event.meta?.window ?? null,
        ledToReflection: hadOutcomeWithinWindow(event.at, REFLECTION_EVENTS),
        ledToRevisit: hadOutcomeWithinWindow(event.at, REVISIT_EVENTS),
        ledToExportOrBackup:
          hadOutcomeWithinWindow(event.at, EXPORT_BACKUP_EVENTS) ||
          hadBackupWithinWindow(event.at),
      };
    })
    .slice(-40)
    .reverse();
}
