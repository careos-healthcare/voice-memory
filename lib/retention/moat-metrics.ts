import {
  buildRetentionLoopReport,
  resolveNoteContext,
} from "@/lib/retention/retention-loops";
import { getAllEntries } from "@/lib/storage";
import type { RevisitSource } from "@/lib/refinement/revisit-experience";
import type { JournalEntry } from "@/types/journal";

export interface MoatOldEntryRevisit {
  id: string;
  at: string;
  entryId: string;
  sources: string;
  fromMemoryLine: boolean;
  noteId?: string;
  noteText?: string;
  hadThenVsNow: boolean;
  audioReplayed: boolean;
  bookmarkBeforeRecording: boolean;
  copyBeforeRecording: boolean;
  reflectionEntryId?: string;
  reflectionAt?: string;
}

export interface MoatFunnelRow {
  label: string;
  count: number;
  rateFromPrior: string | null;
}

export interface MoatMemoryLineRow {
  noteId: string;
  noteText: string;
  revisitCount: number;
  reflectionCount: number;
  conversionRate: string;
}

export interface MoatTargetRow {
  label: string;
  current: string;
  target: string;
  currentValue: number;
  targetValue: number;
  met: boolean;
}

export interface MoatMetricsReport {
  revisits: MoatOldEntryRevisit[];
  oldEntryRevisitCount: number;
  oldEntriesInArchive: number;
  oldEntryRevisitRate: string;
  revisitToReflection24h: string;
  revisitToReflection7d: string;
  revisitToReflection24hCount: number;
  revisitToReflection7dCount: number;
  memoryLineToOldEntryOpenRate: string;
  memoryLineToOldEntryOpenCount: number;
  memoryLineClickCount: number;
  targets: MoatTargetRow[];
  memoryLineFunnel: MoatFunnelRow[];
  thenVsNowFunnel: MoatFunnelRow[];
  audioReplayFunnel: MoatFunnelRow[];
  bookmarkCopyFunnel: MoatFunnelRow[];
  topMemoryLines: MoatMemoryLineRow[];
  hasData: boolean;
}

const MOAT_KEY = "voicememory_moat_revisits";
const MOAT_SESSION_KEY = "voicememory_moat_active_revisit";
const MAX_REVISITS = 600;
const MS_24H = 24 * 60 * 60 * 1000;
const MS_7D = 7 * MS_24H;

export const MOAT_TARGET_OLD_ENTRY_REVISIT_RATE = 30;
export const MOAT_TARGET_REVISIT_TO_REFLECTION_7D = 12;
export const MOAT_TARGET_MEMORY_LINE_OPEN_RATE = 20;

function parsePct(value: string): number {
  const n = Number.parseInt(value.replace("%", ""), 10);
  return Number.isFinite(n) ? n : 0;
}

function memoryLineOpenStats(): { opens: number; clicks: number; rate: string } {
  const report = buildRetentionLoopReport();
  const opens = report.notesCausingRevisits.reduce(
    (sum, row) => sum + row.oldEntryOpens,
    0,
  );
  const clicks = report.notesCausingRevisits.reduce(
    (sum, row) => sum + row.clicks + row.oldEntryOpens,
    0,
  );
  return {
    opens,
    clicks,
    rate: pct(opens, Math.max(1, clicks)),
  };
}

