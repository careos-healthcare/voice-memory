import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { getResurfacingFatigueRecords } from "@/lib/memory/resurfacing-priority";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type {
  ArchiveGrowthContext,
  ArchiveGrowthKind,
  ArchiveGrowthNote,
  ArchiveGrowthReport,
} from "@/types/archive-growth";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";

const ACCUMULATION_KEY = "voicememory_archive_accumulation";
const MIN_ENTRIES = 16;
const MIN_MONTHS = 3;
const STRONG_MIN = 68;
const MIN_SESSIONS = 5;
const MIN_DAYS = 12;
const TEXT_COOLDOWN_DAYS = 28;
const MEMORY_STRONG_MIN = 68;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely|mum|dad)\b/gi;
const LOOP_RE =
  /\b(same loop|keep coming back|again before|that loop|same pattern|i keep)\b/i;

export interface ArchiveGrowthOptions {
  context: ArchiveGrowthContext;
  meaningfulTiming?: boolean;
  record?: boolean;
}

interface AccumulationState {
  sessionCount: number;
  lastSessionDay: string;
  sessionsAtLastShow: number;
  lastShownAt: number;
  records: Array<{
    noteId: string;
    textKey: string;
    surface: ArchiveGrowthContext;
    shownAt: number;
  }>;
}

const CONTEXT_KIND_PRIORITY: Record<ArchiveGrowthContext, ArchiveGrowthKind[]> = {
  homepage: ["connecting_older", "more_familiar", "starting_to_relate", "more_continuity"],
  monthly: ["more_continuity", "read_differently", "connecting_older", "starting_to_relate"],
  memory: ["starting_to_relate", "read_differently", "more_familiar", "connecting_older"],
};

const COPY: Record<ArchiveGrowthKind, string> = {
  connecting_older: "Older reflections are starting to mean something different.",
  read_differently: "You were carrying this differently then.",
  more_familiar: "More of this is starting to mean something.",
  more_continuity: "More of this is starting to mean something.",
  starting_to_relate: "More of this is starting to mean something.",
};

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function textKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 72);
}

function monthKey(iso: string): string {
  return toDayKey(iso).slice(0, 7);
}

function uniqueMonths(entries: JournalEntry[]): string[] {
  return [...new Set(entries.map((entry) => monthKey(entry.createdAt)))].sort();
}

