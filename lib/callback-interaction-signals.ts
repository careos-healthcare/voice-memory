import { readLocalEvents } from "@/lib/local-analytics";
import { getAllBookmarks, getBookmarkForEntry } from "@/lib/reflection-bookmarks";
import { formatEntryDate } from "@/lib/utils";
import { getEntry } from "@/lib/storage";
import type { CallbackInteractionSignals } from "@/types/callback-quality-review";

const INTERACTION_KEY = "voicememory_callback_interactions";
const FOLLOWUP_KEY = "voicememory_followup_continuations";

interface EntryInteractionRecord {
  entryId: string;
  viewCount: number;
  totalDwellMs: number;
  lastViewedAt: string;
}

interface InteractionStore {
  entries: EntryInteractionRecord[];
  followups: Array<{ noteId: string; continuedAt: string }>;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readStore(): InteractionStore {
  if (!isBrowser()) return { entries: [], followups: [] };
  try {
    const raw = localStorage.getItem(INTERACTION_KEY);
    if (!raw) return { entries: [], followups: [] };
    const parsed = JSON.parse(raw) as Partial<InteractionStore>;
    return {
      entries: Array.isArray(parsed.entries) ? parsed.entries : [],
      followups: Array.isArray(parsed.followups) ? parsed.followups : [],
    };
  } catch {
    return { entries: [], followups: [] };
  }
}

function writeStore(store: InteractionStore): void {
  if (!isBrowser()) return;
  localStorage.setItem(
    INTERACTION_KEY,
    JSON.stringify({
      entries: store.entries.slice(-400),
      followups: store.followups.slice(-200),
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
