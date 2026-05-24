import { listAudioEntryIds } from "@/lib/audio-storage";
import { normalizeReflection } from "@/lib/reflection";
import { safeSetJson } from "@/lib/reliability/safe-local-storage";
import { readStorageVersion } from "@/lib/reliability/storage-version";
import { getAllEntries } from "@/lib/storage";
import type { JournalEntry, Reflection } from "@/types/journal";
import type {
  IntegrityIssue,
  RepairResult,
  StorageHealthReport,
} from "@/types/storage-reliability";

const ENTRIES_KEY = "voicememory_entries";

function isValidReflection(value: unknown): value is Reflection {
  if (!value || typeof value !== "object") return false;
  const record = value as Record<string, unknown>;
  return (
    typeof record.mood === "string" &&
    typeof record.emotionalIntensity === "number" &&
    Array.isArray(record.recurringThemes)
  );
}

function isValidTimestamp(value: unknown): boolean {
  if (typeof value !== "string" || !value.trim()) return false;
  const time = new Date(value).getTime();
  return Number.isFinite(time);
}

export function inspectEntryIntegrity(
  entries: JournalEntry[],
  audioIds: Set<string>,
): IntegrityIssue[] {
  const issues: IntegrityIssue[] = [];
  const seenIds = new Map<string, number>();

  for (const entry of entries) {
    if (!entry.id || typeof entry.id !== "string") {
      issues.push({
        type: "invalid_entry_shape",
        detail: "Entry missing id",
      });
      continue;
    }

    seenIds.set(entry.id, (seenIds.get(entry.id) ?? 0) + 1);

    if (!isValidTimestamp(entry.createdAt)) {
      issues.push({
        type: "missing_timestamp",
        entryId: entry.id,
        detail: "Missing or invalid createdAt",
      });
    }

    if (typeof entry.transcript !== "string") {
      issues.push({
        type: "missing_transcript",
        entryId: entry.id,
        detail: "Transcript is not a string",
      });
    }

    if (!isValidReflection(entry.reflection)) {
      issues.push({
        type: "malformed_reflection",
        entryId: entry.id,
        detail: "Reflection object is malformed",
      });
    }

    if (entry.audioId && !audioIds.has(entry.audioId)) {
      issues.push({
        type: "missing_audio_reference",
        entryId: entry.id,
        detail: `audioId ${entry.audioId} not found in IndexedDB`,
      });
    }
  }

  for (const [id, count] of seenIds) {
    if (count > 1) {
      issues.push({
        type: "duplicate_id",
        entryId: id,
        detail: `Duplicate id appears ${count} times`,
      });
    }
  }

  return issues;
}

export async function buildStorageHealthReport(): Promise<StorageHealthReport> {
  const entries = getAllEntries();
  const audioIdsList = await listAudioEntryIds();
  const audioIds = new Set(audioIdsList);
  const issues = inspectEntryIntegrity(entries, audioIds);

  return {
    storageVersion: readStorageVersion(),
    entriesCount: entries.length,
    audioCount: audioIdsList.length,
    brokenAudioReferences: issues.filter(
      (issue) => issue.type === "missing_audio_reference",
    ).length,
    duplicateIds: issues.filter((issue) => issue.type === "duplicate_id").length,
    malformedReflections: issues.filter(
      (issue) => issue.type === "malformed_reflection",
    ).length,
    missingTimestamps: issues.filter(
      (issue) => issue.type === "missing_timestamp",
    ).length,
    issues,
  };
}

function dedupeEntries(entries: JournalEntry[]): JournalEntry[] {
  const byId = new Map<string, JournalEntry>();

  for (const entry of entries) {
    const existing = byId.get(entry.id);
    if (!existing) {
      byId.set(entry.id, entry);
      continue;
    }

    const existingTime = new Date(existing.createdAt).getTime();
    const entryTime = new Date(entry.createdAt).getTime();
    if (entryTime >= existingTime) {
      byId.set(entry.id, entry);
    }
  }

  return Array.from(byId.values()).sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
}

export async function repairEntryIntegrity(): Promise<RepairResult> {
  const entries = getAllEntries();
  const audioIds = new Set(await listAudioEntryIds());
  const details: string[] = [];
  let repaired = 0;

  const fixed = dedupeEntries(entries).map((entry) => {
    let next = { ...entry };
    let changed = false;

    if (!isValidTimestamp(next.createdAt)) {
      next = { ...next, createdAt: new Date().toISOString() };
      changed = true;
      details.push(`Fixed timestamp for ${next.id}`);
    }

    if (!isValidReflection(next.reflection)) {
      next = {
        ...next,
        reflection: normalizeReflection({
          mood: "quiet",
          emotionalIntensity: 5,
          recurringThemes: [],
          hiddenConcern: "",
          positiveSignal: "",
          recommendation: "",
        }),
      };
      changed = true;
      details.push(`Normalized reflection for ${next.id}`);
    } else {
      const normalized = normalizeReflection(next.reflection);
      if (JSON.stringify(normalized) !== JSON.stringify(next.reflection)) {
        next = { ...next, reflection: normalized };
        changed = true;
        details.push(`Normalized reflection fields for ${next.id}`);
      }
    }

    if (typeof next.transcript !== "string") {
      next = { ...next, transcript: "" };
      changed = true;
      details.push(`Fixed transcript for ${next.id}`);
    }

    if (next.audioId && !audioIds.has(next.audioId)) {
      next = { ...next, audioId: undefined };
      changed = true;
      details.push(`Cleared broken audio reference for ${next.id}`);
    }

    if (changed) repaired += 1;
    return next;
  });

  if (fixed.length !== entries.length) {
    details.push(`Removed ${entries.length - fixed.length} duplicate entries`);
    repaired += entries.length - fixed.length;
  }

  safeSetJson(ENTRIES_KEY, fixed);
  return { repaired, details };
}

export async function clearBrokenAudioReferences(): Promise<RepairResult> {
  const entries = getAllEntries();
  const audioIds = new Set(await listAudioEntryIds());
  let repaired = 0;
  const details: string[] = [];

  const fixed = entries.map((entry) => {
    if (entry.audioId && !audioIds.has(entry.audioId)) {
      repaired += 1;
      details.push(`Cleared broken audio reference for ${entry.id}`);
      return { ...entry, audioId: undefined };
    }
    return entry;
  });

  safeSetJson(ENTRIES_KEY, fixed);
  return { repaired, details };
}