function readState(): AccumulationState {
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
    const raw = localStorage.getItem(ACCUMULATION_KEY);
    if (!raw) {
      return {
        sessionCount: 0,
        lastSessionDay: "",
        sessionsAtLastShow: 0,
        lastShownAt: 0,
        records: [],
      };
    }
    const parsed = JSON.parse(raw) as AccumulationState;
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

function writeState(state: AccumulationState): void {
  if (!isBrowser()) return;
  localStorage.setItem(ACCUMULATION_KEY, JSON.stringify(state));
}

export function bumpArchiveSession(): AccumulationState {
  const today = toDayKey(new Date().toISOString());
  const state = readState();
  if (state.lastSessionDay !== today) {
    state.sessionCount += 1;
    state.lastSessionDay = today;
    writeState(state);
  }
  return state;
}

export function clearArchiveAccumulationMemory(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(ACCUMULATION_KEY);
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

function hasMeaningfulRecentTiming(): boolean {
  const recent = getResurfacingFatigueRecords().filter(
    (record) =>
      daysSince(record.shownAt) <= 3 &&
      (record.category === "change_moment" ||
        record.category === "emotional_contrast" ||
        record.category === "first_calmer" ||
        record.category === "loop_long_silence"),
  );
  return recent.length > 0;
}

function canShowArchiveNote(
  state: AccumulationState,
  meaningfulTiming: boolean,
): boolean {
  const sessionsSince = state.sessionCount - state.sessionsAtLastShow;
  const requiredSessions = meaningfulTiming ? Math.max(2, MIN_SESSIONS - 2) : MIN_SESSIONS;
  const requiredDays = meaningfulTiming ? Math.max(4, MIN_DAYS - 3) : MIN_DAYS;

  if (sessionsSince < requiredSessions) return false;
  if (daysSince(state.lastShownAt) < requiredDays) return false;
  return true;
}

function recordArchiveShown(
  note: ArchiveGrowthNote,
  context: ArchiveGrowthContext,
): void {
  const state = readState();
  const now = Date.now();
  state.lastShownAt = now;
  state.sessionsAtLastShow = state.sessionCount;
  state.records = [
    ...state.records,
    {
      noteId: note.id,
      textKey: textKey(note.text),
      surface: context,
      shownAt: now,
    },
  ].slice(-20);
  writeState(state);
}

function evidencePair(past: JournalEntry, current: JournalEntry) {
  return {
    pastQuote: snippet(past),
    currentQuote: snippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
    pastEntryId: past.id,
    entryId: current.id,
  };
}

function hasEvidence(
  item: Pick<
    ArchiveGrowthNote,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function pushCandidate(
  bucket: ArchiveGrowthNote[],
  item: Omit<ArchiveGrowthNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < STRONG_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  if (isTextFatigued(item.text)) return;
  bucket.push({ ...item, strength });
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

function detectCrossMonthContinuity(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  const notes: ArchiveGrowthNote[] = [];
  const months = uniqueMonths(sorted);
  if (months.length < MIN_MONTHS) return notes;

  const recentMonths = months.slice(-2);
  const priorMonths = months.slice(0, -2);
  if (priorMonths.length === 0) return notes;

  let bridgingThemes = 0;
  let samplePast: JournalEntry | null = null;
  let sampleCurrent: JournalEntry | null = null;

  for (const [, hits] of themeMap(sorted)) {
    const monthSet = new Set(hits.map((entry) => monthKey(entry.createdAt)));
    const inRecent = recentMonths.some((month) => monthSet.has(month));
    const inPrior = priorMonths.some((month) => monthSet.has(month));
    if (!inRecent || !inPrior || hits.length < 3) continue;

    bridgingThemes += 1;
    samplePast = hits[0];
    sampleCurrent = hits[hits.length - 1];
  }

  if (bridgingThemes < 2 || !samplePast || !sampleCurrent) return notes;

  pushCandidate(notes, {
    id: `archive-connect-${sampleCurrent.id}`,
    kind: "connecting_older",
    text: COPY.connecting_older,
    strength: 65 + bridgingThemes * 2,
    ...evidencePair(samplePast, sampleCurrent),
  });

  return notes;
}

function detectRevisitationGrowth(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  const notes: ArchiveGrowthNote[] = [];
  let revisitThemes = 0;
  let samplePast: JournalEntry | null = null;
  let sampleCurrent: JournalEntry | null = null;

  for (const [, hits] of themeMap(sorted)) {
    if (hits.length < 3) continue;
    const gaps: number[] = [];
    for (let i = 1; i < hits.length; i += 1) {
      gaps.push(
        daysBetweenKeys(toDayKey(hits[i - 1].createdAt), toDayKey(hits[i].createdAt)),
      );
    }
    const longGaps = gaps.filter((gap) => gap >= 14).length;
    if (longGaps >= 1) {
      revisitThemes += 1;
      samplePast = hits[hits.length - 2];
      sampleCurrent = hits[hits.length - 1];
    }
  }

  if (revisitThemes < 2 || !samplePast || !sampleCurrent) return notes;

  pushCandidate(notes, {
    id: `archive-relate-${sampleCurrent.id}`,
    kind: "starting_to_relate",
    text: COPY.starting_to_relate,
    strength: 64 + revisitThemes * 2,
    ...evidencePair(samplePast, sampleCurrent),
  });

  return notes;
}

function detectLoopEvolution(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  const notes: ArchiveGrowthNote[] = [];

  for (const [theme, hits] of themeMap(sorted)) {
    if (hits.length < 4) continue;
    const loopHits = hits.filter(
      (entry) => LOOP_RE.test(entry.transcript) || countMatches(entry.transcript, HEDGE_RE) >= 2,
    );
    if (loopHits.length < 2) continue;

    const early = loopHits.slice(0, Math.ceil(loopHits.length / 2));
    const late = loopHits.slice(Math.ceil(loopHits.length / 2));
    const earlyAvg = roundAvg(early.map((entry) => entry.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((entry) => entry.reflection.emotionalIntensity));
    const earlyHedge = roundAvg(early.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
    const lateHedge = roundAvg(late.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
    const earlyDirect = roundAvg(early.map((entry) => countMatches(entry.transcript, DIRECT_RE)));
    const lateDirect = roundAvg(late.map((entry) => countMatches(entry.transcript, DIRECT_RE)));

    const evolved =
      lateAvg <= earlyAvg - 1 ||
      lateHedge <= earlyHedge - 0.8 ||
      lateDirect >= earlyDirect + 0.8;
    if (!evolved) continue;

    pushCandidate(notes, {
      id: `archive-loop-evolve-${theme}-${late[late.length - 1].id}`,
      kind: "read_differently",
      text: COPY.read_differently,
      strength: 66 + loopHits.length,
      ...evidencePair(early[0], late[late.length - 1]),
    });
    break;
  }

  return notes;
}

function detectEmotionalDensity(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: ArchiveGrowthNote[] = [];
  const mid = Math.floor(sorted.length / 2);
  const early = sorted.slice(0, mid);
  const late = sorted.slice(mid);
  const earlyThemes = roundAvg(early.map((entry) => entry.reflection.recurringThemes.length));
  const lateThemes = roundAvg(late.map((entry) => entry.reflection.recurringThemes.length));
  const earlyIntensity = roundAvg(early.map((entry) => entry.reflection.emotionalIntensity));
  const lateIntensity = roundAvg(late.map((entry) => entry.reflection.emotionalIntensity));

  if (lateThemes < earlyThemes + 0.4 && lateIntensity <= earlyIntensity) return notes;

  pushCandidate(notes, {
    id: `archive-density-${late[late.length - 1].id}`,
    kind: "more_familiar",
    text: COPY.more_familiar,
    strength: 64 + Math.round((lateThemes - earlyThemes) * 4 + late.length / 4),
    ...evidencePair(early[Math.max(0, early.length - 2)], late[late.length - 1]),
  });
  return notes;
}

function detectConnectingReferences(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  const notes: ArchiveGrowthNote[] = [];
  let bridges = 0;
  let samplePast: JournalEntry | null = null;
  let sampleCurrent: JournalEntry | null = null;

  for (let i = 0; i < sorted.length; i += 1) {
    for (let j = i + 1; j < sorted.length; j += 1) {
      const gap = daysBetweenKeys(
        toDayKey(sorted[i].createdAt),
        toDayKey(sorted[j].createdAt),
      );
      if (gap < 21) continue;
      const shared = sorted[i].reflection.recurringThemes.some((theme) =>
        sorted[j].reflection.recurringThemes.some(
          (other) => other.toLowerCase() === theme.toLowerCase(),
        ),
      );
      if (!shared) continue;
      bridges += 1;
      samplePast = sorted[i];
      sampleCurrent = sorted[j];
    }
  }

  if (bridges < 4 || !samplePast || !sampleCurrent) return notes;

  pushCandidate(notes, {
    id: `archive-bridge-${sampleCurrent.id}`,
    kind: "starting_to_relate",
    text: COPY.starting_to_relate,
    strength: 65 + Math.min(bridges, 8),
    ...evidencePair(samplePast, sampleCurrent),
  });

  return notes;
}

function detectCalmerDirectThemes(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  const notes: ArchiveGrowthNote[] = [];

  for (const [theme, hits] of themeMap(sorted)) {
    if (hits.length < 4) continue;
    const early = hits.slice(0, Math.floor(hits.length / 2));
    const late = hits.slice(Math.floor(hits.length / 2));
    const earlyAvg = roundAvg(early.map((entry) => entry.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((entry) => entry.reflection.emotionalIntensity));
    const earlyHedge = roundAvg(early.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
    const lateHedge = roundAvg(late.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
    const lateDirect = roundAvg(late.map((entry) => countMatches(entry.transcript, DIRECT_RE)));
    const earlyDirect = roundAvg(early.map((entry) => countMatches(entry.transcript, DIRECT_RE)));

    const calmer = lateAvg <= earlyAvg - 1.2;
    const moreDirect = lateDirect >= earlyDirect + 0.8 || lateHedge <= earlyHedge - 0.8;
    if (!calmer && !moreDirect) continue;

    pushCandidate(notes, {
      id: `archive-calmer-${theme}-${late[late.length - 1].id}`,
      kind: "more_continuity",
      text: COPY.more_continuity,
      strength: 66 + hits.length,
      ...evidencePair(early[early.length - 1], late[late.length - 1]),
    });
    break;
  }

  return notes;
}

function detectOlderNewerContinuity(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  if (sorted.length < MIN_ENTRIES) return [];

  const notes: ArchiveGrowthNote[] = [];
  const early = sorted.slice(0, Math.max(3, Math.floor(sorted.length * 0.35)));
  const late = sorted.slice(-Math.max(3, Math.floor(sorted.length * 0.35)));
  const earlyThemes = new Set(
    early.flatMap((entry) => entry.reflection.recurringThemes.map((theme) => theme.toLowerCase())),
  );
  const overlap = late.filter((entry) =>
    entry.reflection.recurringThemes.some((theme) => earlyThemes.has(theme.toLowerCase())),
  );

  if (overlap.length < 2) return notes;

  pushCandidate(notes, {
    id: `archive-older-newer-${late[late.length - 1].id}`,
    kind: "connecting_older",
    text: COPY.connecting_older,
    strength: 65 + overlap.length * 2,
    ...evidencePair(early[early.length - 1], late[late.length - 1]),
  });
  return notes;
}

function collectCandidates(sorted: JournalEntry[]): ArchiveGrowthNote[] {
  return [
    ...detectCrossMonthContinuity(sorted),
    ...detectRevisitationGrowth(sorted),
    ...detectLoopEvolution(sorted),
    ...detectEmotionalDensity(sorted),
    ...detectConnectingReferences(sorted),
    ...detectCalmerDirectThemes(sorted),
    ...detectOlderNewerContinuity(sorted),
  ];
}

function dedupeNotes(notes: ArchiveGrowthNote[]): ArchiveGrowthNote[] {
  const seen = new Set<string>();
  return notes
    .filter((note) => note.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((note) => {
      const key = `${note.kind}:${note.text}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(
  candidates: ArchiveGrowthNote[],
  context: ArchiveGrowthContext,
  minStrength: number,
): ArchiveGrowthNote[] {
  const sorted = dedupeNotes(candidates).filter((note) => note.strength >= minStrength);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: ArchiveGrowthNote[] = [];
  const usedKinds = new Set<ArchiveGrowthKind>();

  for (const kind of priority) {
    const match = sorted.find((note) => note.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
      break;
    }
  }

  if (picked.length === 0 && sorted.length > 0) {
    picked.push(sorted[0]);
  }

  return picked.slice(0, 1);
}

/** Detect sparse archive-growth notes — continuity compounding over time. */
export function buildArchiveGrowthReport(
  entries: JournalEntry[],
  options: ArchiveGrowthOptions,
): ArchiveGrowthReport {
  const sorted = sortedEntries(entries);
  const months = uniqueMonths(sorted);

  if (sorted.length < MIN_ENTRIES || months.length < MIN_MONTHS) {
    return { notes: [], hasData: false };
  }

  const state = bumpArchiveSession();
  const meaningfulTiming =
    (options.meaningfulTiming ?? false) || hasMeaningfulRecentTiming();

  if (!canShowArchiveNote(state, meaningfulTiming)) {
    return { notes: [], hasData: false };
  }

  const minStrength = options.context === "memory" ? MEMORY_STRONG_MIN : STRONG_MIN;
  const candidates = collectCandidates(sorted);
  const notes = pickForContext(candidates, options.context, minStrength);

  if (notes.length > 0 && options.record !== false) {
    recordArchiveShown(notes[0], options.context);
  }

  return { notes, hasData: notes.length > 0 };
}

export function archiveGrowthToNotes(notes: ArchiveGrowthNote[]): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "changed" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
    pastDateLabel: note.pastDateLabel,
    currentDateLabel: note.currentDateLabel,
  }));
}

export function homepageArchiveGrowthNotes(
  entries: JournalEntry[],
  meaningfulTiming = false,
): MemoryNote[] {
  return applyMemoryHierarchy(
    archiveGrowthToNotes(
      buildArchiveGrowthReport(entries, {
        context: "homepage",
        meaningfulTiming,
      }).notes,
    ),
    entries,
    1,
  );
}

export function monthlyArchiveGrowthNotes(
  entries: JournalEntry[],
  meaningfulTiming = false,
): MemoryNote[] {
  return applyMemoryHierarchy(
    archiveGrowthToNotes(
      buildArchiveGrowthReport(entries, {
        context: "monthly",
        meaningfulTiming,
      }).notes,
    ),
    entries,
    1,
  );
}

export function memoryArchiveGrowthNotes(
  entries: JournalEntry[],
  meaningfulTiming = false,
): MemoryNote[] {
  return applyMemoryHierarchy(
    archiveGrowthToNotes(
      buildArchiveGrowthReport(entries, {
        context: "memory",
        meaningfulTiming,
      }).notes,
    ),
    entries,
    1,
  );
}

export interface ArchiveGrowthDepthSignals {
  crossMonthThemes: number;
  oldEntryBridges: number;
  toneEvolutionThemes: number;
  revisitationThemes: number;
  archiveSpanDays: number;
}

/** Measure archive compounding for depth lines — internal scoring only. */
export function measureArchiveGrowthDepthSignals(
  entries: JournalEntry[],
): ArchiveGrowthDepthSignals {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_ENTRIES) {
    return {
      crossMonthThemes: 0,
      oldEntryBridges: 0,
      toneEvolutionThemes: 0,
      revisitationThemes: 0,
      archiveSpanDays: 0,
    };
  }

  const months = uniqueMonths(sorted);
  let crossMonthThemes = 0;
  if (months.length >= MIN_MONTHS) {
    const recentMonths = months.slice(-2);
    const priorMonths = months.slice(0, -2);
    for (const [, hits] of themeMap(sorted)) {
      const monthSet = new Set(hits.map((entry) => monthKey(entry.createdAt)));
      const inRecent = recentMonths.some((month) => monthSet.has(month));
      const inPrior = priorMonths.some((month) => monthSet.has(month));
      if (inRecent && inPrior && hits.length >= 3) crossMonthThemes += 1;
    }
  }

  let revisitationThemes = 0;
  for (const [, hits] of themeMap(sorted)) {
    if (hits.length < 3) continue;
    const gaps = hits.slice(1).map((entry, i) =>
      daysBetweenKeys(toDayKey(hits[i].createdAt), toDayKey(entry.createdAt)),
    );
    if (gaps.some((gap) => gap >= 14)) revisitationThemes += 1;
  }

  let toneEvolutionThemes = 0;
  for (const [, hits] of themeMap(sorted)) {
    if (hits.length < 4) continue;
    const early = hits.slice(0, Math.floor(hits.length / 2));
    const late = hits.slice(Math.floor(hits.length / 2));
    const earlyAvg = roundAvg(early.map((entry) => entry.reflection.emotionalIntensity));
    const lateAvg = roundAvg(late.map((entry) => entry.reflection.emotionalIntensity));
    const earlyHedge = roundAvg(early.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
    const lateHedge = roundAvg(late.map((entry) => countMatches(entry.transcript, HEDGE_RE)));
    const earlyDirect = roundAvg(early.map((entry) => countMatches(entry.transcript, DIRECT_RE)));
    const lateDirect = roundAvg(late.map((entry) => countMatches(entry.transcript, DIRECT_RE)));
    if (
      lateAvg <= earlyAvg - 1 ||
      lateHedge <= earlyHedge - 0.8 ||
      lateDirect >= earlyDirect + 0.8
    ) {
      toneEvolutionThemes += 1;
    }
  }

  let oldEntryBridges = 0;
  for (let i = 0; i < sorted.length; i += 1) {
    for (let j = i + 1; j < sorted.length; j += 1) {
      const gap = daysBetweenKeys(
        toDayKey(sorted[i].createdAt),
        toDayKey(sorted[j].createdAt),
      );
      if (gap < 21) continue;
      const shared = sorted[i].reflection.recurringThemes.some((theme) =>
        sorted[j].reflection.recurringThemes.some(
          (other) => other.toLowerCase() === theme.toLowerCase(),
        ),
      );
      if (shared) oldEntryBridges += 1;
    }
  }

  return {
    crossMonthThemes,
    oldEntryBridges,
    toneEvolutionThemes,
    revisitationThemes,
    archiveSpanDays: daysBetweenKeys(
      toDayKey(sorted[0].createdAt),
      toDayKey(sorted[sorted.length - 1].createdAt),
    ),
  };
}