function buildTargetRows(report: {
  oldEntryRevisitRate: string;
  revisitToReflection7d: string;
  memoryLineToOldEntryOpenRate: string;
}): MoatTargetRow[] {
  const revisitRate = parsePct(report.oldEntryRevisitRate);
  const reflectionRate = parsePct(report.revisitToReflection7d);
  const memoryLineRate = parsePct(report.memoryLineToOldEntryOpenRate);

  return [
    {
      label: "Old-entry revisit rate",
      current: report.oldEntryRevisitRate,
      target: `${MOAT_TARGET_OLD_ENTRY_REVISIT_RATE}%`,
      currentValue: revisitRate,
      targetValue: MOAT_TARGET_OLD_ENTRY_REVISIT_RATE,
      met: revisitRate >= MOAT_TARGET_OLD_ENTRY_REVISIT_RATE,
    },
    {
      label: "Revisit → new reflection (7d)",
      current: report.revisitToReflection7d,
      target: `${MOAT_TARGET_REVISIT_TO_REFLECTION_7D}%`,
      currentValue: reflectionRate,
      targetValue: MOAT_TARGET_REVISIT_TO_REFLECTION_7D,
      met: reflectionRate >= MOAT_TARGET_REVISIT_TO_REFLECTION_7D,
    },
    {
      label: "Memory note → old entry open",
      current: report.memoryLineToOldEntryOpenRate,
      target: `${MOAT_TARGET_MEMORY_LINE_OPEN_RATE}%`,
      currentValue: memoryLineRate,
      targetValue: MOAT_TARGET_MEMORY_LINE_OPEN_RATE,
      met: memoryLineRate >= MOAT_TARGET_MEMORY_LINE_OPEN_RATE,
    },
  ];
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readRevisits(): MoatOldEntryRevisit[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(MOAT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as MoatOldEntryRevisit[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRevisits(revisits: MoatOldEntryRevisit[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(MOAT_KEY, JSON.stringify(revisits.slice(-MAX_REVISITS)));
}

function setActiveSession(revisitId: string, entryId: string): void {
  if (!isBrowser()) return;
  sessionStorage.setItem(
    MOAT_SESSION_KEY,
    JSON.stringify({ revisitId, entryId, startedAt: new Date().toISOString() }),
  );
}

function readActiveSession(): { revisitId: string; entryId: string } | null {
  if (!isBrowser()) return null;
  try {
    const raw = sessionStorage.getItem(MOAT_SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { revisitId: string; entryId: string };
    if (!parsed.revisitId || !parsed.entryId) return null;
    return parsed;
  } catch {
    return null;
  }
}

function updateRevisit(
  revisitId: string,
  patch: Partial<MoatOldEntryRevisit>,
): MoatOldEntryRevisit | null {
  const revisits = readRevisits();
  const index = revisits.findIndex((row) => row.id === revisitId);
  if (index < 0) return null;
  revisits[index] = { ...revisits[index], ...patch };
  writeRevisits(revisits);
  return revisits[index];
}

function updateActiveRevisit(
  entryId: string,
  patch: Partial<MoatOldEntryRevisit>,
): void {
  const session = readActiveSession();
  if (!session || session.entryId !== entryId) return;
  updateRevisit(session.revisitId, patch);
}

export function isOldEntryForMoat(entryId: string, entries: JournalEntry[]): boolean {
  if (entries.length <= 1) return false;
  const entry = entries.find((row) => row.id === entryId);
  if (!entry) return false;

  const sorted = [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  if (sorted[0]?.id !== entryId) return true;

  const ageMs = Date.now() - new Date(entry.createdAt).getTime();
  return ageMs >= MS_24H;
}

function memoryLineSources(sources: RevisitSource[]): boolean {
  return sources.some((source) =>
    ["memory_note", "resurfacing", "revisitation", "memory", "monthly"].includes(source),
  );
}

export function trackOldEntryMoatRevisit(
  entryId: string,
  sources: RevisitSource[],
): MoatOldEntryRevisit | null {
  if (!isBrowser()) return null;

  const entries = getAllEntries();
  if (!isOldEntryForMoat(entryId, entries)) return null;

  const { noteId, noteText } = resolveNoteContext(entryId);
  const fromMemoryLine = memoryLineSources(sources) || Boolean(noteId);

  const row: MoatOldEntryRevisit = {
    id: `moat-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    at: new Date().toISOString(),
    entryId,
    sources: sources.join(","),
    fromMemoryLine,
    noteId,
    noteText,
    hadThenVsNow: false,
    audioReplayed: false,
    bookmarkBeforeRecording: false,
    copyBeforeRecording: false,
  };

  const revisits = readRevisits();
  revisits.push(row);
  writeRevisits(revisits);
  setActiveSession(row.id, entryId);
  return row;
}

export function markMoatRevisitThenVsNow(entryId: string): void {
  updateActiveRevisit(entryId, { hadThenVsNow: true });
}

export function markMoatRevisitAudioReplayed(entryId: string): void {
  updateActiveRevisit(entryId, { audioReplayed: true });
}

export function markMoatRevisitBookmark(entryId: string): void {
  updateActiveRevisit(entryId, { bookmarkBeforeRecording: true });
}

export function markMoatRevisitCopy(entryId: string): void {
  updateActiveRevisit(entryId, { copyBeforeRecording: true });
}

function msBetween(isoA: string, isoB: string): number {
  return new Date(isoB).getTime() - new Date(isoA).getTime();
}

function attachReflectionToRevisit(
  revisit: MoatOldEntryRevisit,
  reflectionEntryId: string,
  reflectionAt: string,
): MoatOldEntryRevisit {
  if (revisit.reflectionEntryId) return revisit;
  const delta = msBetween(revisit.at, reflectionAt);
  if (delta < 0 || delta > MS_7D) return revisit;
  return {
    ...revisit,
    reflectionEntryId,
    reflectionAt,
  };
}

/** Link a newly saved reflection to the most recent open old-entry revisit. */
export function trackMoatNewReflection(reflectionEntryId: string, reflectionAt?: string): void {
  if (!isBrowser()) return;

  const at = reflectionAt ?? new Date().toISOString();
  const revisits = readRevisits();
  let changed = false;

  const session = readActiveSession();
  if (session) {
    const index = revisits.findIndex((row) => row.id === session.revisitId);
    if (index >= 0 && !revisits[index].reflectionEntryId) {
      const updated = attachReflectionToRevisit(revisits[index], reflectionEntryId, at);
      if (updated.reflectionEntryId) {
        revisits[index] = updated;
        changed = true;
      }
    }
  }

  if (!changed) {
    const candidates = revisits
      .filter((row) => !row.reflectionEntryId)
      .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime());

    for (const revisit of candidates) {
      const delta = msBetween(revisit.at, at);
      if (delta >= 0 && delta <= MS_7D) {
        const index = revisits.findIndex((row) => row.id === revisit.id);
        if (index >= 0) {
          revisits[index] = attachReflectionToRevisit(revisits[index], reflectionEntryId, at);
          changed = true;
          break;
        }
      }
    }
  }

  if (changed) writeRevisits(revisits);
}

function pct(count: number, total: number): string {
  if (total <= 0) return "—";
  return `${Math.round((count / total) * 100)}%`;
}

function funnelRate(count: number, prior: number): string | null {
  if (prior <= 0) return null;
  return pct(count, prior);
}

function reflectedWithin(revisit: MoatOldEntryRevisit, windowMs: number): boolean {
  if (!revisit.reflectionAt) return false;
  return msBetween(revisit.at, revisit.reflectionAt) <= windowMs;
}

function buildFunnel(
  revisits: MoatOldEntryRevisit[],
  filter: (row: MoatOldEntryRevisit) => boolean,
  label: string,
): MoatFunnelRow[] {
  const subset = revisits.filter(filter);
  const withReflection = subset.filter((row) => Boolean(row.reflectionEntryId));
  const within7d = withReflection.filter((row) => reflectedWithin(row, MS_7D));

  return [
    {
      label: `${label} revisits`,
      count: subset.length,
      rateFromPrior: null,
    },
    {
      label: `${label} → new reflection (7d)`,
      count: within7d.length,
      rateFromPrior: funnelRate(within7d.length, subset.length),
    },
  ];
}

function buildTopMemoryLines(revisits: MoatOldEntryRevisit[]): MoatMemoryLineRow[] {
  const map = new Map<string, MoatMemoryLineRow>();

  for (const revisit of revisits) {
    if (!revisit.fromMemoryLine) continue;
    const key = revisit.noteId ?? revisit.noteText ?? "unknown";
    const label = revisit.noteText?.trim() || revisit.noteId || "unknown";
    const existing = map.get(key) ?? {
      noteId: revisit.noteId ?? key,
      noteText: label,
      revisitCount: 0,
      reflectionCount: 0,
      conversionRate: "—",
    };
    existing.revisitCount += 1;
    if (revisit.reflectionEntryId && reflectedWithin(revisit, MS_7D)) {
      existing.reflectionCount += 1;
    }
    map.set(key, existing);
  }

  return [...map.values()]
    .map((row) => ({
      ...row,
      conversionRate: pct(row.reflectionCount, row.revisitCount),
    }))
    .sort((a, b) => b.reflectionCount - a.reflectionCount || b.revisitCount - a.revisitCount)
    .slice(0, 12);
}

export function buildMoatMetricsReport(): MoatMetricsReport {
  const revisits = readRevisits();
  const entries = getAllEntries();
  const oldEntriesInArchive = Math.max(
    0,
    entries.filter((entry) => isOldEntryForMoat(entry.id, entries)).length,
  );

  const withReflection7d = revisits.filter(
    (row) => row.reflectionEntryId && reflectedWithin(row, MS_7D),
  );
  const withReflection24h = revisits.filter(
    (row) => row.reflectionEntryId && reflectedWithin(row, MS_24H),
  );

  const bookmarkOrCopy = (row: MoatOldEntryRevisit) =>
    row.bookmarkBeforeRecording || row.copyBeforeRecording;

  const memoryLineStats = memoryLineOpenStats();
  const oldEntryRevisitRate = pct(revisits.length, Math.max(1, oldEntriesInArchive));
  const revisitToReflection7d = pct(withReflection7d.length, Math.max(1, revisits.length));

  return {
    revisits,
    oldEntryRevisitCount: revisits.length,
    oldEntriesInArchive,
    oldEntryRevisitRate,
    revisitToReflection24h: pct(withReflection24h.length, Math.max(1, revisits.length)),
    revisitToReflection7d,
    revisitToReflection24hCount: withReflection24h.length,
    revisitToReflection7dCount: withReflection7d.length,
    memoryLineToOldEntryOpenRate: memoryLineStats.rate,
    memoryLineToOldEntryOpenCount: memoryLineStats.opens,
    memoryLineClickCount: memoryLineStats.clicks,
    targets: buildTargetRows({
      oldEntryRevisitRate,
      revisitToReflection7d,
      memoryLineToOldEntryOpenRate: memoryLineStats.rate,
    }),
    memoryLineFunnel: buildFunnel(revisits, (row) => row.fromMemoryLine, "Memory line"),
    thenVsNowFunnel: buildFunnel(revisits, (row) => row.hadThenVsNow, "Then vs now"),
    audioReplayFunnel: buildFunnel(revisits, (row) => row.audioReplayed, "Audio replay"),
    bookmarkCopyFunnel: buildFunnel(revisits, bookmarkOrCopy, "Bookmark / copy"),
    topMemoryLines: buildTopMemoryLines(revisits),
    hasData: revisits.length > 0 || entries.length > 0,
  };
}

export function readMoatRevisits(): MoatOldEntryRevisit[] {
  return readRevisits();
}

export function clearMoatMetrics(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(MOAT_KEY);
  sessionStorage.removeItem(MOAT_SESSION_KEY);
}
