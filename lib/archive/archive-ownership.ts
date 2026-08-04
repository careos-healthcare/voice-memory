import { listAudioEntryIds } from "@/lib/audio-storage";
import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { LAUNCH_EVENTS, hasLocalEvent } from "@/lib/local-analytics";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { readLastBackupAt } from "@/lib/sync/status-storage";
import { getAllEntries } from "@/lib/storage";
import type {
  ArchiveOwnershipBookmarkRef,
  ArchiveOwnershipEntryRef,
  ArchiveOwnershipLines,
  ArchiveOwnershipLink,
  ArchiveOwnershipReport,
} from "@/types/archive-ownership";
import type { JournalEntry } from "@/types/journal";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";

/** Quiet ownership copy — no stats, streaks, or achievement language. */
export const ARCHIVE_OWNERSHIP_COPY = {
  belongsToYou: "This belongs to you.",
  takeWithYou: "You can take this with you.",
  oldestStillHere: "Your oldest saved moment is still here.",
  firstRecordingStillHere: "Your first recording is still here.",
  earlyBookmarkStillHere: "An early bookmark is still here.",
  markedWhereChanged: "You marked where something changed.",
  backupRecoverable: "Your backup keeps this recoverable.",
  exportPortable: "You can export your archive anytime — it stays portable.",
  signInForBackup: "Sign in on Account if you want encrypted backup across devices.",
  sparseHome: "Your saved moments stay here until you choose to take them with you.",
} as const;

const SPARSE_ENTRY_MAX = 2;
const MONTH_SPAN_MIN = 2;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function monthKey(iso: string): string {
  const date = new Date(iso);
  return `${date.getFullYear()}-${date.getMonth()}`;
}

function formatReachBackMonth(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const sameYear = date.getFullYear() === now.getFullYear();
  return new Intl.DateTimeFormat("en-US", {
    month: "long",
    ...(sameYear ? {} : { year: "numeric" }),
  }).format(date);
}

function countMonthsRepresented(entries: JournalEntry[]): number {
  return new Set(entries.map((entry) => monthKey(entry.createdAt))).size;
}

function oldestReflection(entries: JournalEntry[]): ArchiveOwnershipEntryRef | null {
  const first = sortedEntries(entries)[0];
  if (!first) return null;
  return { entryId: first.id, createdAt: first.createdAt };
}

function firstSavedAudio(
  entries: JournalEntry[],
  audioIds: Set<string>,
): ArchiveOwnershipEntryRef | null {
  const withAudio = sortedEntries(entries).filter(
    (entry) => entry.audioId && audioIds.has(entry.id),
  );
  const first = withAudio[0];
  if (!first) return null;
  return { entryId: first.id, createdAt: first.createdAt };
}

function oldestBookmarkedEntry(
  entries: JournalEntry[],
  bookmarks: ReflectionBookmark[],
): ArchiveOwnershipBookmarkRef | null {
  if (bookmarks.length === 0) return null;

  const byId = new Map(entries.map((entry) => [entry.id, entry]));
  let oldest: ArchiveOwnershipBookmarkRef | null = null;

  for (const bookmark of bookmarks) {
    const entry = byId.get(bookmark.entryId);
    if (!entry) continue;
    const existing = oldest ? byId.get(oldest.entryId) : null;
    if (
      !oldest ||
      (existing &&
        new Date(entry.createdAt).getTime() < new Date(existing.createdAt).getTime())
    ) {
      oldest = { entryId: bookmark.entryId, markedAt: bookmark.markedAt };
    }
  }

  return oldest;
}

function firstChangedSomethingBookmark(
  bookmarks: ReflectionBookmark[],
): ArchiveOwnershipBookmarkRef | null {
  const changed = bookmarks
    .filter((bookmark) => bookmark.type === "changed_something")
    .sort((a, b) => new Date(a.markedAt).getTime() - new Date(b.markedAt).getTime());

  const first = changed[0];
  if (!first) return null;
  return { entryId: first.entryId, markedAt: first.markedAt };
}

function readBackupSignals(): {
  encryptedBackupConfigured: boolean;
  localExportUsed: boolean;
} {
  if (!isBrowser()) {
    return { encryptedBackupConfigured: false, localExportUsed: false };
  }

  return {
    encryptedBackupConfigured: Boolean(readLastBackupAt()),
    localExportUsed: hasLocalEvent(LAUNCH_EVENTS.exportUsed),
  };
}

