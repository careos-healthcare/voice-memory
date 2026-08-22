import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { readRetentionLoopEvents } from "@/lib/retention/retention-loops";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import type { JournalEntry } from "@/types/journal";
import type { RevisitSequencingReport } from "@/types/memory-compounding";

const SEQUENCING_KEY = "voicememory_revisit_sequencing";

export const EMOTIONAL_ADJACENCY_DAYS = 5;
export const HIGH_PAYOFF_SPACING_DAYS = 12;
export const FATIGUE_REVISIT_THRESHOLD = 4;
export const FATIGUE_WINDOW_DAYS = 7;

interface SequencingState {
  lastEmotionalReopenAt: string | null;
  lastHighPayoffEntryId: string | null;
  lastHighPayoffAt: string | null;
  recentEmotionalEntryIds: string[];
  suppressedAdjacentCount: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readState(): SequencingState {
  if (!isBrowser()) {
    return {
      lastEmotionalReopenAt: null,
      lastHighPayoffEntryId: null,
      lastHighPayoffAt: null,
      recentEmotionalEntryIds: [],
      suppressedAdjacentCount: 0,
    };
  }
  try {
    const raw = localStorage.getItem(SEQUENCING_KEY);
    if (!raw) throw new Error("empty");
    return JSON.parse(raw) as SequencingState;
  } catch {
    return {
      lastEmotionalReopenAt: null,
      lastHighPayoffEntryId: null,
      lastHighPayoffAt: null,
      recentEmotionalEntryIds: [],
      suppressedAdjacentCount: 0,
    };
  }
}

function writeState(state: SequencingState): void {
  if (!isBrowser() || isSideEffectBlocked()) return;
  localStorage.setItem(SEQUENCING_KEY, JSON.stringify(state));
}

export function recordEmotionalReopen(entryId: string, payoffScore: number): void {
  if (!isBrowser() || payoffScore < 54) return;
  const state = readState();
  const now = new Date().toISOString();
  const recent = [entryId, ...state.recentEmotionalEntryIds.filter((id) => id !== entryId)].slice(0, 8);
  writeState({
    ...state,
    lastEmotionalReopenAt: now,
    lastHighPayoffEntryId: entryId,
    lastHighPayoffAt: now,
    recentEmotionalEntryIds: recent,
  });
}

export function detectRevisitFatigue(): { active: boolean; score: number } {
  const events = readRetentionLoopEvents().filter(
    (e) => e.kind === "entry_revisited" || e.kind === "old_entry_opened_from_note",
  );
  const recent = events.filter(
    (e) => daysBetweenKeys(toDayKey(e.at), todayKey()) <= FATIGUE_WINDOW_DAYS,
  );
  const score = recent.length;
  return {
    active: score >= FATIGUE_REVISIT_THRESHOLD,
    score,
  };
}

export function recommendedRevisitSpacingDays(): number {
  const fatigue = detectRevisitFatigue();
  if (fatigue.active) return HIGH_PAYOFF_SPACING_DAYS + 7;
  const state = readState();
  if (!state.lastEmotionalReopenAt) return EMOTIONAL_ADJACENCY_DAYS;
  const daysSince = daysBetweenKeys(toDayKey(state.lastEmotionalReopenAt), todayKey());
  if (daysSince < EMOTIONAL_ADJACENCY_DAYS) return HIGH_PAYOFF_SPACING_DAYS;
  return EMOTIONAL_ADJACENCY_DAYS;
}

export function shouldSuppressRevisitCandidate(entryId: string, emotionalWeight = 0): boolean {
  const state = readState();
  const fatigue = detectRevisitFatigue();

  if (fatigue.active && emotionalWeight >= 60) return true;

  if (state.recentEmotionalEntryIds.includes(entryId)) return true;

  if (state.lastHighPayoffAt && emotionalWeight >= 65) {
    const gap = daysBetweenKeys(toDayKey(state.lastHighPayoffAt), todayKey());
    if (gap < HIGH_PAYOFF_SPACING_DAYS) return true;
  }

  if (state.lastEmotionalReopenAt && emotionalWeight >= 55) {
    const gap = daysBetweenKeys(toDayKey(state.lastEmotionalReopenAt), todayKey());
    if (gap < EMOTIONAL_ADJACENCY_DAYS) return true;
  }

  return false;
}

export function filterRevisitCandidates<T extends { entryId?: string; strength?: number; confidence?: number }>(
  candidates: T[],
): T[] {
  const fatigue = detectRevisitFatigue();
  let suppressed = 0;

  const filtered = candidates.filter((candidate) => {
    const entryId = candidate.entryId;
    if (!entryId) return true;
    const weight = candidate.strength ?? candidate.confidence ?? 0;
    const suppress = shouldSuppressRevisitCandidate(entryId, weight);
    if (suppress) suppressed += 1;
    return !suppress;
  });

  if (suppressed > 0) {
    const state = readState();
    writeState({ ...state, suppressedAdjacentCount: state.suppressedAdjacentCount + suppressed });
  }

  if (fatigue.active && filtered.length === 0 && candidates.length > 0) {
    return candidates.slice(-1);
  }

  return filtered;
}

export function buildRevisitSequencingReport(): RevisitSequencingReport {
  const state = readState();
  const fatigue = detectRevisitFatigue();

  return {
    generatedAt: new Date().toISOString(),
    hasData: Boolean(state.lastEmotionalReopenAt) || fatigue.score > 0,
    revisitFatigueActive: fatigue.active,
    fatigueScore: fatigue.score,
    lastEmotionalReopenAt: state.lastEmotionalReopenAt,
    suppressedAdjacentCount: state.suppressedAdjacentCount,
    recommendedSpacingDays: recommendedRevisitSpacingDays(),
  };
}

export function applyRevisitSequencingToEntries(
  entryIds: string[],
  _entries: JournalEntry[],
): string[] {
  return entryIds.filter((id) => !shouldSuppressRevisitCandidate(id, 50));
}
