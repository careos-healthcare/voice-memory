import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";

export const MAX_THEN_VS_NOW_QUOTE = 100;
export const MIN_THEN_VS_NOW_QUOTE = 12;
export const MIN_THEN_VS_NOW_GAP_DAYS = 7;
export const MAX_QUOTE_SIMILARITY = 0.64;
export const MIN_THEN_VS_NOW_SCORE = 44;

const GENERIC_QUOTE_RE =
  /\b(just thinking|not sure what|i don'?t know what|hard to explain|something about|kind of thing|you know what i mean|whatever|i guess so|not much to say)\b/i;

const FILLER_TOKENS = new Set([
  "i",
  "me",
  "my",
  "the",
  "a",
  "an",
  "and",
  "or",
  "but",
  "so",
  "just",
  "like",
  "really",
  "very",
  "um",
  "uh",
  "well",
  "yeah",
  "okay",
]);

const PAST_HEAVY_RE =
  /\b(sorry|apolog\w*|stuck|heavy|overwhelmed|exhausted|anxious|panic|can't|couldn't|hard|difficult|again|circling|loop|avoid|don't want|not ready|hard to say|vague|unsure|worried|scared|tired|drained)\b/gi;

const CURRENT_SHIFT_RE =
  /\b(fine|better|clear|named|decided|moved|less|quieter|calmer|settled|over|done with|direct|know|further|away|lighter)\b/gi;

const NAME_TOKEN_RE = /\b[A-Z][a-z]{2,}\b/g;

function normalizeQuote(text: string): string {
  return text.toLowerCase().replace(/[^\w\s']/g, " ").replace(/\s+/g, " ").trim();
}

function wordCount(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

export function quoteSimilarity(a: string, b: string): number {
  const left = new Set(normalizeQuote(a).split(" ").filter(Boolean));
  const right = new Set(normalizeQuote(b).split(" ").filter(Boolean));
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size);
}

export function hedgeScore(text: string): number {
  return text.match(/\b(maybe|sort of|kind of|not sure|i guess|perhaps|vague|kinda)\b/gi)?.length ?? 0;
}

export function directScore(text: string): number {
  return text.match(/\b(named|decided|clearly|for sure|directly|i know|i need to)\b/gi)?.length ?? 0;
}

export function trimRevisitQuote(text: string): string {
  const trimmed = text.trim().replace(/\s+/g, " ");
  if (trimmed.length <= MAX_THEN_VS_NOW_QUOTE) return trimmed;
  const slice = trimmed.slice(0, MAX_THEN_VS_NOW_QUOTE);
  const lastSpace = slice.lastIndexOf(" ");
  const cut = lastSpace > MIN_THEN_VS_NOW_QUOTE ? slice.slice(0, lastSpace) : slice;
  return `${cut.trim()}…`;
}

function isFillerOnlyQuote(text: string): boolean {
  const tokens = normalizeQuote(text)
    .split(" ")
    .filter((token) => token.length > 2 && !FILLER_TOKENS.has(token));
  return tokens.length < 3;
}

function isGenericQuote(text: string): boolean {
  if (GENERIC_QUOTE_RE.test(text)) return true;
  if (wordCount(text) < 4) return true;
  return false;
}

function sharedThemes(past: JournalEntry, current: JournalEntry): string[] {
  const currentThemes = new Set(current.reflection.recurringThemes.map((theme) => theme.toLowerCase()));
  return past.reflection.recurringThemes.filter((theme) => currentThemes.has(theme.toLowerCase()));
}

function sharedNameTokens(past: JournalEntry, current: JournalEntry): string[] {
  const pastNames = new Set((past.transcript.match(NAME_TOKEN_RE) ?? []).map((name) => name.toLowerCase()));
  return (current.transcript.match(NAME_TOKEN_RE) ?? []).filter((name) =>
    pastNames.has(name.toLowerCase()),
  );
}

export function sharedThenVsNowSubject(past: JournalEntry, current: JournalEntry): boolean {
  if (sharedThemes(past, current).length > 0) return true;
  return sharedNameTokens(past, current).length > 0;
}

function pastHeavyScore(pastQuote: string, past?: JournalEntry): number {
  let score = hedgeScore(pastQuote) * 4;
  score += (pastQuote.match(PAST_HEAVY_RE)?.length ?? 0) * 3;
  if (past && past.reflection.emotionalIntensity >= 5.5) score += 6;
  if (past?.reflection.avoidedOrVagueArea?.trim()) score += 5;
  if (past && hedgeScore(past.transcript) >= 2) score += 4;
  return score;
}

function currentShiftScore(
  pastQuote: string,
  currentQuote: string,
  past?: JournalEntry,
  current?: JournalEntry,
): number {
  let score = 0;
  const hedgeDrop = hedgeScore(pastQuote) - hedgeScore(currentQuote);
  const directGain = directScore(currentQuote) - directScore(pastQuote);
  score += Math.max(0, hedgeDrop) * 5;
  score += Math.max(0, directGain) * 5;
  score += (currentQuote.match(CURRENT_SHIFT_RE)?.length ?? 0) * 3;

  if (past && current && current.reflection.emotionalIntensity <= past.reflection.emotionalIntensity - 0.8) {
    score += 8;
  }
  if (past && current && past.reflection.mood !== current.reflection.mood) {
    score += 4;
  }

  return score;
}

function hasObviousEmotionalContrast(
  pastQuote: string,
  currentQuote: string,
  past?: JournalEntry,
  current?: JournalEntry,
): boolean {
  const hedgeDrop = hedgeScore(pastQuote) - hedgeScore(currentQuote);
  const directGain = directScore(currentQuote) - directScore(pastQuote);
  const pastHeavy = pastHeavyScore(pastQuote, past);
  const currentShift = currentShiftScore(pastQuote, currentQuote, past, current);
  const apologyPast = /\b(sorry|apolog)\w*/i.test(pastQuote);
  const apologyCurrent = /\b(sorry|apolog)\w*/i.test(currentQuote);
  const intensityDrop =
    past && current
      ? past.reflection.emotionalIntensity - current.reflection.emotionalIntensity
      : 0;

  if (hedgeDrop >= 1 || directGain >= 1) return true;
  if (intensityDrop >= 1) return true;
  if (apologyPast && !apologyCurrent) return true;
  if (pastHeavy >= 6 && currentShift >= 8) return true;
  if (pastHeavy >= 4 && currentShift >= 12) return true;

  return false;
}

export interface ThenVsNowQuoteScore {
  total: number;
  pastHeavy: number;
  currentShift: number;
  gapDays: number;
  hasAudio: boolean;
}

export function scoreThenVsNowQuotePair(
  pastQuote: string,
  currentQuote: string,
  past?: JournalEntry,
  current?: JournalEntry,
): ThenVsNowQuoteScore {
  const pastQ = trimRevisitQuote(pastQuote);
  const currentQ = trimRevisitQuote(currentQuote);

  const pastHeavy = pastHeavyScore(pastQ, past);
  const currentShift = currentShiftScore(pastQ, currentQ, past, current);
  const gapDays =
    past && current
      ? daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt))
      : 0;
  const hasAudio = Boolean(past?.audioId || current?.audioId);

  let total = pastHeavy + currentShift;

  if (gapDays >= MIN_THEN_VS_NOW_GAP_DAYS) {
    total += Math.min(Math.round(gapDays / 7) * 3, 12);
  }
  if (past?.audioId) total += 8;
  if (current?.audioId) total += 8;
  if (past && current && sharedThenVsNowSubject(past, current)) total += 10;

  const similarity = quoteSimilarity(pastQ, currentQ);
  total += Math.round((1 - similarity) * 10);

  return { total, pastHeavy, currentShift, gapDays, hasAudio };
}

export function qualifiesRevisitQuoteContrast(
  pastQuote: string,
  currentQuote: string,
  past?: JournalEntry,
  current?: JournalEntry,
): boolean {
  const pastQ = trimRevisitQuote(pastQuote);
  const currentQ = trimRevisitQuote(currentQuote);

  if (pastQ.length < MIN_THEN_VS_NOW_QUOTE || currentQ.length < MIN_THEN_VS_NOW_QUOTE) {
    return false;
  }
  if (pastQ.length > MAX_THEN_VS_NOW_QUOTE + 1 || currentQ.length > MAX_THEN_VS_NOW_QUOTE + 1) {
    return false;
  }
  if (isGenericQuote(pastQ) || isGenericQuote(currentQ)) return false;
  if (isFillerOnlyQuote(pastQ) || isFillerOnlyQuote(currentQ)) return false;

  const similarity = quoteSimilarity(pastQ, currentQ);
  if (similarity >= MAX_QUOTE_SIMILARITY) return false;

  if (past && current) {
    if (!sharedThenVsNowSubject(past, current)) return false;
    const gapDays = daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
    if (gapDays < MIN_THEN_VS_NOW_GAP_DAYS) return false;
  }

  if (!hasObviousEmotionalContrast(pastQ, currentQ, past, current)) return false;

  return scoreThenVsNowQuotePair(pastQ, currentQ, past, current).total >= MIN_THEN_VS_NOW_SCORE;
}

export function prepareRevisitContrastNote(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryNote | null {
  if (!note.pastQuote?.trim() || !note.currentQuote?.trim()) return null;

  const past = note.pastEntryId
    ? entries.find((entry) => entry.id === note.pastEntryId)
    : undefined;
  const current = note.entryId
    ? entries.find((entry) => entry.id === note.entryId)
    : undefined;
  const pastQuote = trimRevisitQuote(note.pastQuote);
  const currentQuote = trimRevisitQuote(note.currentQuote);

  if (!qualifiesRevisitQuoteContrast(pastQuote, currentQuote, past, current)) {
    return null;
  }

  return {
    ...note,
    pastQuote,
    currentQuote,
    text: "",
  };
}

export function rankThenVsNowContrastNotes(
  notes: MemoryNote[],
  entries: JournalEntry[],
): MemoryNote[] {
  return notes
    .map((note) => {
      const prepared = prepareRevisitContrastNote(note, entries);
      if (!prepared) return null;
      const past = note.pastEntryId
        ? entries.find((entry) => entry.id === note.pastEntryId)
        : undefined;
      const current = note.entryId
        ? entries.find((entry) => entry.id === note.entryId)
        : undefined;
      const score = scoreThenVsNowQuotePair(
        prepared.pastQuote!,
        prepared.currentQuote!,
        past,
        current,
      );
      return { note: prepared, score: score.total };
    })
    .filter((row): row is { note: MemoryNote; score: number } => row !== null)
    .sort((a, b) => b.score - a.score)
    .map((row) => row.note);
}
