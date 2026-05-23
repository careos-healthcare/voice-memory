import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import { buildChangeMomentsReport } from "@/lib/memory/change-moments";
import { buildConversationThreadsReport } from "@/lib/memory/conversation-threads";
import { buildRelationshipContinuityReport } from "@/lib/memory/relationship-continuity";
import { buildRevisitationReport } from "@/lib/memory/revisitation";
import type {
  ContinuityDepthContext,
  ContinuityDepthCopyExample,
  ContinuityDepthIndicator,
  ContinuityDepthKind,
  ContinuityDepthReport,
} from "@/types/continuity-depth";
import type { JournalEntry } from "@/types/journal";

const DEPTH_KEY = "voicememory_continuity_depth";
const MIN_ENTRIES = 10;
const STRONG_MIN = 68;
const MIN_SESSIONS = 6;
const MIN_DAYS = 14;
const TEXT_COOLDOWN_DAYS = 28;
const SURFACE_COOLDOWN_DAYS = 10;

const COPY: Record<ContinuityDepthKind, string> = {
  reflections_connecting: "Reflections starting to connect.",
  threads_worth_returning: "Threads worth returning to.",
  older_entries_context: "Older entries carry context.",
};

const KIND_PRIORITY: ContinuityDepthKind[] = [
  "older_entries_context",
  "threads_worth_returning",
  "reflections_connecting",
];

export const CONTINUITY_DEPTH_COPY_EXAMPLES: ContinuityDepthCopyExample[] = [
  {
    kind: "reflections_connecting",
    message: COPY.reflections_connecting,
    whenShown:
      "Threads, revisit links, theme shifts, and relationship notes overlap enough to feel interconnected",
  },
  {
    kind: "threads_worth_returning",
    message: COPY.threads_worth_returning,
    whenShown: "Several conversation threads span multiple reflections with enough depth to revisit",
  },
  {
    kind: "older_entries_context",
    message: COPY.older_entries_context,
    whenShown:
      "Landmarks, revisit links, and relationship continuity give older entries surrounding context",
  },
];

export interface ContinuityDepthOptions {
  context: ContinuityDepthContext;
  record?: boolean;
}

interface DepthState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    indicatorId: string;
    textKey: string;
    surface: ContinuityDepthContext;
    shownAt: number;
  }>;
}

interface DepthSignals {
  connectedThreadCount: number;
  strongThreadCount: number;
  revisitLinkCount: number;
  themeShiftCount: number;
  relationshipDepth: number;
  landmarkSpanDays: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function readState(): DepthState {
  if (!isBrowser()) {
    return {
      sessionCount: 0,
      lastSessionDay: "",
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      records: [],
    };
  }
  try {
    const raw = localStorage.getItem(DEPTH_KEY);
    if (!raw) {
      return {
        sessionCount: 0,
        lastSessionDay: "",
        sessionsAtLastShow: 0,
        lastShownAt: 0,
        records: [],
      };
    }
    const parsed = JSON.parse(raw) as DepthState;
    return {
      sessionCount: parsed.sessionCount ?? 0,
      lastSessionDay: parsed.lastSessionDay ?? "",
      sessionsAtLastShow: parsed.sessionsAtLastShow ?? 0,
      lastShownAt: parsed.lastShownAt ?? 0,
      records: Array.isArray(parsed.records) ? parsed.records : [],
    };
  } catch {
    return {
      sessionCount: 0,
      lastSessionDay: "",
      sessionsAtLastShow: 0,
      lastShownAt: 0,
      records: [],
    };
  }
}

function writeState(state: DepthState): void {
  if (!isBrowser()) return;
  localStorage.setItem(DEPTH_KEY, JSON.stringify(state));
}

export function bumpContinuityDepthSession(): DepthState {
  const today = toDayKey(new Date().toISOString());
  const state = readState();
  if (state.lastSessionDay !== today) {
    state.sessionCount += 1;
    state.lastSessionDay = today;
    writeState(state);
  }
  return state;
}

export function clearContinuityDepthFatigue(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(DEPTH_KEY);
}

function daysSince(timestamp: number): number {
  if (!timestamp) return Number.POSITIVE_INFINITY;
  return (Date.now() - timestamp) / (1000 * 60 * 60 * 24);
}

function isTextFatigued(text: string): boolean {
  const key = textKey(text);
  return readState().records.some(
    (record) => record.textKey === key && daysSince(record.shownAt) < TEXT_COOLDOWN_DAYS,
  );
}

function isSurfaceFatigued(context: ContinuityDepthContext): boolean {
  const now = Date.now();
  return readState().records.some(
    (record) =>
      record.surface === context &&
      now - record.shownAt < SURFACE_COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
  );
}

function canShowOnHomepage(state: DepthState): boolean {
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  if (sessionsSince < MIN_SESSIONS) return false;
  if (daysSince(state.lastShownAt) < MIN_DAYS) return false;
  return true;
}

function canShowOnMemory(state: DepthState): boolean {
  if (daysSince(state.lastShownAt) < MIN_DAYS) return false;
  return true;
}

function recordIndicatorShown(
  indicator: ContinuityDepthIndicator,
  context: ContinuityDepthContext,
): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    {
      indicatorId: indicator.id,
      textKey: textKey(indicator.text),
      surface: context,
      shownAt: now,
    },
  ].slice(-16);
  writeState(state);
}

