import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import {
  getThemeIntensityTrend,
  hasTheme,
  languageShiftOnTheme,
} from "@/lib/patterns/emotional-evolution";
import { helpsOrient } from "@/lib/patterns/usefulness-filter";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";
import type {
  MemoryCompoundingCandidate,
  MemoryCompoundingKind,
  MemoryCompoundingReport,
} from "@/types/memory-compounding";

export const COMPOUNDING_COPY = {
  closerToSaying: "You were getting closer to saying this.",
  soundsClearerNow: "This sounds clearer now.",
  carriedDifferently: "You carried this differently over time.",
  circlingBeforeNaming: "You kept circling this before naming it.",
  easierToSayLater: "This became easier to say later.",
} as const;

export const COMPOUNDING_FORBIDDEN = [
  "transformed",
  "healing",
  "breakthrough",
  "best self",
  "growth journey",
  "level up",
  "evolved into",
] as const;

export const MIN_COMPOUNDING_GAP_DAYS = 45;
export const MIN_COMPOUNDING_ENTRIES = 6;
export const COMPOUNDING_MIN_STRENGTH = 68;

const HEDGE_RE =
  /\b(maybe|i guess|sort of|kind of|probably|not sure|eventually|vague|worried|anxious|stress|fear|afraid)\b/gi;
const DIRECT_RE =
  /\b(i will|decided|named|wrote down|clearly|for sure|definitely|directly|i am|i'm)\b/gi;
const SOFT_RE = /\b(softer|gentler|calmer|quieter|eased|less heavy|lighter)\b/gi;
const IDENTITY_RE =
  /\b(i am|i'm|who i am|myself|identity|person i|kind of person)\b/gi;

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

function passesCompoundingCopy(text: string): boolean {
  const lower = text.toLowerCase();
  if (COMPOUNDING_FORBIDDEN.some((phrase) => lower.includes(phrase))) return false;
  return helpsOrient(text, COMPOUNDING_MIN_STRENGTH);
}

function pushCandidate(
  bucket: MemoryCompoundingCandidate[],
  item: Omit<MemoryCompoundingCandidate, "strength"> & { strength?: number },
): void {
  const strength = item.strength ?? COMPOUNDING_MIN_STRENGTH;
  if (strength < COMPOUNDING_MIN_STRENGTH) return;
  if (!passesCompoundingCopy(item.text)) return;
  bucket.push({ ...item, strength });
}

function detectAlmostNaming(
  current: JournalEntry,
  prior: JournalEntry[],
): MemoryCompoundingCandidate[] {
  const notes: MemoryCompoundingCandidate[] = [];
  const currentDirect = countMatches(snippet(current), DIRECT_RE);
  if (currentDirect < 1) return notes;

  const circling = prior.filter((entry) => {
    const gap = daysBetweenKeys(toDayKey(entry.createdAt), toDayKey(current.createdAt));
    if (gap < MIN_COMPOUNDING_GAP_DAYS) return false;
    const text = snippet(entry);
    return countMatches(text, HEDGE_RE) >= 2 && countMatches(text, DIRECT_RE) === 0;
  });

  if (circling.length < 2) return notes;

  const anchor = circling[circling.length - 1];
  pushCandidate(notes, {
    id: `compound-almost-naming-${current.id}`,
    kind: "almost_naming",
    text: COMPOUNDING_COPY.circlingBeforeNaming,
    strength: 72 + Math.min(circling.length, 4) * 3,
    gapDays: daysBetweenKeys(toDayKey(anchor.createdAt), toDayKey(current.createdAt)),
    supportingEntryIds: circling.slice(-3).map((e) => e.id),
    pastEntryId: anchor.id,
    entryId: current.id,
    pastQuote: snippet(anchor),
    currentQuote: snippet(current),
  });

  return notes;
}

function detectSofteningAndFears(
  current: JournalEntry,
  prior: JournalEntry[],
): MemoryCompoundingCandidate[] {
  const notes: MemoryCompoundingCandidate[] = [];

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const matches = prior.filter((e) => hasTheme(e, themeKey));
    if (matches.length < 2) continue;

    const lastPrior = matches[matches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), toDayKey(current.createdAt));
    if (gap < MIN_COMPOUNDING_GAP_DAYS) continue;

    const shift = languageShiftOnTheme(lastPrior, current);
    const trend = getThemeIntensityTrend(matches.concat(current), themeKey);
    const pastText = snippet(lastPrior);
    const currentText = snippet(current);

    if (shift.hedgeDelta >= 1 || (countMatches(pastText, HEDGE_RE) >= 2 && countMatches(currentText, HEDGE_RE) === 0)) {
      pushCandidate(notes, {
        id: `compound-softened-${themeKey}-${current.id}`,
        kind: "wording_softened",
        text: COMPOUNDING_COPY.easierToSayLater,
        strength: 70 + shift.hedgeDelta * 4,
        gapDays: gap,
        supportingEntryIds: matches.slice(-3).map((e) => e.id).concat(current.id),
        pastEntryId: lastPrior.id,
        entryId: current.id,
        pastQuote: pastText,
        currentQuote: currentText,
      });
    }

    if (trend && trend.delta >= 1.5 && countMatches(pastText, HEDGE_RE) >= 1) {
      pushCandidate(notes, {
        id: `compound-fear-faded-${themeKey}-${current.id}`,
        kind: "fear_faded",
        text: COMPOUNDING_COPY.carriedDifferently,
        strength: 71,
        gapDays: gap,
        supportingEntryIds: matches.slice(-2).map((e) => e.id).concat(current.id),
        pastEntryId: lastPrior.id,
        entryId: current.id,
      });
    }

    if (countMatches(pastText, IDENTITY_RE) >= 1 && countMatches(currentText, IDENTITY_RE) >= 1 && shift.directDelta >= 1) {
      pushCandidate(notes, {
        id: `compound-identity-${themeKey}-${current.id}`,
        kind: "identity_shift",
        text: COMPOUNDING_COPY.carriedDifferently,
        strength: 73,
        gapDays: gap,
        supportingEntryIds: matches.slice(-2).map((e) => e.id).concat(current.id),
        pastEntryId: lastPrior.id,
        entryId: current.id,
      });
    }
  }

  return notes;
}

