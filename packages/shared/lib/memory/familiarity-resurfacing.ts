import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  applyResurfacingRarity,
  candidateFromFamiliarityResurfacingNote,
  gapDaysBetweenEntries,
  type ResurfacingSurface,
} from "@/lib/memory/resurfacing-priority";
import {
  hasTheme,
  languageShiftOnTheme,
} from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type {
  FamiliarityResurfacingContext,
  FamiliarityResurfacingKind,
  FamiliarityResurfacingNote,
  FamiliarityResurfacingReport,
} from "@/types/familiarity-resurfacing";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";

const MIN_ENTRIES = 4;
const STRONG_MIN = 62;
const MIN_GAP_DAYS = 14;
const MIN_SHIFT_GAP_DAYS = 21;

const HEDGE_RE =
  /\b(maybe|sort of|kind of|probably|not sure|something|stuff|indirectly|i guess|vague)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|mum|dad|mother|father|clearly|for sure|definitely|plan)\b/gi;
const LOOP_RE =
  /\b(same loop|loop came back|keep coming back|again before|that loop|same pattern|i keep)\b/i;

export interface FamiliarityResurfacingOptions {
  context: FamiliarityResurfacingContext;
  entryId?: string;
  limit?: number;
}

const CONTEXT_KIND_PRIORITY: Record<
  FamiliarityResurfacingContext,
  FamiliarityResurfacingKind[]
> = {
  homepage: ["sound_different", "earlier_loop", "first_calmer_topic", "before_direct_naming"],
  entry: [
    "sound_different",
    "before_direct_naming",
    "first_calmer_topic",
    "earlier_loop",
    "before_major_shift",
    "monthly_contrast",
  ],
  timeline: [
    "before_major_shift",
    "monthly_contrast",
    "sound_different",
    "earlier_loop",
    "first_calmer_topic",
  ],
  monthly: ["monthly_contrast", "before_major_shift", "first_calmer_topic", "sound_different"],
  memory: [
    "earlier_loop",
    "before_major_shift",
    "sound_different",
    "before_direct_naming",
    "first_calmer_topic",
  ],
};

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

function countMatches(text: string, re: RegExp): number {
  return text.match(re)?.length ?? 0;
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function themeLabel(theme: string): string {
  return theme.toLowerCase();
}

function evidence(past: JournalEntry, current: JournalEntry) {
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
    FamiliarityResurfacingNote,
    "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel"
  >,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function gapDays(past: JournalEntry, current: JournalEntry): number {
  return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((t) => t.toLowerCase()));
  return a.reflection.recurringThemes.filter((t) => setB.has(t.toLowerCase()));
}

function pushCandidate(
  bucket: FamiliarityResurfacingNote[],
  item: Omit<FamiliarityResurfacingNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < STRONG_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectSoundDifferent(
  current: JournalEntry,
  prior: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];

  for (const past of [...prior].reverse()) {
    if (gapDays(past, current) < MIN_SHIFT_GAP_DAYS) continue;

    const themes = sharedThemes(past, current);
    const intensityDelta = Math.abs(
      current.reflection.emotionalIntensity - past.reflection.emotionalIntensity,
    );
    const shift =
      themes.length > 0 ? languageShiftOnTheme(past, current) : { hedgeDelta: 0, directDelta: 0 };
    const languageFlip = shift.hedgeDelta >= 1 || shift.directDelta >= 2;

    if (intensityDelta < 2 && !languageFlip) continue;
    if (themes.length === 0 && intensityDelta < 2.5) continue;

    pushCandidate(notes, {
      id: `fam-resurface-different-${past.id}-${current.id}`,
      kind: "sound_different",
      text: "You were carrying this differently then.",
      strength: 64 + Math.round(intensityDelta * 3) + (languageFlip ? 4 : 0),
      ...evidence(past, current),
    });
    break;
  }

  return notes;
}

function detectEmotionallyOpposite(
  current: JournalEntry,
  prior: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];

  for (const past of [...prior].reverse()) {
    if (gapDays(past, current) < MIN_GAP_DAYS) continue;
    if (sharedThemes(past, current).length === 0) continue;

    const delta = Math.abs(
      current.reflection.emotionalIntensity - past.reflection.emotionalIntensity,
    );
    if (delta < 2.8) continue;

    pushCandidate(notes, {
      id: `fam-resurface-opposite-${past.id}-${current.id}`,
      kind: "emotionally_opposite",
      text: "You were carrying this differently then.",
      strength: 63 + Math.round(delta * 2),
      ...evidence(past, current),
    });
    break;
  }

  return notes;
}

