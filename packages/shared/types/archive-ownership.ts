import type { JournalEntry } from "@/types/journal";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";

export interface ArchiveOwnershipEntryRef {
  entryId: string;
  createdAt: string;
}

export interface ArchiveOwnershipBookmarkRef {
  entryId: string;
  markedAt: string;
}

export interface ArchiveOwnershipReport {
  hasArchive: boolean;
  entryCount: number;
  archiveAgeDays: number | null;
  oldestReflection: ArchiveOwnershipEntryRef | null;
  firstSavedAudio: ArchiveOwnershipEntryRef | null;
  oldestBookmarkedEntry: ArchiveOwnershipBookmarkRef | null;
  firstChangedSomethingBookmark: ArchiveOwnershipBookmarkRef | null;
  monthsRepresented: number;
  reachesBackMonthLabel: string | null;
  encryptedBackupConfigured: boolean;
  localExportUsed: boolean;
  backupConfigured: boolean;
}

export interface ArchiveOwnershipLines {
  primary: string | null;
  secondary: string | null;
  reassurance: string | null;
}

export interface ArchiveOwnershipLink {
  href: string;
  label: string;
}
