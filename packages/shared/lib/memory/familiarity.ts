import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import {
  buildLanguageFingerprint,
  currentCircleRun,
  directCount,
  FAMILIARITY_COPY,
  fingerprintEvidence,
  hedgeCount,
  type LanguageFingerprint,
  MIN_FINGERPRINT_ENTRIES,
} from "@/lib/memory/language-fingerprint";
import { hasTheme } from "@/lib/patterns/emotional-evolution";
import { helpsOrient, USEFULNESS_MIN_CONFIDENCE } from "@/lib/patterns/usefulness-filter";
import { applyMemoryHierarchy } from "@/lib/refinement/memory-hierarchy";
import type {
  FamiliarityContext,
  FamiliarityKind,
  FamiliarityNote,
  FamiliarityReport,
} from "@/types/familiarity";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

const FAMILIAR_MIN = 63;
const STRONG_MIN = 65;

export interface FamiliarityOptions {
  context: FamiliarityContext;
  entryId?: string;
  limit?: number;
}

const CONTEXT_KIND_PRIORITY: Record<FamiliarityContext, FamiliarityKind[]> = {
  homepage: [
    "more_settled_than_usual",
    "more_direct_than_usual",
    "heavier_before",
    "stopped_circling",
    "slower_return",
    "quicker_return",
  ],
  entry: [
    "more_settled_than_usual",
    "more_direct_than_usual",
    "heavier_before",
    "stopped_circling",
    "slower_return",
    "quicker_return",
  ],
  timeline: [
    "heavier_before",
    "stopped_circling",
    "more_settled_than_usual",
    "more_direct_than_usual",
    "slower_return",
  ],
  monthly: [
    "more_settled_than_usual",
    "more_direct_than_usual",
    "heavier_before",
    "stopped_circling",
  ],
  memory: [
    "stopped_circling",
    "heavier_before",
    "more_settled_than_usual",
    "more_direct_than_usual",
  ],
};

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function hasEvidence(
  item: Pick<FamiliarityNote, "pastQuote" | "currentQuote" | "pastDateLabel" | "currentDateLabel">,
): boolean {
  const hasQuotes = Boolean(item.pastQuote?.trim() && item.currentQuote?.trim());
  const hasDates = Boolean(item.pastDateLabel && item.currentDateLabel);
  return hasQuotes || hasDates;
}

function pushCandidate(
  bucket: FamiliarityNote[],
  item: Omit<FamiliarityNote, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? 55;
  if (strength < FAMILIAR_MIN) return;
  if (!hasEvidence(item)) return;
  if (!helpsOrient(item.text, strength)) return;
  bucket.push({ ...item, strength });
}

function detectMoreSettled(
  current: JournalEntry,
  fingerprint: LanguageFingerprint,
  history: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const intensity = current.reflection.emotionalIntensity;
  const delta = fingerprint.avgIntensity - intensity;
  const belowUsual = intensity <= fingerprint.intensityP25 - 0.3 || delta >= 1.5;
  if (!belowUsual) return notes;

  const heavierPrior = [...history]
    .reverse()
    .find((e) => e.reflection.emotionalIntensity >= fingerprint.avgIntensity + 0.5);
  if (!heavierPrior) return notes;

  pushCandidate(notes, {
    id: `familiar-settled-${current.id}`,
    kind: "more_settled_than_usual",
    text: FAMILIARITY_COPY.moreSettled,
    strength: STRONG_MIN + Math.min(Math.round(delta * 3), 12),
    ...fingerprintEvidence(heavierPrior, current),
  });

  return notes;
}

