import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import {
  ARCHIVE_DELTA_AWAY_HEADLINE,
  ARCHIVE_DELTA_FIRST_VISIT,
  ARCHIVE_DELTA_NO_CHANGES,
  ARCHIVE_DELTA_ROW_LABEL,
  ARCHIVE_DELTA_TITLE,
} from "@/lib/archive/archive-state-delta-copy";
import { buildArchiveReputationView } from "@/lib/archive/archive-reputation";
import { ARCHIVE_REPUTATION_LEVEL_LABEL } from "@/lib/archive/archive-reputation-copy";
import { buildEvidenceArchiveStats } from "@/lib/archive/evidence-archive-stats";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveStateDeltaHistoryEntry,
  ArchiveStateDeltaRow,
  ArchiveStateDeltaView,
  ArchiveStateSnapshot,
} from "@/types/archive-state-snapshot";
import type { ArchiveReputationLevel } from "@/types/archive-reputation";
import type { JournalEntry } from "@/types/journal";

const SNAPSHOT_KEY = "voicememory_archive_state_snapshot";
const LAST_VIEW_KEY = "voicememory_archive_last_view_at";
const DELTA_HISTORY_KEY = "voicememory_archive_delta_history";
const AWAY_RETURN_DAYS = 3;
const MAX_DELTA_HISTORY = 8;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function lineId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `delta-${Date.now()}`;
}

export function captureArchiveStateSnapshot(
  entriesInput?: JournalEntry[],
): ArchiveStateSnapshot | null {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return null;

  const reputation = buildArchiveReputationView(entries);
  const stats = buildEvidenceArchiveStats(entries);

  return {
    belief: belief.belief.trim(),
    confidence: Math.round(belief.confidence),
    reputation: reputation?.level ?? "low",
    evidenceCount: stats.evidenceQuotesStored,
    lifeAreas: [...belief.evidence.lifeAreas],
    timestamp: new Date().toISOString(),
  };
}