/** Detect archive depth and backup posture — internal signals for quiet copy. */
export async function buildArchiveOwnershipReport(
  entries: JournalEntry[] = getAllEntries(),
): Promise<ArchiveOwnershipReport> {
  const sorted = sortedEntries(entries);
  const bookmarks = getAllBookmarks();
  const audioIds = new Set(isBrowser() ? await listAudioEntryIds() : []);
  const backup = readBackupSignals();

  const oldest = oldestReflection(sorted);
  const archiveAgeDays =
    oldest && sorted.length > 0
      ? daysBetweenKeys(toDayKey(oldest.createdAt), todayKey())
      : null;
  const monthsRepresented = countMonthsRepresented(sorted);
  const reachesBackMonthLabel =
    oldest && monthsRepresented >= MONTH_SPAN_MIN
      ? formatReachBackMonth(oldest.createdAt)
      : null;

  return {
    hasArchive: sorted.length > 0,
    entryCount: sorted.length,
    archiveAgeDays,
    oldestReflection: oldest,
    firstSavedAudio: firstSavedAudio(sorted, audioIds),
    oldestBookmarkedEntry: oldestBookmarkedEntry(sorted, bookmarks),
    firstChangedSomethingBookmark: firstChangedSomethingBookmark(bookmarks),
    monthsRepresented,
    reachesBackMonthLabel,
    encryptedBackupConfigured: backup.encryptedBackupConfigured,
    localExportUsed: backup.localExportUsed,
    backupConfigured: backup.encryptedBackupConfigured || backup.localExportUsed,
  };
}

export function buildArchivePageOwnershipLines(
  report: ArchiveOwnershipReport,
): ArchiveOwnershipLines {
  if (!report.hasArchive) {
    return {
      primary: ARCHIVE_OWNERSHIP_COPY.belongsToYou,
      secondary: ARCHIVE_OWNERSHIP_COPY.takeWithYou,
      reassurance: null,
    };
  }

  const primary =
    report.reachesBackMonthLabel !== null
      ? `This archive now reaches back to ${report.reachesBackMonthLabel}.`
      : report.oldestReflection
        ? ARCHIVE_OWNERSHIP_COPY.oldestStillHere
        : ARCHIVE_OWNERSHIP_COPY.belongsToYou;

  const secondary =
    report.firstChangedSomethingBookmark
      ? ARCHIVE_OWNERSHIP_COPY.markedWhereChanged
      : report.oldestBookmarkedEntry
        ? ARCHIVE_OWNERSHIP_COPY.earlyBookmarkStillHere
        : report.firstSavedAudio
          ? ARCHIVE_OWNERSHIP_COPY.firstRecordingStillHere
          : ARCHIVE_OWNERSHIP_COPY.takeWithYou;

  const reassurance = report.backupConfigured
    ? ARCHIVE_OWNERSHIP_COPY.backupRecoverable
    : ARCHIVE_OWNERSHIP_COPY.exportPortable;

  return { primary, secondary, reassurance };
}

export function buildAccountOwnershipLines(
  report: ArchiveOwnershipReport,
  signedIn: boolean,
): string[] {
  if (!report.hasArchive) return [];

  const lines: string[] = [ARCHIVE_OWNERSHIP_COPY.belongsToYou];

  if (report.backupConfigured) {
    lines.push(ARCHIVE_OWNERSHIP_COPY.backupRecoverable);
  } else if (signedIn) {
    lines.push(ARCHIVE_OWNERSHIP_COPY.exportPortable);
  } else {
    lines.push(ARCHIVE_OWNERSHIP_COPY.signInForBackup);
  }

  lines.push(ARCHIVE_OWNERSHIP_COPY.takeWithYou);
  return [...new Set(lines)].slice(0, 3);
}

export function buildSettingsOwnershipLine(report: ArchiveOwnershipReport): string | null {
  if (!report.hasArchive) return ARCHIVE_OWNERSHIP_COPY.takeWithYou;
  if (report.reachesBackMonthLabel) {
    return `This archive now reaches back to ${report.reachesBackMonthLabel}. ${ARCHIVE_OWNERSHIP_COPY.takeWithYou}`;
  }
  return `${ARCHIVE_OWNERSHIP_COPY.oldestStillHere} ${ARCHIVE_OWNERSHIP_COPY.takeWithYou}`;
}

export function buildSparseHomepageOwnershipLine(
  report: ArchiveOwnershipReport,
): string | null {
  if (report.entryCount > SPARSE_ENTRY_MAX) return null;
  if (report.entryCount === 0) return ARCHIVE_OWNERSHIP_COPY.belongsToYou;
  return ARCHIVE_OWNERSHIP_COPY.sparseHome;
}

export function buildOldestEntryLink(
  report: ArchiveOwnershipReport,
): ArchiveOwnershipLink | null {
  if (!report.oldestReflection) return null;
  return {
    href: `/entry/${report.oldestReflection.entryId}`,
    label: "Oldest saved moment",
  };
}
