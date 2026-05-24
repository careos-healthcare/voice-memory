import { daysBetweenKeys, toDayKey, todayKey } from "@/lib/dates";
import { buildMemoryCompoundingReport } from "@/lib/memory/memory-compounding";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type {
  SlowRealizationCandidate,
  SlowRealizationKind,
  SlowRealizationReport,
} from "@/types/memory-compounding";

export const SLOW_REALIZATION_MIN_GAP_DAYS = 45;
export const SLOW_REALIZATION_MAX_GAP_DAYS = 90;
export const SLOW_REALIZATION_MIN_SUPPORT = 3;
export const SLOW_REALIZATION_MIN_STRENGTH = 76;
export const SHOW_COOLDOWN_DAYS = 35;
export const MIN_SESSIONS_BETWEEN = 6;

export const SLOW_REALIZATION_COPY: Record<SlowRealizationKind, string> = {
  stopped_same_way: "You stopped talking about this the same way.",
  sounded_heavier: "This used to sound heavier.",
  came_back_differently: "You came back differently.",
  carried_differently: "You carried this differently over time.",
  easier_to_say: "This became easier to say later.",
};

const STATE_KEY = "voicememory_slow_realizations";

const HEAVY_RE = /\b(heavy|hard|overwhelm|stuck|tired|exhausted|drained|weight)\b/gi;

interface SlowState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  surfacedId: string | null;
  records: Array<{ noteId: string; textKey: string; shownAt: number }>;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function readState(): SlowState {
  if (!isBrowser()) {
    return {
      sessionCount: 0,
      lastSessionDay: todayKey(),
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      surfacedId: null,
      records: [],
    };
  }
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (!raw) throw new Error("empty");
    return JSON.parse(raw) as SlowState;
  } catch {
    return {
      sessionCount: 0,
      lastSessionDay: todayKey(),
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      surfacedId: null,
      records: [],
    };
  }
}

function writeState(state: SlowState): void {
  if (!isBrowser()) return;
  localStorage.setItem(STATE_KEY, JSON.stringify(state));
}

function textKey(text: string): string {
  return text.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 72);
}

function bumpSession(state: SlowState): SlowState {
  const day = todayKey();
  const sessionCount = state.lastSessionDay === day ? state.sessionCount : state.sessionCount + 1;
  return { ...state, sessionCount, lastSessionDay: day };
}

function canShow(state: SlowState, candidate: SlowRealizationCandidate): boolean {
  const now = Date.now();
  if (state.lastShownAt && daysBetweenKeys(toDayKey(new Date(state.lastShownAt).toISOString()), todayKey()) < SHOW_COOLDOWN_DAYS) {
    return false;
  }
  if (state.sessionCount - state.sessionsAtLastShow < MIN_SESSIONS_BETWEEN) {
    return false;
  }
  const recent = state.records.find(
    (row) => row.textKey === textKey(candidate.text) && now - row.shownAt < SHOW_COOLDOWN_DAYS * 86400000,
  );
  return !recent;
}

function markShown(state: SlowState, candidate: SlowRealizationCandidate): SlowState {
  const now = Date.now();
  return {
    ...state,
    sessionsAtLastShow: state.sessionCount,
    lastShownAt: now,
    surfacedId: candidate.id,
    records: [
      { noteId: candidate.id, textKey: textKey(candidate.text), shownAt: now },
      ...state.records,
    ].slice(0, 24),
  };
}

function fromCompounding(entries: JournalEntry[]): SlowRealizationCandidate[] {
  const report = buildMemoryCompoundingReport(entries);
  const kindMap: Partial<Record<string, SlowRealizationKind>> = {
    wording_softened: "easier_to_say",
    fear_faded: "carried_differently",
    identity_shift: "came_back_differently",
    almost_naming: "stopped_same_way",
    clearer_later: "sounded_heavier",
    phrase_gained_meaning: "stopped_same_way",
    loop_resolving: "carried_differently",
  };

  return report.candidates
    .filter(
      (row) =>
        row.gapDays >= SLOW_REALIZATION_MIN_GAP_DAYS &&
        row.gapDays <= SLOW_REALIZATION_MAX_GAP_DAYS + 120 &&
        row.supportingEntryIds.length >= SLOW_REALIZATION_MIN_SUPPORT - 1,
    )
    .map((row) => {
      const kind = kindMap[row.kind] ?? "carried_differently";
      return {
        id: `slow-${row.id}`,
        kind,
        text: SLOW_REALIZATION_COPY[kind],
        strength: row.strength + 4,
        gapDays: row.gapDays,
        supportingCount: row.supportingEntryIds.length,
        anchorEntryId: row.entryId ?? row.pastEntryId ?? row.id,
        pastEntryId: row.pastEntryId,
        entryId: row.entryId,
      };
    })
    .filter((row) => row.strength >= SLOW_REALIZATION_MIN_STRENGTH && helpsOrient(row.text, row.strength));
}

/** Build slow realization candidates — rare, distance-gated moments. */
export function buildSlowRealizationReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): SlowRealizationReport {
  const candidates = fromCompounding(entries)
    .sort((a, b) => b.strength - a.strength)
    .slice(0, 12);

  const state = readState();
  return {
    generatedAt: new Date().toISOString(),
    hasData: candidates.length > 0,
    candidates,
    surfacedId: state.surfacedId,
  };
}

function toMemoryNote(candidate: SlowRealizationCandidate): MemoryNote {
  return {
    id: candidate.id,
    text: candidate.text,
    category: "changed",
    confidence: candidate.strength,
    pastEntryId: candidate.pastEntryId,
    entryId: candidate.entryId ?? candidate.anchorEntryId,
  };
}

/** Pick at most one slow realization, silence-calibrated. Max 1 surfaced at a time. */
export function pickSlowRealizationNote(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
  surface: "memory" | "homepage" = "memory",
): MemoryNote | null {
  const report = buildSlowRealizationReport(entries);
  if (!report.hasData) return null;

  let state = bumpSession(readState());
  writeState(state);

  const notes = report.candidates.map(toMemoryNote);
  for (const candidate of report.candidates) {
    if (!canShow(state, candidate)) continue;
    const note = toMemoryNote(candidate);
    const calibrated = calibratePrimaryNote([note], entries, surface === "homepage" ? "homepage" : "memory");
    if (calibrated) {
      writeState(markShown(state, candidate));
      return calibrated;
    }
  }

  const calibrated = calibratePrimaryNote(notes.slice(0, 1), entries, surface === "homepage" ? "homepage" : "memory");
  if (calibrated && report.candidates[0] && canShow(state, report.candidates[0])) {
    writeState(markShown(state, report.candidates[0]));
    return calibrated;
  }

  return null;
}

export function memorySlowRealizationNote(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): MemoryNote | null {
  return pickSlowRealizationNote(entries, "memory");
}