function detectMoreDirect(
  current: JournalEntry,
  fingerprint: LanguageFingerprint,
  history: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const hedge = hedgeCount(current);
  const direct = directCount(current);
  const directDelta = direct - fingerprint.avgDirect;
  const hedgeDelta = fingerprint.avgHedge - hedge;

  if (directDelta < 1.5 || direct <= fingerprint.avgDirect + 0.5) return notes;
  if (hedge > fingerprint.avgHedge && hedgeDelta < 1) return notes;

  const hedgedPrior = [...history]
    .reverse()
    .find((e) => hedgeCount(e) >= Math.max(fingerprint.avgHedge, 2));
  if (!hedgedPrior) return notes;

  pushCandidate(notes, {
    id: `familiar-direct-${current.id}`,
    kind: "more_direct_than_usual",
    text: FAMILIARITY_COPY.namedDirectly,
    strength: STRONG_MIN + Math.round(directDelta * 4) + Math.max(hedgeDelta, 0) * 2,
    ...fingerprintEvidence(hedgedPrior, current),
  });

  return notes;
}

function detectHeavierBefore(
  current: JournalEntry,
  fingerprint: LanguageFingerprint,
  history: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorHits = history.filter((e) => hasTheme(e, themeKey));
    if (priorHits.length < 2) continue;

    const heavier = [...priorHits]
      .reverse()
      .find(
        (e) =>
          e.reflection.emotionalIntensity >= fingerprint.intensityP75 &&
          e.reflection.emotionalIntensity >= current.reflection.emotionalIntensity + 1.5,
      );
    if (!heavier) continue;

    pushCandidate(notes, {
      id: `familiar-heavier-${themeKey}-${current.id}`,
      kind: "heavier_before",
      text: FAMILIARITY_COPY.usedToFeelHeavier,
      strength:
        STRONG_MIN +
        Math.round(heavier.reflection.emotionalIntensity - current.reflection.emotionalIntensity) *
          3,
      ...fingerprintEvidence(heavier, current),
    });
    break;
  }

  return notes;
}

function detectStoppedCircling(
  current: JournalEntry,
  sorted: JournalEntry[],
  anchorIdx: number,
  fingerprint: LanguageFingerprint,
  prior: JournalEntry[],
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = fingerprint.themeCircleRun.get(themeKey);
    if (!typical || typical < 2.5) continue;

    const run = currentCircleRun(sorted, anchorIdx, themeKey);
    if (run >= typical - 0.5) continue;

    const circlingPrior = [...prior]
      .reverse()
      .find((e) => hasTheme(e, themeKey) && hedgeCount(e) >= fingerprint.avgHedge);
    if (!circlingPrior) continue;

    pushCandidate(notes, {
      id: `familiar-stopped-${themeKey}-${current.id}`,
      kind: "stopped_circling",
      text: FAMILIARITY_COPY.stoppedCircling,
      strength: STRONG_MIN + Math.min(Math.round((typical - run) * 4), 12),
      ...fingerprintEvidence(circlingPrior, current),
    });
    break;
  }

  return notes;
}

function detectQuickerReturn(
  current: JournalEntry,
  prior: JournalEntry[],
  fingerprint: LanguageFingerprint,
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const currentDay = toDayKey(current.createdAt);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = fingerprint.themeReturnGap.get(themeKey);
    if (!typical || typical < 4) continue;

    const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
    if (priorMatches.length < 2) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap <= 0 || gap >= typical * 0.6) continue;

    pushCandidate(notes, {
      id: `familiar-quicker-${themeKey}-${current.id}`,
      kind: "quicker_return",
      text: FAMILIARITY_COPY.quickerReturn,
      strength: STRONG_MIN + Math.min(typical - gap, 10),
      ...fingerprintEvidence(lastPrior, current),
    });
    break;
  }

  return notes;
}

function detectSlowerReturn(
  current: JournalEntry,
  prior: JournalEntry[],
  fingerprint: LanguageFingerprint,
): FamiliarityNote[] {
  const notes: FamiliarityNote[] = [];
  const currentDay = toDayKey(current.createdAt);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const typical = fingerprint.themeReturnGap.get(themeKey);
    if (!typical || typical < 4) continue;

    const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
    if (priorMatches.length < 2) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    if (gap <= typical * 1.4) continue;

    pushCandidate(notes, {
      id: `familiar-slower-${themeKey}-${current.id}`,
      kind: "slower_return",
      text: FAMILIARITY_COPY.slowerReturn,
      strength: STRONG_MIN + Math.min(Math.round(gap - typical), 12),
      ...fingerprintEvidence(lastPrior, current),
    });
    break;
  }

  return notes;
}

