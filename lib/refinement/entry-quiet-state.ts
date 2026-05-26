import { CONFIDENCE_STRONG_MIN } from "@/lib/revisit/resurfacing-confidence";
import type { MemoryNote } from "@/types/memory-note";

/** Post-record quiet window — progressive disclosure on the entry page. */
export const FRESH_ENTRY_QUIET_WINDOW_MS = 15 * 60 * 1000;

const FRESH_ENTRY_KEY = "voicememory_fresh_entry";
const DISMISS_PREFIX = "voicememory_fresh_entry_dismissed:";

interface FreshEntryRecord {
  entryId: string;
  recordedAt: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function markFreshEntryAfterRecording(entryId: string): void {
  if (!isBrowser()) return;
  const record: FreshEntryRecord = { entryId, recordedAt: Date.now() };
  sessionStorage.setItem(FRESH_ENTRY_KEY, JSON.stringify(record));
}

export function dismissFreshEntryQuietMode(entryId: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(`${DISMISS_PREFIX}${entryId}`, "1");
}

function readFreshEntryRecord(): FreshEntryRecord | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(FRESH_ENTRY_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<FreshEntryRecord>;
    if (!parsed.entryId || typeof parsed.recordedAt !== "number") return null;
    return { entryId: parsed.entryId, recordedAt: parsed.recordedAt };
  } catch {
    return null;
  }
}

function isDismissed(entryId: string): boolean {
  if (!isBrowser()) return false;
  return sessionStorage.getItem(`${DISMISS_PREFIX}${entryId}`) === "1";
}

export function isWithinFreshEntryWindow(createdAt: string, now = Date.now()): boolean {
  const createdMs = new Date(createdAt).getTime();
  if (!Number.isFinite(createdMs)) return false;
  return now - createdMs <= FRESH_ENTRY_QUIET_WINDOW_MS;
}

/** Fresh entry quiet mode — newly recorded or opened soon after recording. */
export function isFreshEntryQuietMode(entryId: string, createdAt: string): boolean {
  if (!isWithinFreshEntryWindow(createdAt)) return false;
  if (isDismissed(entryId)) return false;

  const record = readFreshEntryRecord();
  if (record?.entryId === entryId) {
    return Date.now() - record.recordedAt <= FRESH_ENTRY_QUIET_WINDOW_MS;
  }

  return isWithinFreshEntryWindow(createdAt);
}

/** One continuity line — only when evidence is strong enough to feel earned. */
export function pickEvidenceBackedEntryMoment(
  note: MemoryNote | null | undefined,
): MemoryNote | null {
  if (!note) return null;
  if (note.confidence < CONFIDENCE_STRONG_MIN) return null;
  return note;
}