function themeMap(sorted: JournalEntry[]): Map<string, JournalEntry[]> {
  const map = new Map<string, JournalEntry[]>();
  for (const entry of sorted) {
    for (const theme of entry.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      map.set(key, [...(map.get(key) ?? []), entry]);
    }
  }
  return map;
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countThemeShifts(sorted: JournalEntry[]): number {
  let count = 0;
  for (const [, hits] of themeMap(sorted)) {
    if (hits.length < 3) continue;
    const midpoint = Math.ceil(hits.length / 2);
    const earlier = hits.slice(0, midpoint);
    const later = hits.slice(midpoint);
    const earlierAvg = roundAvg(earlier.map((entry) => entry.reflection.emotionalIntensity));
    const laterAvg = roundAvg(later.map((entry) => entry.reflection.emotionalIntensity));
    if (Math.abs(earlierAvg - laterAvg) >= 1.2) {
      count += 1;
      continue;
    }
    const earlierThemes = new Set(
      earlier.flatMap((entry) => entry.reflection.recurringThemes.map((t) => t.toLowerCase())),
    );
    const laterOnly = later.some(
      (entry) =>
        entry.reflection.recurringThemes.some((t) => !earlierThemes.has(t.toLowerCase())) ||
        entry.reflection.emotionalIntensity <= earlierAvg - 1,
    );
    if (laterOnly) count += 1;
  }
  return count;
}

function countRevisitLinks(sorted: JournalEntry[]): number {
  const linked = new Set<string>();
  const anchors = sorted.slice(-Math.min(sorted.length, 12));

  for (const anchor of anchors) {
    const report = buildRevisitationReport(sorted, {
      context: "memory",
      entryId: anchor.id,
      limit: 2,
    });
    for (const note of report.notes) {
      if (note.pastEntryId) {
        linked.add(note.pastEntryId);
        if (note.entryId) linked.add(note.entryId);
      }
    }
  }

  return linked.size;
}

function measureLandmarkSpan(sorted: JournalEntry[]): number {
  const report = buildMemoryNotesReport(sorted, {
    context: "memory",
    maxTotal: 4,
    includeLandmarks: true,
  });
  const landmarks = report.landmarks ?? [];
  if (landmarks.length < 2) return 0;

  const entryIndex = new Map(sorted.map((entry, index) => [entry.id, index]));
  const indices = landmarks
    .flatMap((landmark) => {
      const ids = [landmark.pastEntryId, landmark.entryId].filter(Boolean) as string[];
      return ids.map((id) => entryIndex.get(id)).filter((index) => index !== undefined) as number[];
    })
    .sort((a, b) => a - b);

  if (indices.length < 2) return 0;

  const first = sorted[indices[0]];
  const last = sorted[indices[indices.length - 1]];
  return daysBetweenKeys(toDayKey(first.createdAt), toDayKey(last.createdAt));
}

function measureSignals(sorted: JournalEntry[]): DepthSignals {
  const threads = buildConversationThreadsReport(sorted).threads.filter(
    (thread) => thread.mentionCount >= 2,
  );
  const changeMoments = buildChangeMomentsReport(sorted, {
    context: "memory",
    limit: 6,
  }).notes;
  const relationshipNotes = buildRelationshipContinuityReport(sorted, {
    context: "memory",
    limit: 6,
  }).notes;

  return {
    connectedThreadCount: threads.length,
    strongThreadCount: threads.filter((thread) => thread.mentionCount >= 3).length,
    revisitLinkCount: countRevisitLinks(sorted),
    themeShiftCount: Math.max(countThemeShifts(sorted), changeMoments.length >= 2 ? 2 : changeMoments.length),
    relationshipDepth: relationshipNotes.length,
    landmarkSpanDays: measureLandmarkSpan(sorted),
  };
}

function scoreReflectionsConnecting(signals: DepthSignals): number {
  let score = 0;
  if (signals.connectedThreadCount >= 2) score += 18;
  if (signals.connectedThreadCount >= 3) score += 12;
  if (signals.revisitLinkCount >= 4) score += 22;
  if (signals.revisitLinkCount >= 6) score += 10;
  if (signals.themeShiftCount >= 2) score += 18;
  if (signals.themeShiftCount >= 1) score += 8;
  if (signals.relationshipDepth >= 2) score += 14;
  if (signals.landmarkSpanDays >= 21) score += 8;
  return score;
}

function scoreThreadsWorthReturning(signals: DepthSignals): number {
  let score = 0;
  if (signals.connectedThreadCount >= 2) score += 24;
  if (signals.connectedThreadCount >= 3) score += 16;
  if (signals.strongThreadCount >= 1) score += 22;
  if (signals.strongThreadCount >= 2) score += 14;
  if (signals.connectedThreadCount >= 4) score += 12;
  return score;
}

function scoreOlderEntriesContext(signals: DepthSignals): number {
  let score = 0;
  if (signals.landmarkSpanDays >= 30) score += 26;
  if (signals.landmarkSpanDays >= 14) score += 14;
  if (signals.revisitLinkCount >= 3) score += 22;
  if (signals.revisitLinkCount >= 5) score += 10;
  if (signals.relationshipDepth >= 1) score += 16;
  if (signals.relationshipDepth >= 3) score += 12;
  if (signals.themeShiftCount >= 1) score += 10;
  return score;
}

function meetsKindThreshold(kind: ContinuityDepthKind, signals: DepthSignals): boolean {
  switch (kind) {
    case "reflections_connecting":
      return (
        signals.connectedThreadCount >= 2 &&
        signals.revisitLinkCount >= 4 &&
        (signals.themeShiftCount >= 1 || signals.relationshipDepth >= 2)
      );
    case "threads_worth_returning":
      return signals.connectedThreadCount >= 2 && signals.strongThreadCount >= 1;
    case "older_entries_context":
      return (
        signals.landmarkSpanDays >= 14 &&
        signals.revisitLinkCount >= 3 &&
        signals.relationshipDepth >= 1
      );
    default:
      return false;
  }
}

function scoreForKind(kind: ContinuityDepthKind, signals: DepthSignals): number {
  switch (kind) {
    case "reflections_connecting":
      return scoreReflectionsConnecting(signals);
    case "threads_worth_returning":
      return scoreThreadsWorthReturning(signals);
    case "older_entries_context":
      return scoreOlderEntriesContext(signals);
    default:
      return 0;
  }
}

function pickIndicator(signals: DepthSignals): ContinuityDepthIndicator | null {
  const ranked = KIND_PRIORITY.map((kind) => ({
    kind,
    strength: scoreForKind(kind, signals),
  }))
    .filter((row) => row.strength >= STRONG_MIN)
    .filter((row) => meetsKindThreshold(row.kind, signals))
    .filter((row) => !isTextFatigued(COPY[row.kind]))
    .filter((row) => row.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength);

  const best = ranked[0];
  if (!best) return null;
  if (!helpsOrient(COPY[best.kind], best.strength)) return null;

  return {
    id: `continuity-depth-${best.kind}`,
    kind: best.kind,
    text: COPY[best.kind],
    strength: best.strength,
  };
}

/** Detect rare accumulated continuity — one subtle line when the archive has depth. */
export function buildContinuityDepthReport(
  entries: JournalEntry[],
  options: ContinuityDepthOptions,
): ContinuityDepthReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return { indicator: null, hasData: false };
  }

  if (isSurfaceFatigued(options.context)) {
    return { indicator: null, hasData: false };
  }

  const state =
    options.context === "homepage" ? bumpContinuityDepthSession() : readState();

  if (options.context === "homepage" && !canShowOnHomepage(state)) {
    return { indicator: null, hasData: false };
  }

  if (options.context === "memory" && !canShowOnMemory(state)) {
    return { indicator: null, hasData: false };
  }

  const signals = measureSignals(sorted);
  const indicator = pickIndicator(signals);
  if (!indicator) {
    return { indicator: null, hasData: false };
  }

  if (options.record !== false) {
    recordIndicatorShown(indicator, options.context);
  }

  return { indicator, hasData: true };
}

export function homepageContinuityDepthIndicator(
  entries: JournalEntry[],
): ContinuityDepthIndicator | null {
  return buildContinuityDepthReport(entries, { context: "homepage" }).indicator;
}

export function memoryContinuityDepthIndicator(
  entries: JournalEntry[],
): ContinuityDepthIndicator | null {
  return buildContinuityDepthReport(entries, { context: "memory" }).indicator;
}