function detectEmotionallySimilar(
  current: JournalEntry,
  prior: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];

  for (const past of [...prior].reverse()) {
    if (gapDays(past, current) < MIN_GAP_DAYS) continue;
    if (sharedThemes(past, current).length === 0) continue;

    const delta = Math.abs(
      current.reflection.emotionalIntensity - past.reflection.emotionalIntensity,
    );
    if (delta > 1.2) continue;

    pushCandidate(notes, {
      id: `fam-resurface-similar-${past.id}-${current.id}`,
      kind: "emotionally_similar",
      text: "You spoke about this the same way.",
      strength: 61 + Math.round((1.2 - delta) * 4),
      ...evidence(past, current),
    });
    break;
  }

  return notes;
}

function detectEarlierLoop(
  current: JournalEntry,
  prior: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];
  const currentHasLoop =
    LOOP_RE.test(current.transcript) ||
    current.reflection.recurringThemes.some((t) =>
      prior.some(
        (p) =>
          hasTheme(p, t.toLowerCase()) &&
          (LOOP_RE.test(p.transcript) || countMatches(p.transcript, HEDGE_RE) >= 2),
      ),
    );

  if (!currentHasLoop) return notes;

  for (const past of [...prior].reverse()) {
    if (gapDays(past, current) < MIN_GAP_DAYS) continue;
    if (!LOOP_RE.test(past.transcript) && countMatches(past.transcript, HEDGE_RE) < 2) continue;
    if (sharedThemes(past, current).length === 0) continue;

    pushCandidate(notes, {
      id: `fam-resurface-loop-${past.id}-${current.id}`,
      kind: "earlier_loop",
      text: "An earlier version of the same thought.",
      strength: 65 + Math.min(gapDays(past, current), 14),
      ...evidence(past, current),
    });
    break;
  }

  return notes;
}

function detectFirstCalmerTopic(
  current: JournalEntry,
  prior: JournalEntry[],
  sorted: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const hits = sorted.filter((e) => hasTheme(e, themeKey));
    if (hits.length < 3) continue;

    let firstCalm: JournalEntry | null = null;
    for (let i = 0; i < hits.length; i += 1) {
      const priorHits = hits.slice(0, i);
      if (priorHits.length < 2) continue;
      const priorAvg = roundAvg(priorHits.map((e) => e.reflection.emotionalIntensity));
      if (priorAvg < 5.5) continue;
      if (hits[i].reflection.emotionalIntensity > priorAvg - 1.5) continue;
      firstCalm = hits[i];
      break;
    }

    if (!firstCalm || firstCalm.id === current.id) continue;
    if (gapDays(firstCalm, current) < MIN_GAP_DAYS) continue;

    pushCandidate(notes, {
      id: `fam-resurface-first-calm-${themeKey}-${current.id}`,
      kind: "first_calmer_topic",
      text: `The first quieter entry about ${themeLabel(theme)}.`,
      strength: 64 + hits.length,
      ...evidence(firstCalm, current),
    });
  }

  return notes;
}

function detectBeforeDirectNaming(
  current: JournalEntry,
  prior: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];
  const currentDirect = countMatches(current.transcript, DIRECT_RE);
  const currentHedge = countMatches(current.transcript, HEDGE_RE);

  if (currentDirect < 1 || currentHedge > currentDirect) return notes;

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorHits = prior.filter((e) => hasTheme(e, themeKey));
    if (priorHits.length < 2) continue;

    const hedgedPrior = priorHits.find(
      (e) =>
        countMatches(e.transcript, HEDGE_RE) >= 2 &&
        countMatches(e.transcript, DIRECT_RE) === 0,
    );
    if (!hedgedPrior) continue;

    const laterDirect = priorHits.some(
      (e) =>
        toDayKey(e.createdAt) > toDayKey(hedgedPrior.createdAt) &&
        countMatches(e.transcript, DIRECT_RE) >= 1,
    );
    if (laterDirect) continue;
    if (gapDays(hedgedPrior, current) < MIN_GAP_DAYS) continue;

    pushCandidate(notes, {
      id: `fam-resurface-before-direct-${themeKey}-${current.id}`,
      kind: "before_direct_naming",
      text: "You had not named this directly yet.",
      strength: 63 + priorHits.length,
      ...evidence(hedgedPrior, current),
    });
  }

  return notes;
}

