import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import {
  BELIEF_RECALL_COOLDOWN_MS,
  BELIEF_RECALL_DELAY_MS,
} from "@/lib/retention/belief-recall-copy";
import { trackBeliefRecallLevel, trackBeliefRecallNote } from "@/lib/metrics/belief-recall-events";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { BeliefRecallLevelId, BeliefRecallRecord } from "@/types/belief-recall";
import type { JournalEntry } from "@/types/journal";

export const BELIEF_RECALL_LAST_SHOWN_KEY = "voicememory_belief_recall_last_shown";
export const BELIEF_RECALL_RECORDS_KEY = "voicememory_belief_recall_records";
export const BELIEF_RECALL_PENDING_NOTE_KEY = "voicememory_belief_recall_pending_note";
export const BELIEF_RECALL_ANCHOR_KEY = "voicememory_belief_recall_anchor_at";

const MAX_RECORDS = 80;

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function readRecords(): BeliefRecallRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(BELIEF_RECALL_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as BeliefRecallRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRecords(rows: BeliefRecallRecord[]): void {
  getStorage()?.setItem(BELIEF_RECALL_RECORDS_KEY, JSON.stringify(rows.slice(-MAX_RECORDS)));
}

/** Call when user views a working belief or blind spot — starts 7-day recall window. */
export function markBeliefRecallAnchor(theoryId: string): void {
  getStorage()?.setItem(
    BELIEF_RECALL_ANCHOR_KEY,
    JSON.stringify({ theoryId, anchoredAt: new Date().toISOString() }),
  );
}

function readAnchor(): { theoryId: string; anchoredAt: string } | null {
  const store = getStorage();
  if (!store) return null;
  try {
    const raw = store.getItem(BELIEF_RECALL_ANCHOR_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { theoryId: string; anchoredAt: string };
    if (!parsed.theoryId || !parsed.anchoredAt) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function canShowBeliefRecallPrompt(now = Date.now()): boolean {
  const store = getStorage();
  if (!store) return false;

  const belief = buildArchiveBeliefView(getMemoryEligibleEntries());
  if (!belief) return false;

  const anchor = readAnchor();
  if (!anchor || anchor.theoryId !== belief.theoryId) {
    markBeliefRecallAnchor(belief.theoryId);
    return false;
  }

  const elapsed = now - new Date(anchor.anchoredAt).getTime();
  if (elapsed < BELIEF_RECALL_DELAY_MS) return false;

  const last = store.getItem(BELIEF_RECALL_LAST_SHOWN_KEY);
  if (last && now - new Date(last).getTime() < BELIEF_RECALL_COOLDOWN_MS) return false;

  const already = readRecords().some(
    (r) => r.theoryId === belief.theoryId && r.answeredAt >= anchor.anchoredAt,
  );
  return !already;
}

export function markBeliefRecallPromptShown(): void {
  getStorage()?.setItem(BELIEF_RECALL_LAST_SHOWN_KEY, new Date().toISOString());
}

export function saveBeliefRecallLevel(level: BeliefRecallLevelId): BeliefRecallRecord {
  const belief = buildArchiveBeliefView(getMemoryEligibleEntries());
  const theoryId = belief?.theoryId ?? "unknown";

  const record: BeliefRecallRecord = {
    id: newId("br"),
    level,
    answeredAt: new Date().toISOString(),
    theoryId,
  };

  const rows = readRecords();
  rows.push(record);
  writeRecords(rows);

  trackBeliefRecallLevel({ level, attributionId: record.id, theoryId });
  markBeliefRecallPromptShown();

  const store = getStorage();
  if (level === "yes_clearly" || level === "vaguely") {
    store?.setItem(
      BELIEF_RECALL_PENDING_NOTE_KEY,
      JSON.stringify({ attributionId: record.id, answered: false }),
    );
  } else {
    store?.removeItem(BELIEF_RECALL_PENDING_NOTE_KEY);
  }

  return record;
}

export function shouldShowBeliefRecallNotePrompt(): { attributionId: string } | null {
  const store = getStorage();
  if (!store) return null;
  const raw = store.getItem(BELIEF_RECALL_PENDING_NOTE_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as { attributionId: string; answered?: boolean };
    if (parsed.answered || !parsed.attributionId) return null;
    return { attributionId: parsed.attributionId };
  } catch {
    return null;
  }
}

export function saveBeliefRecallNote(note: string, attributionId: string): void {
  const trimmed = note.trim().slice(0, 500);
  const rows = readRecords();
  const idx = rows.findIndex((r) => r.id === attributionId);
  if (idx >= 0) {
    rows[idx] = {
      ...rows[idx]!,
      note: trimmed,
      followUpAnsweredAt: new Date().toISOString(),
    };
    writeRecords(rows);
  }
  trackBeliefRecallNote({ attributionId, noteLength: trimmed.length });
  getStorage()?.removeItem(BELIEF_RECALL_PENDING_NOTE_KEY);
}

export function dismissBeliefRecallPrompt(): void {
  markBeliefRecallPromptShown();
  getStorage()?.removeItem(BELIEF_RECALL_PENDING_NOTE_KEY);
}

export function dismissBeliefRecallNotePrompt(): void {
  const store = getStorage();
  if (!store) return;
  const raw = store.getItem(BELIEF_RECALL_PENDING_NOTE_KEY);
  if (!raw) return;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    store.setItem(BELIEF_RECALL_PENDING_NOTE_KEY, JSON.stringify({ ...parsed, answered: true }));
  } catch {
    store.removeItem(BELIEF_RECALL_PENDING_NOTE_KEY);
  }
}

export function readBeliefRecallRecords(): BeliefRecallRecord[] {
  return readRecords().slice().reverse();
}

export function clearBeliefRecallForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(BELIEF_RECALL_LAST_SHOWN_KEY);
  store.removeItem(BELIEF_RECALL_RECORDS_KEY);
  store.removeItem(BELIEF_RECALL_PENDING_NOTE_KEY);
  store.removeItem(BELIEF_RECALL_ANCHOR_KEY);
}

export { BELIEF_RECALL_DELAY_MS, BELIEF_RECALL_COOLDOWN_MS };