function detectPhraseMeaning(entries: JournalEntry[]): MemoryCompoundingCandidate[] {
  const notes: MemoryCompoundingCandidate[] = [];
  const phraseMemory = buildPhraseMemory(entries);
  const sorted = sortedEntries(entries);

  for (const row of phraseMemory.slice(0, 12)) {
    if (row.occurrences.length < 3) continue;
    const first = sorted.find((e) => e.id === row.occurrences[0]?.entryId);
    const last = sorted.find((e) => e.id === row.occurrences[row.occurrences.length - 1]?.entryId);
    if (!first || !last || first.id === last.id) continue;

    const gap = daysBetweenKeys(toDayKey(first.createdAt), toDayKey(last.createdAt));
    if (gap < MIN_COMPOUNDING_GAP_DAYS) continue;

    pushCandidate(notes, {
      id: `compound-phrase-${row.phrase.slice(0, 12)}-${last.id}`,
      kind: "phrase_gained_meaning",
      text: COMPOUNDING_COPY.soundsClearerNow,
      strength: 74 + Math.min(row.occurrences.length, 5) * 2,
      gapDays: gap,
      supportingEntryIds: row.occurrences.slice(-4).map((o) => o.entryId),
      pastEntryId: first.id,
      entryId: last.id,
      pastQuote: snippet(first),
      currentQuote: snippet(last),
    });
  }

  return notes;
}

function detectClearerLater(entries: JournalEntry[]): MemoryCompoundingCandidate[] {
  const notes: MemoryCompoundingCandidate[] = [];
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_COMPOUNDING_ENTRIES) return notes;

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    for (let j = 0; j < i; j += 1) {
      const past = sorted[j];
      const gap = daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
      if (gap < 60 || gap > 400) continue;

      const pastSoft = countMatches(snippet(past), SOFT_RE) + countMatches(snippet(past), HEDGE_RE);
      const nowDirect = countMatches(snippet(current), DIRECT_RE);
      if (pastSoft < 2 || nowDirect < 1) continue;

      pushCandidate(notes, {
        id: `compound-clearer-${past.id}-${current.id}`,
        kind: "clearer_later",
        text: COMPOUNDING_COPY.closerToSaying,
        strength: 69 + Math.min(gap / 30, 8),
        gapDays: gap,
        supportingEntryIds: [past.id, current.id],
        pastEntryId: past.id,
        entryId: current.id,
        pastQuote: snippet(past),
        currentQuote: snippet(current),
      });
      break;
    }
  }

  return notes;
}

/** Detect long-horizon compounding patterns across the archive. */
export function buildMemoryCompoundingReport(
  entries: JournalEntry[],
): MemoryCompoundingReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < MIN_COMPOUNDING_ENTRIES) {
    return { generatedAt: new Date().toISOString(), hasData: false, candidates: [] };
  }

  const candidates: MemoryCompoundingCandidate[] = [
    ...detectPhraseMeaning(sorted),
    ...detectClearerLater(sorted),
  ];

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    const prior = sorted.slice(0, i);
    candidates.push(
      ...detectAlmostNaming(current, prior),
      ...detectSofteningAndFears(current, prior),
    );
  }

  const seen = new Set<string>();
  const unique = candidates
    .filter((row) => {
      const key = `${row.kind}:${row.pastEntryId ?? ""}:${row.entryId ?? row.id}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => b.strength - a.strength);

  return {
    generatedAt: new Date().toISOString(),
    hasData: unique.length > 0,
    candidates: unique.slice(0, 24),
  };
}

export function compoundingCandidateToNote(
  candidate: MemoryCompoundingCandidate,
  entries: JournalEntry[],
): import("@/types/memory-note").MemoryNote {
  const past = candidate.pastEntryId
    ? entries.find((e) => e.id === candidate.pastEntryId)
    : undefined;
  const current = candidate.entryId
    ? entries.find((e) => e.id === candidate.entryId)
    : undefined;

  return {
    id: candidate.id,
    text: candidate.text,
    category: "changed",
    confidence: candidate.strength,
    pastEntryId: candidate.pastEntryId,
    entryId: candidate.entryId,
    pastQuote: candidate.pastQuote,
    currentQuote: candidate.currentQuote,
    pastDateLabel: past ? formatRelativeDate(past.createdAt) : undefined,
    currentDateLabel: current ? formatRelativeDate(current.createdAt) : undefined,
  };
}