function dedupeNotes(notes: FamiliarityNote[]): FamiliarityNote[] {
  const seen = new Set<string>();
  return notes
    .filter((n) => n.strength >= USEFULNESS_MIN_CONFIDENCE)
    .sort((a, b) => b.strength - a.strength)
    .filter((n) => {
      const key = `${n.kind}:${n.text.slice(0, 32)}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function pickForContext(
  candidates: FamiliarityNote[],
  context: FamiliarityContext,
  limit: number,
): FamiliarityNote[] {
  const sorted = dedupeNotes(candidates);
  const priority = CONTEXT_KIND_PRIORITY[context];
  const picked: FamiliarityNote[] = [];
  const usedKinds = new Set<FamiliarityKind>();

  for (const kind of priority) {
    if (picked.length >= limit) break;
    const match = sorted.find((n) => n.kind === kind && !usedKinds.has(kind));
    if (match) {
      picked.push(match);
      usedKinds.add(kind);
    }
  }

  return picked.slice(0, limit);
}

function collectCandidates(
  sorted: JournalEntry[],
  anchorIdx: number,
  fingerprint: LanguageFingerprint,
): FamiliarityNote[] {
  const current = sorted[anchorIdx];
  const prior = sorted.slice(0, anchorIdx);
  const history = prior;

  return [
    ...detectMoreSettled(current, fingerprint, history),
    ...detectMoreDirect(current, fingerprint, history),
    ...detectHeavierBefore(current, fingerprint, history),
    ...detectStoppedCircling(current, sorted, anchorIdx, fingerprint, prior),
    ...detectQuickerReturn(current, prior, fingerprint),
    ...detectSlowerReturn(current, prior, fingerprint),
  ];
}

/** Detect quiet familiarity — how this reflection sits against how you usually sound. */
export function buildFamiliarityReport(
  entries: JournalEntry[],
  options: FamiliarityOptions,
): FamiliarityReport {
  const limit = options.limit ?? 1;
  const sorted = sortedEntries(entries);

  if (sorted.length < MIN_FINGERPRINT_ENTRIES + 1) {
    return { notes: [], hasData: false };
  }

  let anchorIdx = sorted.length - 1;
  if (options.context === "entry" && options.entryId) {
    const idx = sorted.findIndex((e) => e.id === options.entryId);
    if (idx < 0) return { notes: [], hasData: false };
    anchorIdx = idx;
  }

  const history = sorted.slice(0, anchorIdx);
  if (history.length < MIN_FINGERPRINT_ENTRIES) {
    return { notes: [], hasData: false };
  }

  const fingerprint = buildLanguageFingerprint(history);
  if (!fingerprint) return { notes: [], hasData: false };

  const candidates = collectCandidates(sorted, anchorIdx, fingerprint);
  const notes = pickForContext(candidates, options.context, limit);
  return { notes, hasData: notes.length > 0 };
}

export function familiarityToNotes(notes: FamiliarityNote[]): MemoryNote[] {
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

export function homepageFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    familiarityToNotes(buildFamiliarityReport(entries, { context: "homepage", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function entryFamiliarityNotes(
  entries: JournalEntry[],
  entryId: string,
  limit = 1,
): MemoryNote[] {
  return applyMemoryHierarchy(
    familiarityToNotes(
      buildFamiliarityReport(entries, { context: "entry", entryId, limit }).notes,
    ),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function timelineFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    familiarityToNotes(buildFamiliarityReport(entries, { context: "timeline", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function monthlyFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    familiarityToNotes(buildFamiliarityReport(entries, { context: "monthly", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}

export function memoryFamiliarityNotes(entries: JournalEntry[], limit = 1): MemoryNote[] {
  return applyMemoryHierarchy(
    familiarityToNotes(buildFamiliarityReport(entries, { context: "memory", limit }).notes),
    entries,
    limit,
    STRONG_MIN - 4,
  );
}
