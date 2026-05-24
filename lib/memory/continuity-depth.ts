import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { revisitedEntryCount } from "@/lib/callback-interaction-signals";
import { getAllBookmarks } from "@/lib/reflection-bookmarks";
import { measureArchiveGrowthDepthSignals } from "@/lib/memory/archive-growth";
import { measureThreadDepthSignals } from "@/lib/memory/conversation-threads";
import { measureMilestoneDepthSignals } from "@/lib/memory/milestones";
import { measureSeasonDepthSignals } from "@/lib/memory/seasons";
import { buildChangeMomentsReport } from "@/lib/memory/change-moments";
import { buildRelationshipContinuityReport } from "@/lib/memory/relationship-continuity";
import { buildRevisitationReport } from "@/lib/memory/revisitation";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { buildMemoryNotesReport } from "@/lib/patterns/memory-notes";
import type {
  ContinuityDepthContext,
  ContinuityDepthCopyExample,
  ContinuityDepthIndicator,
  ContinuityDepthKind,
  ContinuityDepthReport,
} from "@/types/continuity-depth";
import type { JournalEntry } from "@/types/journal";

const DEPTH_KEY = "voicememory_continuity_depth";
const MIN_ENTRIES = 16;
const MIN_MONTHS = 3;
const MIN_SPAN_DAYS = 45;
const STRONG_MIN = 72;
const MIN_SESSIONS = 6;
const MIN_DAYS = 16;
const TEXT_COOLDOWN_DAYS = 28;
const SURFACE_COOLDOWN_DAYS = 12;

const COPY: Record<ContinuityDepthKind, string> = {
  older_entries_context: "Older entries are beginning to carry context.",
  reflections_connecting: "More of this is starting to connect.",
  period_read_differently: "This period is beginning to read differently.",
  threads_worth_returning: "There are a few threads worth returning to.",
};

const KIND_PRIORITY: ContinuityDepthKind[] = [
  "older_entries_context",
  "reflections_connecting",
  "period_read_differently",
  "threads_worth_returning",
];

export const CONTINUITY_DEPTH_COPY_EXAMPLES: ContinuityDepthCopyExample[] = [
  {
    kind: "older_entries_context",
    message: COPY.older_entries_context,
    whenShown:
      "Older reflections, revisit links, and bookmarks give earlier entries surrounding context",
  },
  {
    kind: "reflections_connecting",
    message: COPY.reflections_connecting,
    whenShown: "Themes and threads bridge weeks or months with enough overlap to feel linked",
  },
  {
    kind: "period_read_differently",
    message: COPY.period_read_differently,
    whenShown: "A recurring theme or season reads with a different tone than before",
  },
  {
    kind: "threads_worth_returning",
    message: COPY.threads_worth_returning,
    whenShown: "Several conversation threads span multiple reflections with enough depth to revisit",
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
  archiveSpanDays: number;
  monthCount: number;
  connectedThreadCount: number;
  multiMonthThreadCount: number;
  strongThreadCount: number;
  crossMonthThemes: number;
  oldEntryBridges: number;
  toneEvolutionThemes: number;
  revisitationThemes: number;
  distinguishablePeriodCount: number;
  toneShiftPeriodCount: number;
  milestoneCount: number;
  oldEntryMilestoneCount: number;
  revisitLinkCount: number;
  themeShiftCount: number;
  relationshipDepth: number;
  landmarkSpanDays: number;
  bookmarkedCount: number;
  revisitedCount: number;
}

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function uniqueMonths(entries: JournalEntry[]): string[] {
  return [...new Set(entries.map((entry) => toDayKey(entry.createdAt).slice(0, 7)))].sort();
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
    }
  }
  return count;
}