function detectBeforeMajorShift(
  current: JournalEntry,
  sorted: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];
  const idx = sorted.findIndex((e) => e.id === current.id);
  if (idx < 4) return notes;

  let best: { entry: JournalEntry; magnitude: number } | null = null;

  for (let i = 3; i < idx; i += 1) {
    const before = sorted.slice(Math.max(0, i - 3), i);
    const after = sorted.slice(i, Math.min(sorted.length, i + 3));
    if (before.length < 2 || after.length < 2) continue;

    const beforeAvg = roundAvg(before.map((e) => e.reflection.emotionalIntensity));
    const afterAvg = roundAvg(after.map((e) => e.reflection.emotionalIntensity));
    const magnitude = Math.abs(afterAvg - beforeAvg);
    if (magnitude < 1.8) continue;

    const pivot = sorted[i - 1];
    if (!best || magnitude > best.magnitude) {
      best = { entry: pivot, magnitude };
    }
  }

  if (!best || gapDays(best.entry, current) < MIN_SHIFT_GAP_DAYS) return notes;

  pushCandidate(notes, {
    id: `fam-resurface-shift-${best.entry.id}-${current.id}`,
    kind: "before_major_shift",
    text: "You were carrying this differently then.",
    strength: 64 + Math.round(best.magnitude * 3),
    ...evidence(best.entry, current),
  });

  return notes;
}

function detectMonthlyContrast(
  current: JournalEntry,
  prior: JournalEntry[],
): FamiliarityResurfacingNote[] {
  const notes: FamiliarityResurfacingNote[] = [];
  const currentMonth = toDayKey(current.createdAt).slice(0, 7);
  const currentMonthEntries = prior.filter(
    (e) => toDayKey(e.createdAt).slice(0, 7) === currentMonth,
  );
  currentMonthEntries.push(current);

  const monthBuckets = new Map<string, JournalEntry[]>();
  for (const entry of [...prior, current]) {
    const key = toDayKey(entry.createdAt).slice(0, 7);
    const list = monthBuckets.get(key) ?? [];
    list.push(entry);
    monthBuckets.set(key, list);
  }

  const months = [...monthBuckets.keys()].sort();
  if (months.length < 3) return notes;

  const thisAvg = roundAvg(currentMonthEntries.map((e) => e.reflection.emotionalIntensity));
  const compareMonth = months[months.length - 3];
  const compareEntries = monthBuckets.get(compareMonth) ?? [];
  if (compareEntries.length < 2) return notes;

  const compareAvg = roundAvg(compareEntries.map((e) => e.reflection.emotionalIntensity));
  const delta = Math.abs(thisAvg - compareAvg);
  if (delta < 1.5) return notes;

  const past = compareEntries[compareEntries.length - 1];
  if (gapDays(past, current) < 28) return notes;

  pushCandidate(notes, {
    id: `fam-resurface-month-${compareMonth}-${current.id}`,
    kind: "monthly_contrast",
    text: "You sound further away from it now.",
    strength: 62 + Math.round(delta * 3),
    ...evidence(past, current),
  });

  return notes;
}

function dedupeNotes(notes: FamiliarityResurfacingNote[]): FamiliarityResurfacingNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.kind}:${n.text}:${n.pastEntryId}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(
  candidates: FamiliarityResurfacingNote[],
  context: FamiliarityResurfacingContext,
  limit: number,
): FamiliarityResurfacingNote[] {
  const sorted = dedupeNotes(candidates);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: FamiliarityResurfacingNote[] = [];
  const usedKinds = new Set<FamiliarityResurfacingKind>();
  const usedPast = new Set<string>();

  for (const kind of priority) {
    if (picked.length >= limit) break;
    const match = sorted.find(
      (n) => n.kind === kind && !usedKinds.has(kind) && !usedPast.has(n.pastEntryId ?? ""),
    );
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
      if (match.pastEntryId) usedPast.add(match.pastEntryId);
    }
  }

  for (const note of sorted) {
    if (picked.length >= limit) break;
    if (picked.some((p) => p.id === note.id)) continue;
    if (note.pastEntryId && usedPast.has(note.pastEntryId)) continue;
    picked.push(note);
    if (note.pastEntryId) usedPast.add(note.pastEntryId);
  }

  return picked.slice(0, limit);
}

