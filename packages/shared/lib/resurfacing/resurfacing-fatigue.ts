import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";

const STORE_KEY = "voicememory_resurfacing_behavioral_fatigue";

export interface ResurfacingBehavioralFatigueRecord {
  noteId: string;
  ignoredCount: number;
  openedWithoutReflection: number;
  repeatedDismissals: number;
  lastShownAt: string | null;
  lastOpenedAt: string | null;
  lastReflectionAt: string | null;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readRecords(): ResurfacingBehavioralFatigueRecord[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as Partial<ResurfacingBehavioralFatigueRecord>[];
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((row) => typeof row?.noteId === "string")
      .map((row) => ({
        noteId: row.noteId!,
        ignoredCount: Number(row.ignoredCount) || 0,
        openedWithoutReflection: Number(row.openedWithoutReflection) || 0,
        repeatedDismissals: Number(row.repeatedDismissals) || 0,
        lastShownAt: typeof row.lastShownAt === "string" ? row.lastShownAt : null,
        lastOpenedAt: typeof row.lastOpenedAt === "string" ? row.lastOpenedAt : null,
        lastReflectionAt:
          typeof row.lastReflectionAt === "string" ? row.lastReflectionAt : null,
      }));
  } catch {
    return [];
  }
}

function writeRecords(records: ResurfacingBehavioralFatigueRecord[]): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(STORE_KEY, JSON.stringify(records.slice(-120)));
}

function upsert(
  noteId: string,
  patch: Partial<Omit<ResurfacingBehavioralFatigueRecord, "noteId">>,
): ResurfacingBehavioralFatigueRecord {
  const records = readRecords();
  const now = new Date().toISOString();
  const existing = records.find((row) => row.noteId === noteId);
  const next: ResurfacingBehavioralFatigueRecord = {
    noteId,
    ignoredCount: existing?.ignoredCount ?? 0,
    openedWithoutReflection: existing?.openedWithoutReflection ?? 0,
    repeatedDismissals: existing?.repeatedDismissals ?? 0,
    lastShownAt: existing?.lastShownAt ?? null,
    lastOpenedAt: existing?.lastOpenedAt ?? null,
    lastReflectionAt: existing?.lastReflectionAt ?? null,
    ...patch,
  };
  const without = records.filter((row) => row.noteId !== noteId);
  writeRecords([...without, next]);
  return next;
}

export function getResurfacingFatigueRecords(): ResurfacingBehavioralFatigueRecord[] {
  return readRecords();
}

export function getResurfacingFatigueRecord(
  noteId: string,
): ResurfacingBehavioralFatigueRecord | null {
  return readRecords().find((row) => row.noteId === noteId) ?? null;
}

export function recordResurfacingShown(noteId: string): void {
  upsert(noteId, { lastShownAt: new Date().toISOString() });
}

export function recordResurfacingIgnored(noteId: string): void {
  const row = getResurfacingFatigueRecord(noteId);
  upsert(noteId, {
    ignoredCount: (row?.ignoredCount ?? 0) + 1,
    lastShownAt: new Date().toISOString(),
  });
}

export function recordResurfacingOpened(noteId: string): void {
  upsert(noteId, { lastOpenedAt: new Date().toISOString() });
}

export function recordResurfacingOpenedWithoutReflection(noteId: string): void {
  const row = getResurfacingFatigueRecord(noteId);
  upsert(noteId, {
    openedWithoutReflection: (row?.openedWithoutReflection ?? 0) + 1,
    lastOpenedAt: new Date().toISOString(),
  });
}

export function recordResurfacingDismissed(noteId: string): void {
  const row = getResurfacingFatigueRecord(noteId);
  upsert(noteId, {
    repeatedDismissals: (row?.repeatedDismissals ?? 0) + 1,
    lastShownAt: new Date().toISOString(),
  });
}

export function recordReflectionAfterResurface(noteId: string): void {
  upsert(noteId, { lastReflectionAt: new Date().toISOString() });
}

/** Penalty applied when ranking callbacks — behavior beats poetic quality. */
export function getResurfacingFatiguePenalty(noteId: string): number {
  const row = getResurfacingFatigueRecord(noteId);
  if (!row) return 0;
  return (
    row.ignoredCount * 6 +
    row.openedWithoutReflection * 10 +
    row.repeatedDismissals * 12
  );
}

/** Suppress callbacks that keep surfacing without reflection. */
export function shouldSuppressResurfacingNote(noteId: string): boolean {
  const row = getResurfacingFatigueRecord(noteId);
  if (!row) return false;
  if (row.repeatedDismissals >= 3) return true;
  if (row.ignoredCount >= 4) return true;
  if (row.openedWithoutReflection >= 3) return true;
  if (
    row.openedWithoutReflection >= 2 &&
    row.repeatedDismissals >= 1
  ) {
    return true;
  }
  return false;
}

export function clearResurfacingBehavioralFatigue(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(STORE_KEY);
}
