import { toDayKey } from "@/lib/dates";
import { getAllEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type {
  ArchiveImportPreview,
  ArchiveSettingsSnapshot,
  ArchiveValidationIssue,
  VoiceMemoryArchivePackage,
} from "@/types/archive-permanence";
import type { ReflectionBookmark } from "@/types/reflection-bookmark";
import type { ArchiveReviewLabel } from "@/types/archive-permanence";

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function isJournalEntry(value: unknown): value is JournalEntry {
  if (!isObject(value)) return false;
  return (
    typeof value.id === "string" &&
    typeof value.createdAt === "string" &&
    typeof value.transcript === "string" &&
    isObject(value.reflection)
  );
}

function normalizeLegacyExport(raw: Record<string, unknown>): VoiceMemoryArchivePackage | null {
  const entries = raw.entries;
  if (!Array.isArray(entries) || entries.length === 0) return null;
  if (!entries.every(isJournalEntry)) return null;

  return {
    format: "voicememory-archive",
    version: 1,
    exportedAt: typeof raw.exportedAt === "string" ? raw.exportedAt : new Date().toISOString(),
    entries,
    bookmarks: [],
    settings: {
      reminders: {
        dailyReflection: true,
        afterStressfulEntry: true,
        weeklyReview: true,
        inactiveThreeDays: true,
        preferredReflectionHour: 20,
      },
      reflectionGoal: "off",
      listeningMode: false,
      fullDetail: false,
    },
    memoryReviewLabels: [],
  };
}

function normalizeFullArchive(raw: Record<string, unknown>): VoiceMemoryArchivePackage | null {
  if (raw.format !== "voicememory-archive" && raw.format !== undefined) return null;

  const entries = raw.entries;
  if (!Array.isArray(entries) || !entries.every(isJournalEntry)) return null;

  const bookmarks = Array.isArray(raw.bookmarks)
    ? (raw.bookmarks as ReflectionBookmark[])
    : [];

  const settings = isObject(raw.settings)
    ? (raw.settings as unknown as ArchiveSettingsSnapshot)
    : null;

  const memoryReviewLabels = Array.isArray(raw.memoryReviewLabels)
    ? (raw.memoryReviewLabels as ArchiveReviewLabel[])
    : [];

  const audio = Array.isArray(raw.audio) ? raw.audio : undefined;

  return {
    format: "voicememory-archive",
    version: 1,
    exportedAt: typeof raw.exportedAt === "string" ? raw.exportedAt : new Date().toISOString(),
    entries,
    bookmarks,
    settings: settings ?? {
      reminders: {
        dailyReflection: true,
        afterStressfulEntry: true,
        weeklyReview: true,
        inactiveThreeDays: true,
        preferredReflectionHour: 20,
      },
      reflectionGoal: "off",
      listeningMode: false,
      fullDetail: false,
    },
    memoryReviewLabels,
    audio,
  };
}

export function parseArchiveJson(raw: unknown): VoiceMemoryArchivePackage | null {
  if (!isObject(raw)) return null;
  return normalizeFullArchive(raw) ?? normalizeLegacyExport(raw);
}

function dateRangeForEntries(entries: JournalEntry[]) {
  if (entries.length === 0) return { from: null, to: null };
  const days = entries.map((entry) => toDayKey(entry.createdAt)).sort();
  return { from: days[0], to: days[days.length - 1] };
}

export function validateArchiveImport(
  archive: VoiceMemoryArchivePackage | null,
): ArchiveImportPreview {
  const issues: ArchiveValidationIssue[] = [];

  if (!archive) {
    return {
      valid: false,
      formatLabel: "Unknown",
      entryCount: 0,
      bookmarkCount: 0,
      audioCount: 0,
      reviewLabelCount: 0,
      hasSettings: false,
      dateRange: { from: null, to: null },
      localOverlapCount: 0,
      issues: [{ level: "error", message: "This file does not look like a VoiceMemory archive." }],
      package: null,
    };
  }

  if (archive.entries.length === 0) {
    issues.push({ level: "error", message: "Archive contains no reflections." });
  }

  const localIds = new Set(getAllEntries().map((entry) => entry.id));
  const overlap = archive.entries.filter((entry) => localIds.has(entry.id)).length;
  if (overlap > 0) {
    issues.push({
      level: "warning",
      message: `${overlap} reflection${overlap === 1 ? "" : "s"} already exist on this device.`,
    });
  }

  const hasErrors = issues.some((issue) => issue.level === "error");

  return {
    valid: !hasErrors,
    formatLabel: "VoiceMemory archive",
    entryCount: archive.entries.length,
    bookmarkCount: archive.bookmarks.length,
    audioCount: archive.audio?.length ?? 0,
    reviewLabelCount: archive.memoryReviewLabels.length,
    hasSettings: Boolean(archive.settings),
    dateRange: dateRangeForEntries(archive.entries),
    localOverlapCount: overlap,
    issues,
    package: archive,
  };
}

export async function parseArchiveFile(file: File): Promise<VoiceMemoryArchivePackage | null> {
  if (file.name.endsWith(".zip")) {
    const { unzipArchivePackage } = await import("@/lib/archive/zip-import");
    return unzipArchivePackage(await file.arrayBuffer());
  }

  try {
    const text = await file.text();
    return parseArchiveJson(JSON.parse(text) as unknown);
  } catch {
    return null;
  }
}
