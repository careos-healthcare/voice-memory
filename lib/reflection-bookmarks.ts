import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type {
  ReflectionBookmark,
  ReflectionBookmarkType,
  ReflectionBookmarkWithEntry,
} from "@/types/reflection-bookmark";

const BOOKMARKS_KEY = "voicememory_reflection_bookmarks";
export const BOOKMARK_CHANGE_EVENT = "voicememory-bookmarks-changed";

const TYPE_LABELS: Record<ReflectionBookmarkType, string> = {
  mattered: "Mattered",
  revisit_later: "Revisit later",
  changed_something: "Changed something",
};

const TYPE_COPY: Record<ReflectionBookmarkType, string> = {
  mattered: "This mattered.",
  revisit_later: "To revisit later.",
  changed_something: "Something changed here.",
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readBookmarks(): ReflectionBookmark[] {
  if (!isBrowser()) return [];

  try {
    const raw = localStorage.getItem(BOOKMARKS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ReflectionBookmark[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (bookmark) =>
        typeof bookmark.entryId === "string" &&
        typeof bookmark.type === "string" &&
        typeof bookmark.markedAt === "string",
    );
  } catch {
    return [];
  }
}

function writeBookmarks(bookmarks: ReflectionBookmark[]): void {
  if (!isBrowser()) return;
  localStorage.setItem(BOOKMARKS_KEY, JSON.stringify(bookmarks));
}

export function dispatchBookmarkChange(): void {
  if (!isBrowser()) return;
  window.dispatchEvent(new CustomEvent(BOOKMARK_CHANGE_EVENT));
}

export function getAllBookmarks(): ReflectionBookmark[] {
  return readBookmarks().sort(
    (a, b) => new Date(b.markedAt).getTime() - new Date(a.markedAt).getTime(),
  );
}

export function getBookmarkForEntry(entryId: string): ReflectionBookmark | null {
  return readBookmarks().find((bookmark) => bookmark.entryId === entryId) ?? null;
}

export function isEntryBookmarked(entryId: string): boolean {
  return getBookmarkForEntry(entryId) !== null;
}

export function getBookmarkedEntryIds(): Set<string> {
  return new Set(readBookmarks().map((bookmark) => bookmark.entryId));
}

export function setBookmark(
  entryId: string,
  type: ReflectionBookmarkType,
): ReflectionBookmark {
  const bookmarks = readBookmarks().filter((bookmark) => bookmark.entryId !== entryId);
  const next: ReflectionBookmark = {
    entryId,
    type,
    markedAt: new Date().toISOString(),
  };
  writeBookmarks([next, ...bookmarks]);
  dispatchBookmarkChange();
  return next;
}

export function removeBookmark(entryId: string): void {
  const bookmarks = readBookmarks().filter((bookmark) => bookmark.entryId !== entryId);
  writeBookmarks(bookmarks);
  dispatchBookmarkChange();
}

export function clearAllBookmarks(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(BOOKMARKS_KEY);
  dispatchBookmarkChange();
}

export function formatBookmarkTypeLabel(type: ReflectionBookmarkType): string {
  return TYPE_LABELS[type];
}

export function bookmarkTypeCopy(type: ReflectionBookmarkType): string {
  return TYPE_COPY[type];
}

function entrySnippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

export function listBookmarksWithEntries(
  entries: JournalEntry[],
): ReflectionBookmarkWithEntry[] {
  const entryMap = new Map(entries.map((entry) => [entry.id, entry]));
  return getAllBookmarks()
    .map((bookmark) => {
      const entry = entryMap.get(bookmark.entryId);
      if (!entry) return null;
      return {
        ...bookmark,
        dateLabel: formatEntryDate(entry.createdAt),
        snippet: entrySnippet(entry),
        href: `/entry/${entry.id}`,
      };
    })
    .filter((item): item is ReflectionBookmarkWithEntry => item !== null);
}

export function bookmarksByType(
  bookmarks: ReflectionBookmarkWithEntry[],
): Record<ReflectionBookmarkType, ReflectionBookmarkWithEntry[]> {
  return {
    mattered: bookmarks.filter((bookmark) => bookmark.type === "mattered"),
    revisit_later: bookmarks.filter((bookmark) => bookmark.type === "revisit_later"),
    changed_something: bookmarks.filter(
      (bookmark) => bookmark.type === "changed_something",
    ),
  };
}
