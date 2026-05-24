import { readLocalEvents } from "@/lib/local-analytics";
import { getAllBookmarks, getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { formatEntryDate } from "@/lib/utils";
import { getEntry } from "@/lib/storage";
import type { CallbackInteractionSignals, CallbackRetentionSummary } from "@/types/callback-quality-review";

const INTERACTION_KEY = "voicememory_callback_interactions";
const FOLLOWUP_KEY = "voicememory_followup_continuations";
const RETENTION_KEY = "voicememory_callback_retention";

export type CallbackRetentionOutcome =
  | "surfaced"
  | "ignored"
  | "reread"
  | "revisit"
  | "recording"
  | "bookmark"
  | "copied";

interface CallbackRetentionRecord {
  callbackId: string;
  outcome: CallbackRetentionOutcome;
  at: string;
}

interface InteractionStore {
  entries: EntryInteractionRecord[];
  followups: Array<{ noteId: string; continuedAt: string }>;
  retention: CallbackRetentionRecord[];
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

interface EntryInteractionRecord {
  entryId: string;
  viewCount: number;
  totalDwellMs: number;
  lastViewedAt: string;
}

function readStore(): InteractionStore {
  if (!isBrowser()) return { entries: [], followups: [], retention: [] };
  try {
    const raw = localStorage.getItem(INTERACTION_KEY);
    if (!raw) return { entries: [], followups: [], retention: [] };
    const parsed = JSON.parse(raw) as Partial<InteractionStore>;
    return {
      entries: Array.isArray(parsed.entries) ? parsed.entries : [],
      followups: Array.isArray(parsed.followups) ? parsed.followups : [],
      retention: Array.isArray(parsed.retention) ? parsed.retention : [],
    };
  } catch {
    return { entries: [], followups: [], retention: [] };
  }
}

function writeStore(store: InteractionStore): void {
  if (!isBrowser()) return;
  localStorage.setItem(
    INTERACTION_KEY,
    JSON.stringify({
      entries: store.entries.slice(-400),
      followups: store.followups.slice(-200),
      retention: store.retention.slice(-600),
    }),
  );
}

export function recordEntryView(entryId: string): void {
  if (!isBrowser()) return;
  const store = readStore();
  const now = new Date().toISOString();
  const existing = store.entries.find((row) => row.entryId === entryId);
  if (existing) {
    existing.viewCount += 1;
    existing.lastViewedAt = now;
  } else {
    store.entries.push({ entryId, viewCount: 1, totalDwellMs: 0, lastViewedAt: now });
  }
  writeStore(store);
}

export function recordEntryDwell(entryId: string, dwellMs: number): void {
  if (!isBrowser() || dwellMs <= 0) return;
  const store = readStore();
  const existing = store.entries.find((row) => row.entryId === entryId);
  if (existing) {
    existing.totalDwellMs += dwellMs;
  } else {
    store.entries.push({
      entryId,
      viewCount: 1,
      totalDwellMs: dwellMs,
      lastViewedAt: new Date().toISOString(),
    });
  }
  writeStore(store);
}

export function recordFollowupContinued(noteId: string): void {
  if (!isBrowser()) return;
  const store = readStore();
  store.followups.push({ noteId, continuedAt: new Date().toISOString() });
  writeStore(store);
}

function pushRetention(callbackId: string, outcome: CallbackRetentionOutcome): void {
  if (!isBrowser()) return;
  const store = readStore();
  store.retention.push({ callbackId, outcome, at: new Date().toISOString() });
  writeStore(store);
}

export function recordCallbackSurfaced(callbackId: string): void {
  pushRetention(callbackId, "surfaced");
}

export function recordCallbackIgnored(callbackId: string): void {
  pushRetention(callbackId, "ignored");
}

export function recordRecordingAfterCallback(callbackId: string): void {
  pushRetention(callbackId, "recording");
}

export function readCallbackRetention(callbackId: string): CallbackRetentionRecord[] {
  return readStore().retention.filter((row) => row.callbackId === callbackId);
}

export function summarizeCallbackRetention(
  callbackId: string,
  entryIds: string[] = [],
): CallbackRetentionSummary {
  const records = readCallbackRetention(callbackId);
  const signals = callbackInteractionSignals(callbackId, entryIds);
  const count = (outcome: CallbackRetentionOutcome) =>
    records.filter((row) => row.outcome === outcome).length;

  return {
    surfaced: count("surfaced"),
    ignored: count("ignored"),
    reread: Math.max(count("reread"), signals.rereadCount),
    revisit: Math.max(count("revisit"), signals.revisitCount),
    recording: count("recording"),
    bookmark: Math.max(count("bookmark"), signals.bookmarked ? 1 : 0),
    copied: Math.max(count("copied"), signals.memoryMomentCopied ? 1 : 0),
  };
}

export function clearCallbackInteractionSignals(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(INTERACTION_KEY);
  localStorage.removeItem(FOLLOWUP_KEY);
}

function memoryMomentCopiedForEntries(entryIds: string[]): boolean {
  const idSet = new Set(entryIds);
  return readLocalEvents().some((event) => {
    if (event.name !== "memory_moment_copied") return false;
    const sourceId = event.meta?.sourceId;
    if (sourceId && idSet.has(sourceId)) return true;
    return false;
  });
}

export function averageEntryDwellMs(entryIds: string[]): number {
  const store = readStore();
  const linked = store.entries.filter((row) => entryIds.includes(row.entryId));
  const totalViews = linked.reduce((sum, row) => sum + row.viewCount, 0);
  const totalDwell = linked.reduce((sum, row) => sum + row.totalDwellMs, 0);
  return totalViews > 0 ? Math.round(totalDwell / totalViews) : 0;
}

export function callbackInteractionSignals(
  callbackId: string,
  entryIds: string[],
): CallbackInteractionSignals {
  const store = readStore();
  const bookmarks = getAllBookmarks();
  const linked = store.entries.filter((row) => entryIds.includes(row.entryId));

  const rereadCount = linked.reduce(
    (sum, row) => sum + Math.max(0, row.viewCount - 1),
    0,
  );
  const revisitCount = linked.filter((row) => row.viewCount > 1).length;
  const dwellMs = linked.reduce((sum, row) => sum + row.totalDwellMs, 0);

  const bookmarkTypes = bookmarks
    .filter((bookmark) => entryIds.includes(bookmark.entryId))
    .map((bookmark) => bookmark.type);

  const continuedFollowup =
    store.followups.some((row) => row.noteId === callbackId) ||
    store.followups.some((row) => entryIds.some((id) => row.noteId.includes(id)));

  return {
    rereadCount,
    revisitCount,
    bookmarked: bookmarkTypes.length > 0,
    bookmarkTypes,
    memoryMomentCopied: memoryMomentCopiedForEntries([callbackId, ...entryIds]),
    dwellMs,
    followupContinued: continuedFollowup,
  };
}

export function entryInteractionSummary(entryId: string): EntryInteractionRecord | null {
  return readStore().entries.find((row) => row.entryId === entryId) ?? null;
}

export function revisitedEntryCount(): number {
  if (!isBrowser()) return 0;
  return readStore().entries.filter((row) => row.viewCount > 1).length;
}

export function buildSourceEntrySnippet(entryId: string): string {
  const entry = getEntry(entryId);
  if (!entry) return "";
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

export function buildSourceEntry(entryId: string) {
  const entry = getEntry(entryId);
  if (!entry) return null;
  return {
    id: entryId,
    dateLabel: formatEntryDate(entry.createdAt),
    snippet: buildSourceEntrySnippet(entryId),
    href: `/entry/${entryId}`,
  };
}

export function bookmarkLabelForEntry(entryId: string): string | null {
  const bookmark = getBookmarkForEntry(entryId);
  return bookmark?.type ?? null;
}