export function readArchiveStateSnapshot(): ArchiveStateSnapshot | null {
  const store = getStorage();
  if (!store) return null;
  try {
    const raw = store.getItem(SNAPSHOT_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as ArchiveStateSnapshot;
    if (!parsed || typeof parsed.belief !== "string") return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writeArchiveStateSnapshot(snapshot: ArchiveStateSnapshot): void {
  getStorage()?.setItem(SNAPSHOT_KEY, JSON.stringify(snapshot));
}

export function readArchiveLastViewAt(): string | null {
  return getStorage()?.getItem(LAST_VIEW_KEY) ?? null;
}

export function writeArchiveLastViewAt(iso: string = new Date().toISOString()): void {
  getStorage()?.setItem(LAST_VIEW_KEY, iso);
}

function reputationLabel(level: ArchiveReputationLevel): string {
  return ARCHIVE_REPUTATION_LEVEL_LABEL[level];
}

function addedLifeAreas(before: string[], after: string[]): string[] {
  const beforeSet = new Set(before.map((a) => a.toLowerCase()));
  return after.filter((a) => !beforeSet.has(a.toLowerCase()));
}

export function buildDeltaRows(
  before: ArchiveStateSnapshot,
  after: ArchiveStateSnapshot,
): ArchiveStateDeltaRow[] {
  const rows: ArchiveStateDeltaRow[] = [];

  if (before.confidence !== after.confidence) {
    rows.push({
      kind: "confidence",
      label: ARCHIVE_DELTA_ROW_LABEL.confidence,
      then: `${before.confidence}%`,
      now: `${after.confidence}%`,
      difference: `${before.confidence}% → ${after.confidence}%`,
    });
  }

  if (before.evidenceCount !== after.evidenceCount) {
    rows.push({
      kind: "evidence",
      label: ARCHIVE_DELTA_ROW_LABEL.evidence,
      then: String(before.evidenceCount),
      now: String(after.evidenceCount),
      difference: `${before.evidenceCount} → ${after.evidenceCount}`,
    });
  }

  const added = addedLifeAreas(before.lifeAreas, after.lifeAreas);
  if (added.length > 0) {
    const prefix = added.length === 1 ? "+ " : "+ ";
    rows.push({
      kind: "life_areas",
      label: ARCHIVE_DELTA_ROW_LABEL.life_areas,
      then: before.lifeAreas.length ? before.lifeAreas.join(", ") : "—",
      now: after.lifeAreas.join(", "),
      difference: `${prefix}${added.join(", ")}`,
    });
  }

  if (before.reputation !== after.reputation) {
    rows.push({
      kind: "reputation",
      label: ARCHIVE_DELTA_ROW_LABEL.reputation,
      then: reputationLabel(before.reputation),
      now: reputationLabel(after.reputation),
      difference: `${reputationLabel(before.reputation)} → ${reputationLabel(after.reputation)}`,
    });
  }

  if (before.belief !== after.belief) {
    rows.push({
      kind: "belief",
      label: ARCHIVE_DELTA_ROW_LABEL.belief,
      then: before.belief.slice(0, 80),
      now: after.belief.slice(0, 80),
      difference: "Belief shifted",
    });
  }

  return rows;
}

export function daysSinceArchiveLastView(now = new Date()): number | null {
  const last = readArchiveLastViewAt();
  if (!last) return null;
  return daysBetweenKeys(toDayKey(last), toDayKey(now.toISOString()));
}

export function buildArchiveStateDelta(
  entriesInput?: JournalEntry[],
): ArchiveStateDeltaView | null {
  const current = captureArchiveStateSnapshot(entriesInput);
  if (!current) return null;

  const baseline = readArchiveStateSnapshot();
  const awayDays = daysSinceArchiveLastView();
  const awayReturn = awayDays !== null && awayDays >= AWAY_RETURN_DAYS;

  if (!baseline) {
    return {
      hasChanges: false,
      rows: [],
      awayReturn: false,
      headline: ARCHIVE_DELTA_TITLE,
      subheadline: ARCHIVE_DELTA_FIRST_VISIT,
      generatedAt: new Date().toISOString(),
    };
  }

  const rows = buildDeltaRows(baseline, current);
  const hasChanges = rows.length > 0;

  return {
    hasChanges,
    rows,
    awayReturn,
    headline: awayReturn ? ARCHIVE_DELTA_AWAY_HEADLINE : ARCHIVE_DELTA_TITLE,
    subheadline: hasChanges ? null : ARCHIVE_DELTA_NO_CHANGES,
    generatedAt: new Date().toISOString(),
  };
}

export function readArchiveDeltaHistory(): ArchiveStateDeltaHistoryEntry[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(DELTA_HISTORY_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as ArchiveStateDeltaHistoryEntry[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeArchiveDeltaHistory(entries: ArchiveStateDeltaHistoryEntry[]): void {
  getStorage()?.setItem(
    DELTA_HISTORY_KEY,
    JSON.stringify(entries.slice(0, MAX_DELTA_HISTORY)),
  );
}

export function pushArchiveDeltaHistory(delta: ArchiveStateDeltaView): void {
  if (!delta.hasChanges) return;
  const history = readArchiveDeltaHistory();
  const entry: ArchiveStateDeltaHistoryEntry = {
    id: lineId(),
    recordedAt: delta.generatedAt,
    delta,
  };
  writeArchiveDeltaHistory([entry, ...history].slice(0, MAX_DELTA_HISTORY));
}

/** Persist current archive state after the user has seen the page. */
export function commitArchiveStateView(entriesInput?: JournalEntry[]): void {
  const current = captureArchiveStateSnapshot(entriesInput);
  if (!current) return;
  const delta = buildArchiveStateDelta(entriesInput);
  if (delta?.hasChanges) pushArchiveDeltaHistory(delta);
  writeArchiveStateSnapshot(current);
  writeArchiveLastViewAt();
}

export function buildArchiveDiscoverDeltaCollection(
  entriesInput?: JournalEntry[],
): ArchiveStateDeltaView[] {
  const current = buildArchiveStateDelta(entriesInput);
  const history = readArchiveDeltaHistory()
    .map((entry) => entry.delta)
    .filter((d) => d.hasChanges);

  if (current?.hasChanges) {
    const seen = new Set(history.map((d) => d.generatedAt));
    if (!seen.has(current.generatedAt)) {
      return [current, ...history].slice(0, MAX_DELTA_HISTORY);
    }
  }

  return history.length > 0 ? history : current ? [current] : [];
}

export function clearArchiveStateForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(SNAPSHOT_KEY);
  store.removeItem(LAST_VIEW_KEY);
  store.removeItem(DELTA_HISTORY_KEY);
}
