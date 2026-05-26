import { normalizeReflection } from "@/lib/reflection";
import { safeSetJson } from "@/lib/reliability/safe-local-storage";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import {
  CURRENT_STORAGE_VERSION,
  readStorageVersion,
  writeStorageVersion,
} from "@/lib/reliability/storage-version";
import type { JournalEntry, Reflection } from "@/types/journal";

const ENTRIES_KEY = "voicememory_entries";

let storageReady = false;

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readRawEntries(): unknown[] {
  if (!isBrowser()) return [];

  try {
    const raw = localStorage.getItem(ENTRIES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function migrateToV1(): void {
  const rawEntries = readRawEntries();
  const byId = new Map<string, JournalEntry>();

  for (const item of rawEntries) {
    if (!item || typeof item !== "object") continue;

    const record = item as Record<string, unknown>;
    const id =
      typeof record.id === "string" && record.id.trim()
        ? record.id.trim()
        : crypto.randomUUID();

    const createdAt =
      typeof record.createdAt === "string" && record.createdAt.trim()
        ? record.createdAt
        : new Date().toISOString();

    const transcript =
      typeof record.transcript === "string" ? record.transcript.trim() : "";

    const reflectionRaw = record.reflection;
    let reflection: Reflection;

    if (
      reflectionRaw &&
      typeof reflectionRaw === "object" &&
      "mood" in (reflectionRaw as object) &&
      "emotionalIntensity" in (reflectionRaw as object)
    ) {
      reflection = normalizeReflection(reflectionRaw as Reflection);
    } else {
      reflection = normalizeReflection({
        mood: "quiet",
        emotionalIntensity: 5,
        recurringThemes: [],
        hiddenConcern: "",
        positiveSignal: "",
        recommendation: "",
      });
    }

    const durationSeconds =
      typeof record.durationSeconds === "number" && record.durationSeconds > 0
        ? Math.round(record.durationSeconds)
        : 1;

    const entry: JournalEntry = {
      id,
      createdAt,
      transcript,
      reflection,
      durationSeconds,
      audioId:
        typeof record.audioId === "string" && record.audioId.trim()
          ? record.audioId
          : undefined,
      reflectionPending: record.reflectionPending === true,
    };

    const existing = byId.get(id);
    if (!existing) {
      byId.set(id, entry);
      continue;
    }

    const existingTime = new Date(existing.createdAt).getTime();
    const entryTime = new Date(entry.createdAt).getTime();
    if (entryTime >= existingTime) {
      byId.set(id, entry);
    }
  }

  const migrated = Array.from(byId.values()).sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );

  safeSetJson(ENTRIES_KEY, migrated);
}

const MIGRATIONS: Record<number, () => void> = {
  1: migrateToV1,
};

/** Run pending storage migrations once per session. */
export function ensureStorageReady(): void {
  if (!isBrowser() || storageReady || isSideEffectBlocked()) return;

  let version = readStorageVersion();

  while (version < CURRENT_STORAGE_VERSION) {
    const next = version + 1;
    const migrate = MIGRATIONS[next];
    if (migrate) {
      migrate();
    }
    writeStorageVersion(next);
    version = next;
  }

  storageReady = true;
}

/** Reset readiness flag — for tests/debug only. */
export function resetStorageReadyForDebug(): void {
  storageReady = false;
}