function collectCandidates(
  sorted: JournalEntry[],
  anchorIdx: number,
): FamiliarityResurfacingNote[] {
  const current = sorted[anchorIdx];
  const prior = sorted.slice(0, anchorIdx);

  if (prior.length < MIN_ENTRIES - 1) return [];

  return [
    ...detectSoundDifferent(current, prior),
    ...detectEmotionallyOpposite(current, prior),
    ...detectEarlierLoop(current, prior),
    ...detectFirstCalmerTopic(current, prior, sorted),
    ...detectBeforeDirectNaming(current, prior),
    ...detectBeforeMajorShift(current, sorted),
    ...detectMonthlyContrast(current, prior),
  ];
}

/** Reconnect older reflections to who you are now — emotionally, not analytically. */
export function buildFamiliarityResurfacingReport(
  entries: JournalEntry[],
  options: FamiliarityResurfacingOptions,
): FamiliarityResurfacingReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < MIN_ENTRIES) {
    return { notes: [], hasData: false };
  }

  let anchorIdx = sorted.length - 1;
  if (options.context === "entry" && options.entryId) {
    const idx = sorted.findIndex((e) => e.id === options.entryId);
    if (idx <= 0) return { notes: [], hasData: false };
    anchorIdx = idx;
  }

  const candidates = collectCandidates(sorted, anchorIdx);
  const notes = pickForContext(candidates, options.context, (options.limit ?? 1) * 4);
  return { notes, hasData: notes.length > 0 };
}

export function familiarityResurfacingToNotes(
  notes: FamiliarityResurfacingNote[],
): MemoryNote[] {
  return notes.map((note) => ({
    id: note.id,
    text: note.text,
    category: "returned" as const,
    confidence: note.strength,
    pastQuote: note.pastQuote,
    currentQuote: note.currentQuote,
    pastDateLabel: note.pastDateLabel,
    currentDateLabel: note.currentDateLabel,
    pastEntryId: note.pastEntryId,
    entryId: note.entryId,
  }));
}

function surfaceForContext(context: FamiliarityResurfacingContext): ResurfacingSurface {
  return context;
}

function applyFamiliarityResurfacingRarity(
  entries: JournalEntry[],
  notes: FamiliarityResurfacingNote[],
  context: FamiliarityResurfacingContext,
  limit = 1,
): MemoryNote[] {
  return applyResurfacingRarity(
    notes.map((note) =>
      candidateFromFamiliarityResurfacingNote(
        note,
        familiarityResurfacingToNotes([note])[0],
        gapDaysBetweenEntries(entries, note.pastEntryId, note.entryId),
      ),
    ),
    { surface: surfaceForContext(context), limit, record: true, entries },
  );
}

export function homepageFamiliarityResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildFamiliarityResurfacingReport(entries, { context: "homepage", limit });
  return applyMemoryHierarchy(
    applyFamiliarityResurfacingRarity(entries, report.notes, "homepage", limit),
    entries,
    limit,
  );
}

export function entryFamiliarityResurfacingNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 1,
): MemoryNote[] {
  const report = buildFamiliarityResurfacingReport(entries, { context: "entry", entryId, limit });
  return applyMemoryHierarchy(
    applyFamiliarityResurfacingRarity(entries, report.notes, "entry", limit),
    entries,
    limit,
  );
}

export function timelineFamiliarityResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildFamiliarityResurfacingReport(entries, { context: "timeline", limit });
  return applyMemoryHierarchy(
    applyFamiliarityResurfacingRarity(entries, report.notes, "timeline", limit),
    entries,
    limit,
  );
}

export function monthlyFamiliarityResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildFamiliarityResurfacingReport(entries, { context: "monthly", limit });
  return applyMemoryHierarchy(
    applyFamiliarityResurfacingRarity(entries, report.notes, "monthly", limit),
    entries,
    limit,
  );
}

export function memoryFamiliarityResurfacingNotes(
  entries: JournalEntry[],
  limit = 1,
): MemoryNote[] {
  const report = buildFamiliarityResurfacingReport(entries, { context: "memory", limit });
  return applyMemoryHierarchy(
    applyFamiliarityResurfacingRarity(entries, report.notes, "memory", limit),
    entries,
    limit,
  );
}
