import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveDisclosureInput,
  ArchiveDisclosureLevel,
  ArchiveDisclosureResolution,
} from "@/types/archive-disclosure-level";
import type { JournalEntry } from "@/types/journal";

export const ARCHIVE_DISCLOSURE_STORAGE_KEY = "voicememory_archive_disclosure";

const L1_MAX_REFLECTIONS = 9;
const L2_MIN_REFLECTIONS = 10;
const L2_MIN_VISITS = 3;

export type ArchiveDisclosureStorage = {
  archiveVisitCount: number;
  archiveDetailOpened: boolean;
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

export function readArchiveDisclosureStorage(): ArchiveDisclosureStorage {
  if (!isBrowser()) {
    return { archiveVisitCount: 0, archiveDetailOpened: false };
  }
  try {
    const raw = localStorage.getItem(ARCHIVE_DISCLOSURE_STORAGE_KEY);
    if (!raw) return { archiveVisitCount: 0, archiveDetailOpened: false };
    const parsed = JSON.parse(raw) as Partial<ArchiveDisclosureStorage>;
    return {
      archiveVisitCount: Math.max(0, Number(parsed.archiveVisitCount) || 0),
      archiveDetailOpened: Boolean(parsed.archiveDetailOpened),
    };
  } catch {
    return { archiveVisitCount: 0, archiveDetailOpened: false };
  }
}

export function writeArchiveDisclosureStorage(next: ArchiveDisclosureStorage): void {
  if (!isBrowser()) return;
  localStorage.setItem(ARCHIVE_DISCLOSURE_STORAGE_KEY, JSON.stringify(next));
}

export function recordArchiveHomeVisit(): ArchiveDisclosureStorage {
  const current = readArchiveDisclosureStorage();
  const next = {
    ...current,
    archiveVisitCount: current.archiveVisitCount + 1,
  };
  writeArchiveDisclosureStorage(next);
  return next;
}

export function markArchiveDetailOpened(): ArchiveDisclosureStorage {
  const current = readArchiveDisclosureStorage();
  const next = {
    ...current,
    archiveDetailOpened: true,
  };
  writeArchiveDisclosureStorage(next);
  return next;
}

function countEligibleReflections(entries: JournalEntry[]): number {
  return entries.filter((e) => e.reflectionPending !== true).length;
}

/** Resolve L1 / L2 / L3 from reflection depth, visits, and detail usage. */
export function resolveArchiveDisclosureLevel(
  input?: Partial<ArchiveDisclosureInput>,
): ArchiveDisclosureResolution {
  const entries = getMemoryEligibleEntries();
  const stored = readArchiveDisclosureStorage();
  const reflectionCount =
    input?.reflectionCount ?? countEligibleReflections(entries);
  const archiveVisitCount = input?.archiveVisitCount ?? stored.archiveVisitCount;
  const archiveDetailOpened =
    input?.archiveDetailOpened ?? stored.archiveDetailOpened;

  const reasons: string[] = [];

  if (archiveDetailOpened) {
    reasons.push("Opened Archive detail");
    return {
      level: "L3_ADVANCED",
      reflectionCount,
      archiveVisitCount,
      reasons,
    };
  }

  if (reflectionCount >= L2_MIN_REFLECTIONS) {
    reasons.push(`${reflectionCount} reflections (≥ ${L2_MIN_REFLECTIONS})`);
    return {
      level: "L2_ENGAGED",
      reflectionCount,
      archiveVisitCount,
      reasons,
    };
  }

  if (archiveVisitCount >= L2_MIN_VISITS) {
    reasons.push(`${archiveVisitCount} archive visits (≥ ${L2_MIN_VISITS})`);
    return {
      level: "L2_ENGAGED",
      reflectionCount,
      archiveVisitCount,
      reasons,
    };
  }

  if (reflectionCount <= L1_MAX_REFLECTIONS) {
    reasons.push(`${reflectionCount} reflections (< ${L2_MIN_REFLECTIONS})`);
  }

  return {
    level: "L1_BASIC",
    reflectionCount,
    archiveVisitCount,
    reasons,
  };
}

export function isDisclosureLevelAtLeast(
  current: ArchiveDisclosureLevel,
  minimum: ArchiveDisclosureLevel,
): boolean {
  const rank: Record<ArchiveDisclosureLevel, number> = {
    L1_BASIC: 1,
    L2_ENGAGED: 2,
    L3_ADVANCED: 3,
  };
  return rank[current] >= rank[minimum];
}