function countRevisitLinks(sorted: JournalEntry[]): number {
  const linked = new Set<string>();
  const anchors = sorted.slice(-Math.min(sorted.length, 10));

  for (const anchor of anchors) {
    const report = buildRevisitationReport(sorted, {
      context: "memory",
      entryId: anchor.id,
      limit: 1,
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

function measureEngagementDepth(): { bookmarkedCount: number; revisitedCount: number } {
  return {
    bookmarkedCount: isBrowser() ? getAllBookmarks().length : 0,
    revisitedCount: revisitedEntryCount(),
  };
}

function measureSignals(sorted: JournalEntry[]): DepthSignals {
  const threads = measureThreadDepthSignals(sorted);
  const seasons = measureSeasonDepthSignals(sorted);
  const milestones = measureMilestoneDepthSignals(sorted);
  const archive = measureArchiveGrowthDepthSignals(sorted);
  const changeMoments = buildChangeMomentsReport(sorted, {
    context: "memory",
    limit: 4,
  }).notes;
  const relationshipNotes = buildRelationshipContinuityReport(sorted, {
    context: "memory",
    limit: 4,
  }).notes;
  const engagement = measureEngagementDepth();

  return {
    archiveSpanDays: archive.archiveSpanDays,
    monthCount: uniqueMonths(sorted).length,
    connectedThreadCount: threads.connectedThreadCount,
    multiMonthThreadCount: threads.multiMonthThreadCount,
    strongThreadCount: threads.strongThreadCount,
    crossMonthThemes: archive.crossMonthThemes,
    oldEntryBridges: archive.oldEntryBridges,
    toneEvolutionThemes: archive.toneEvolutionThemes,
    revisitationThemes: archive.revisitationThemes,
    distinguishablePeriodCount: seasons.distinguishablePeriodCount,
    toneShiftPeriodCount: seasons.toneShiftPeriodCount,
    milestoneCount: milestones.milestoneCount,
    oldEntryMilestoneCount: milestones.oldEntryMilestoneCount,
    revisitLinkCount: countRevisitLinks(sorted),
    themeShiftCount: Math.max(countThemeShifts(sorted), changeMoments.length >= 2 ? 2 : 0),
    relationshipDepth: relationshipNotes.length,
    landmarkSpanDays: measureLandmarkSpan(sorted),
    bookmarkedCount: engagement.bookmarkedCount,
    revisitedCount: engagement.revisitedCount,
  };
}

/** True when the archive is deep enough for a sparse depth line. */
export function isArchiveDeep(entries: JournalEntry[]): boolean {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) return false;
  if (uniqueMonths(sorted).length < MIN_MONTHS) return false;

  const span = daysBetweenKeys(
    toDayKey(sorted[0].createdAt),
    toDayKey(sorted[sorted.length - 1].createdAt),
  );
  return span >= MIN_SPAN_DAYS;
}

function scoreOlderEntriesContext(signals: DepthSignals): number {
  let score = 0;
  if (signals.landmarkSpanDays >= 30) score += 24;
  if (signals.landmarkSpanDays >= 14) score += 12;
  if (signals.oldEntryBridges >= 4) score += 22;
  if (signals.oldEntryMilestoneCount >= 1) score += 18;
  if (signals.revisitLinkCount >= 3) score += 20;
  if (signals.bookmarkedCount >= 1) score += 14;
  if (signals.revisitedCount >= 2) score += 16;
  if (signals.relationshipDepth >= 1) score += 12;
  return score;
}

function scoreReflectionsConnecting(signals: DepthSignals): number {
  let score = 0;
  if (signals.crossMonthThemes >= 2) score += 24;
  if (signals.oldEntryBridges >= 6) score += 18;
  if (signals.connectedThreadCount >= 2) score += 16;
  if (signals.revisitationThemes >= 2) score += 18;
  if (signals.themeShiftCount >= 1) score += 12;
  if (signals.relationshipDepth >= 2) score += 14;
  return score;
}

function scorePeriodReadDifferently(signals: DepthSignals): number {
  let score = 0;
  if (signals.toneEvolutionThemes >= 1) score += 24;
  if (signals.toneShiftPeriodCount >= 2) score += 20;
  if (signals.themeShiftCount >= 2) score += 18;
  if (signals.distinguishablePeriodCount >= 2) score += 14;
  if (signals.multiMonthThreadCount >= 1) score += 12;
  return score;
}

function scoreThreadsWorthReturning(signals: DepthSignals): number {
  let score = 0;
  if (signals.strongThreadCount >= 2) score += 26;
  if (signals.strongThreadCount >= 1) score += 18;
  if (signals.multiMonthThreadCount >= 2) score += 20;
  if (signals.connectedThreadCount >= 3) score += 16;
  if (signals.revisitedCount >= 2) score += 12;
  if (signals.bookmarkedCount >= 1) score += 10;
  return score;
}

function meetsKindThreshold(kind: ContinuityDepthKind, signals: DepthSignals): boolean {
  switch (kind) {
    case "older_entries_context":
      return (
        signals.archiveSpanDays >= MIN_SPAN_DAYS &&
        (signals.landmarkSpanDays >= 14 ||
          signals.oldEntryMilestoneCount >= 1 ||
          signals.revisitLinkCount >= 3) &&
        (signals.bookmarkedCount >= 1 ||
          signals.revisitedCount >= 2 ||
          signals.oldEntryBridges >= 4)
      );
    case "reflections_connecting":
      return (
        signals.crossMonthThemes >= 2 ||
        (signals.connectedThreadCount >= 2 &&
          signals.oldEntryBridges >= 4 &&
          signals.revisitationThemes >= 2)
      );
    case "period_read_differently":
      return (
        signals.toneEvolutionThemes >= 1 ||
        (signals.toneShiftPeriodCount >= 2 && signals.themeShiftCount >= 1)
      );
    case "threads_worth_returning":
      return (
        signals.strongThreadCount >= 1 &&
        signals.connectedThreadCount >= 2 &&
        signals.multiMonthThreadCount >= 1
      );
    default:
      return false;
  }
}

function scoreForKind(kind: ContinuityDepthKind, signals: DepthSignals): number {
  switch (kind) {
    case "older_entries_context":
      return scoreOlderEntriesContext(signals);
    case "reflections_connecting":
      return scoreReflectionsConnecting(signals);
    case "period_read_differently":
      return scorePeriodReadDifferently(signals);
    case "threads_worth_returning":
      return scoreThreadsWorthReturning(signals);
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
  if (!isArchiveDeep(entries)) {
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

  const sorted = sortedEntries(entries);
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

/** Max one archive-depth line for homepage or memory. */
export function pickArchiveDepthIndicator(
  entries: JournalEntry[],
  context: ContinuityDepthContext,
): ContinuityDepthIndicator | null {
  return buildContinuityDepthReport(entries, { context }).indicator;
}

export function homepageContinuityDepthIndicator(
  entries: JournalEntry[],
): ContinuityDepthIndicator | null {
  return pickArchiveDepthIndicator(entries, "homepage");
}

export function memoryContinuityDepthIndicator(
  entries: JournalEntry[],
): ContinuityDepthIndicator | null {
  return pickArchiveDepthIndicator(entries, "memory");
}
