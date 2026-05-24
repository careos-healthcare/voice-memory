import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { readMoatRevisits } from "@/lib/retention/moat-metrics";
import { REVISIT_REWARD_COPY } from "@/lib/refinement/knows-me-moments";
import {
  directScore,
  hedgeScore,
  prepareRevisitContrastNote,
  qualifiesRevisitQuoteContrast,
  quoteSimilarity,
  scoreThenVsNowQuotePair,
  trimRevisitQuote,
} from "@/lib/refinement/then-vs-now-quotes";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { VoicePlaybackPair } from "@/lib/conversation/voice-playback-continuity";

export type ReopenPayoffSignal =
  | "emotional_wording_shift"
  | "apology_disappearance"
  | "direct_naming"
  | "calmer_tone"
  | "changed_certainty"
  | "earlier_self_feeling"
  | "phrase_disappearance"
  | "long_distance_contrast";

export type ReopenPayoffSuppressReason =
  | "topical_similarity"
  | "informational_continuity"
  | "weak_quote_pair"
  | "emotionally_flat";

export interface ReopenPayoffSignalRow {
  id: ReopenPayoffSignal;
  points: number;
}

export interface ReopenPayoffScore {
  total: number;
  signals: ReopenPayoffSignalRow[];
  suppressed: boolean;
  suppressReason?: ReopenPayoffSuppressReason;
  gapDays: number;
  quoteScore: number;
  audioScore: number;
}

export interface ReopenPayoffMomentRow {
  entryId: string;
  anchorEntryId: string;
  payoffScore: number;
  signals: ReopenPayoffSignal[];
  firstLine: string;
  pastQuote?: string;
  currentQuote?: string;
  gapDays: number;
  hasAudio: boolean;
  suppressed: boolean;
  suppressReason?: ReopenPayoffSuppressReason;
  revisitCount: number;
  reflectionAfterPayoff: number;
  conversionRate: string;
}

export interface ReopenPayoffDebugReport {
  moments: ReopenPayoffMomentRow[];
  avgPayoffScore: number;
  strongMomentCount: number;
  revisitConversionAfterPayoff: string;
  hasData: boolean;
}

export const REOPEN_PAYOFF_MIN = 54;
export const REOPEN_PAYOFF_STRONG = 70;
export const LONG_DISTANCE_DAYS = 30;

const APOLOGY_RE = /\b(sorry|apolog\w*)\b/i;
const DIRECT_RE = /\b(named|decided|clearly|for sure|directly|i know)\b/i;
const HEDGE_RE = /\b(maybe|sort of|kind of|not sure|i guess|perhaps|vague)\b/gi;
const INFORMATIONAL_RE =
  /\b(as discussed|following up|update on|still working on|progress on|next step|meeting went|call went)\b/i;
const TOPICAL_ONLY_RE =
  /\b(same topic|similar theme|appeared again|showed up again|worth revisiting|older reflection|this thread)\b/i;
const EARLIER_SELF_RE =
  /\b(earlier|before|used to|back then|that version|old me|younger|first time)\b/i;

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function entryById(entries: JournalEntry[], id?: string): JournalEntry | undefined {
  if (!id) return undefined;
  return entries.find((row) => row.id === id);
}

function sharedThemes(a: JournalEntry, b: JournalEntry): string[] {
  const setB = new Set(b.reflection.recurringThemes.map((theme) => theme.toLowerCase()));
  return a.reflection.recurringThemes.filter((theme) => setB.has(theme.toLowerCase()));
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function gapDaysForNote(entries: JournalEntry[], note: MemoryNote): number {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  if (past && current) {
    return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(current.createdAt));
  }
  if (past) return daysBetweenKeys(toDayKey(past.createdAt), toDayKey(new Date().toISOString()));
  return 0;
}

function hasPhraseDisappearance(entries: JournalEntry[], note: MemoryNote): boolean {
  const past = entryById(entries, note.pastEntryId);
  if (!past) return false;
  const phrases = buildPhraseMemory(sortedEntries(entries));
  for (const record of phrases) {
    if (record.count < 3) continue;
    const lastOcc = record.occurrences[record.occurrences.length - 1];
    if (lastOcc.entryId !== past.id) continue;
    const gap = daysBetweenKeys(lastOcc.dateKey, toDayKey(new Date().toISOString()));
    if (gap >= 14) return true;
  }
  return note.id.includes("phrase-gone") || note.id.includes("phrase_gone");
}

function scoreAudioPair(past?: JournalEntry, current?: JournalEntry): number {
  let score = 0;
  if (past?.audioId) score += 14;
  if (current?.audioId) score += 14;
  if (past?.audioId && current?.audioId) score += 18;
  if (past && current) {
    const intensityDelta = Math.abs(
      past.reflection.emotionalIntensity - current.reflection.emotionalIntensity,
    );
    score += Math.round(intensityDelta * 3);
  }
  return score;
}

function detectSuppressReason(
  note: MemoryNote,
  entries: JournalEntry[],
  past?: JournalEntry,
  current?: JournalEntry,
): ReopenPayoffSuppressReason | undefined {
  const text = note.text.trim();
  const pastQuote = note.pastQuote?.trim() ?? "";
  const currentQuote = note.currentQuote?.trim() ?? "";

  if (pastQuote && currentQuote) {
    if (
      !qualifiesRevisitQuoteContrast(pastQuote, currentQuote, past, current) ||
      quoteSimilarity(pastQuote, currentQuote) >= 0.72
    ) {
      return "weak_quote_pair";
    }
  }

  if (past && current) {
    const overlap = sharedThemes(past, current);
    const intensityDelta = Math.abs(
      past.reflection.emotionalIntensity - current.reflection.emotionalIntensity,
    );
    const hedgeDrop = hedgeScore(pastQuote || past.transcript) - hedgeScore(currentQuote || current.transcript);
    const directGain = directScore(currentQuote || current.transcript) - directScore(pastQuote || past.transcript);

    if (
      overlap.length > 0 &&
      intensityDelta < 0.8 &&
      hedgeDrop <= 0 &&
      directGain <= 0 &&
      past.reflection.mood === current.reflection.mood
    ) {
      return "topical_similarity";
    }
  }

  if (INFORMATIONAL_RE.test(text) || (TOPICAL_ONLY_RE.test(text) && !pastQuote)) {
    return "informational_continuity";
  }

  if (past && current) {
    const intensityDelta = Math.abs(
      past.reflection.emotionalIntensity - current.reflection.emotionalIntensity,
    );
    const apologyPast = APOLOGY_RE.test(pastQuote || past.transcript);
    const apologyCurrent = APOLOGY_RE.test(currentQuote || current.transcript);
    const hasShift =
      intensityDelta >= 1 ||
      hedgeScore(pastQuote || past.transcript) > hedgeScore(currentQuote || current.transcript) ||
      directScore(currentQuote || current.transcript) > directScore(pastQuote || past.transcript) ||
      (apologyPast && !apologyCurrent) ||
      past.reflection.mood !== current.reflection.mood;

    if (!hasShift && note.confidence < 68 && !note.pastQuote) {
      return "emotionally_flat";
    }
  }

  if (!pastQuote && !currentQuote && note.confidence < 64 && TOPICAL_ONLY_RE.test(text)) {
    return "emotionally_flat";
  }

  return undefined;
}

function collectPayoffSignals(
  note: MemoryNote,
  entries: JournalEntry[],
  past?: JournalEntry,
  current?: JournalEntry,
): ReopenPayoffSignalRow[] {
  const signals: ReopenPayoffSignalRow[] = [];
  const pastText = note.pastQuote?.trim() || past?.transcript || "";
  const currentText = note.currentQuote?.trim() || current?.transcript || "";
  const gapDays = gapDaysForNote(entries, note);

  if (past && current) {
    const hedgeDrop = hedgeScore(pastText) - hedgeScore(currentText);
    const directGain = directScore(currentText) - directScore(pastText);
    if (hedgeDrop >= 1 || directGain >= 1 || past.reflection.mood !== current.reflection.mood) {
      signals.push({ id: "emotional_wording_shift", points: 12 + Math.min(hedgeDrop + directGain, 4) * 2 });
    }

    const apologyPast = APOLOGY_RE.test(pastText);
    const apologyCurrent = APOLOGY_RE.test(currentText);
    if (apologyPast && !apologyCurrent) {
      signals.push({ id: "apology_disappearance", points: 14 });
    }

    if (directGain >= 1 || DIRECT_RE.test(currentText)) {
      signals.push({ id: "direct_naming", points: 12 });
    }

    if (current.reflection.emotionalIntensity <= past.reflection.emotionalIntensity - 1) {
      signals.push({ id: "calmer_tone", points: 10 + Math.round(past.reflection.emotionalIntensity - current.reflection.emotionalIntensity) });
    }

    const certaintyBefore = (pastText.match(HEDGE_RE)?.length ?? 0) >= 2;
    const certaintyAfter = (currentText.match(HEDGE_RE)?.length ?? 0) <= 1 && directScore(currentText) >= 1;
    if (certaintyBefore && certaintyAfter) {
      signals.push({ id: "changed_certainty", points: 10 });
    }
  }

  if (
    note.id.includes("earlier") ||
    note.id.includes("earlier_self") ||
    EARLIER_SELF_RE.test(note.text) ||
    (past &&
      current &&
      gapDays >= 21 &&
      past.reflection.emotionalIntensity >= current.reflection.emotionalIntensity + 1)
  ) {
    signals.push({ id: "earlier_self_feeling", points: 14 });
  }

  if (hasPhraseDisappearance(entries, note)) {
    signals.push({ id: "phrase_disappearance", points: 12 });
  }

  if (gapDays >= LONG_DISTANCE_DAYS) {
    signals.push({
      id: "long_distance_contrast",
      points: 16 + Math.min(Math.round((gapDays - LONG_DISTANCE_DAYS) / 7), 8),
    });
  }

  const seen = new Set<ReopenPayoffSignal>();
  return signals.filter((row) => {
    if (seen.has(row.id)) return false;
    seen.add(row.id);
    return true;
  });
}

/** Score how strongly an old-entry revisit should land — prefer self-contrast over topic echo. */
export function scoreReopenPayoff(note: MemoryNote, entries: JournalEntry[]): ReopenPayoffScore {
  const past = entryById(entries, note.pastEntryId);
  const current = entryById(entries, note.entryId);
  const gapDays = gapDaysForNote(entries, note);
  const suppressReason = detectSuppressReason(note, entries, past, current);
  const signals = collectPayoffSignals(note, entries, past, current);

  const quoteScore =
    note.pastQuote?.trim() && note.currentQuote?.trim()
      ? scoreThenVsNowQuotePair(note.pastQuote, note.currentQuote, past, current).total
      : 0;
  const audioScore = scoreAudioPair(past, current);

  let total = note.confidence * 0.35;
  total += signals.reduce((sum, row) => sum + row.points, 0);
  total += Math.round(quoteScore * 0.45);
  total += Math.round(audioScore * 0.25);

  if (gapDays >= LONG_DISTANCE_DAYS && !signals.some((row) => row.id === "long_distance_contrast")) {
    total += 8;
  }

  const suppressed = Boolean(suppressReason) && total < REOPEN_PAYOFF_STRONG;

  return {
    total: Math.round(total),
    signals,
    suppressed,
    suppressReason,
    gapDays,
    quoteScore,
    audioScore,
  };
}

export function shouldSuppressReopenPayoff(note: MemoryNote, entries: JournalEntry[]): boolean {
  const score = scoreReopenPayoff(note, entries);
  if (score.suppressReason && score.total < REOPEN_PAYOFF_MIN) return true;
  if (score.suppressReason === "weak_quote_pair") return true;
  if (score.suppressReason === "informational_continuity") return true;
  if (score.suppressed) return true;
  return score.total < REOPEN_PAYOFF_MIN && Boolean(score.suppressReason);
}

/** Improved before/after quote selection — trims, validates, ranks by payoff. */
export function selectReopenQuotePair(
  note: MemoryNote,
  entries: JournalEntry[],
): MemoryNote | null {
  if (shouldSuppressReopenPayoff(note, entries)) return null;
  return prepareRevisitContrastNote(note, entries);
}

/** Rank contrast notes for reopen payoff — strongest “I forgot I sounded like this” first. */
export function rankReopenPayoffNotes(notes: MemoryNote[], entries: JournalEntry[]): MemoryNote[] {
  return notes
    .map((note) => {
      const prepared = selectReopenQuotePair(note, entries);
      if (!prepared) return null;
      const score = scoreReopenPayoff(prepared, entries);
      if (shouldSuppressReopenPayoff(prepared, entries)) return null;
      return { note: prepared, score: score.total };
    })
    .filter((row): row is { note: MemoryNote; score: number } => row !== null)
    .sort((a, b) => b.score - a.score)
    .map((row) => row.note);
}

/** Max one strong reopen moment per revisit — contrast beats text-only when payoff is close. */
export function pickStrongestReopenMoment(
  candidates: MemoryNote[],
  entries: JournalEntry[],
  entryId?: string,
): { moment: MemoryNote | null; score: ReopenPayoffScore | null } {
  const pool = candidates.filter((note) => {
    if (!entryId) return true;
    return note.entryId === entryId || note.pastEntryId === entryId;
  });

  let best: { note: MemoryNote; score: ReopenPayoffScore } | null = null;

  for (const note of pool) {
    const prepared = note.pastQuote?.trim()
      ? selectReopenQuotePair(note, entries) ?? note
      : note;
    if (shouldSuppressReopenPayoff(prepared, entries)) continue;

    const score = scoreReopenPayoff(prepared, entries);
    if (score.total < REOPEN_PAYOFF_MIN) continue;

    if (!best || score.total > best.score.total) {
      best = { note: prepared, score };
    }
  }

  if (!best) return { moment: null, score: null };
  return { moment: best.note, score: best.score };
}

export type ReopenQuietCopy = (typeof REVISIT_REWARD_COPY)[keyof typeof REVISIT_REWARD_COPY];

/** First visible line on revisit — maps payoff signals to quiet copy, no analysis language. */
export function pickReopenFirstLine(
  note: MemoryNote | null,
  entries: JournalEntry[],
  score?: ReopenPayoffScore | null,
): ReopenQuietCopy {
  const resolvedScore = score ?? (note ? scoreReopenPayoff(note, entries) : null);
  const signalIds = new Set(resolvedScore?.signals.map((row) => row.id) ?? []);

  if (signalIds.has("apology_disappearance") || signalIds.has("direct_naming")) {
    return REVISIT_REWARD_COPY.notNamedYet;
  }
  if (signalIds.has("calmer_tone") || signalIds.has("long_distance_contrast")) {
    return REVISIT_REWARD_COPY.soundFurtherAway;
  }
  if (signalIds.has("earlier_self_feeling") || signalIds.has("phrase_disappearance")) {
    return REVISIT_REWARD_COPY.beforeThingsChanged;
  }
  if (signalIds.has("emotional_wording_shift") || signalIds.has("changed_certainty")) {
    return REVISIT_REWARD_COPY.soundDifferentNow;
  }

  if (note?.pastQuote && note.currentQuote) {
    const hedgeDrop = hedgeScore(note.pastQuote) - hedgeScore(note.currentQuote);
    if (hedgeDrop >= 1) return REVISIT_REWARD_COPY.notNamedYet;
  }

  return REVISIT_REWARD_COPY.soundDifferentNow;
}

export interface ReopenAudioCandidate {
  note: MemoryNote;
  thenEntry: JournalEntry;
  nowEntry: JournalEntry;
  score: number;
}

/** Rank audio pairs for revisit — both clips required, emotional spread preferred. */
export function rankReopenAudioCandidates(
  currentEntry: JournalEntry,
  allEntries: JournalEntry[],
  notes: MemoryNote[],
): ReopenAudioCandidate[] {
  const ranked: ReopenAudioCandidate[] = [];

  for (const note of notes) {
    if (!note.pastEntryId) continue;
    const thenEntry = entryById(allEntries, note.pastEntryId);
    if (!thenEntry || thenEntry.id === currentEntry.id) continue;
    if (!thenEntry.audioId || !currentEntry.audioId) continue;

    const payoff = scoreReopenPayoff(note, allEntries);
    ranked.push({
      note,
      thenEntry,
      nowEntry: currentEntry,
      score: payoff.total + payoff.audioScore,
    });
  }

  return ranked.sort((a, b) => b.score - a.score);
}

export function resolveReopenVoicePlaybackPair(
  currentEntry: JournalEntry,
  allEntries: JournalEntry[],
  notes: MemoryNote[],
): VoicePlaybackPair | null {
  const ranked = rankReopenAudioCandidates(currentEntry, allEntries, notes);
  const best = ranked[0];
  if (!best) return null;
  return {
    kind: "then_vs_now",
    thenEntry: best.thenEntry,
    nowEntry: best.nowEntry,
  };
}


/** Follow-up timing after revisit — stronger payoff waits slightly longer so the moment lands. */
export function resolveReopenFollowupDelayMs(score: ReopenPayoffScore | null): number {
  if (!score) return 0;
  if (score.total >= REOPEN_PAYOFF_STRONG) return 45 * 60 * 1000;
  if (score.total >= REOPEN_PAYOFF_MIN) return 20 * 60 * 1000;
  return 0;
}

export function shouldShowReopenFollowupNow(score: ReopenPayoffScore | null, revisitOpenedAt: number): boolean {
  const delay = resolveReopenFollowupDelayMs(score);
  if (delay <= 0) return true;
  return Date.now() - revisitOpenedAt >= delay;
}

function conversionForEntry(entryId: string): {
  revisitCount: number;
  reflectionAfterPayoff: number;
  conversionRate: string;
} {
  const revisits = readMoatRevisits().filter((row) => row.entryId === entryId);
  const withReflection = revisits.filter((row) => Boolean(row.reflectionEntryId));
  const count = revisits.length;
  const reflections = withReflection.length;
  const rate = count > 0 ? `${Math.round((reflections / count) * 100)}%` : "—";
  return { revisitCount: count, reflectionAfterPayoff: reflections, conversionRate: rate };
}

/** Debug report — strongest reopen moments and revisit conversion after payoff. */
export function buildReopenPayoffDebugReport(entries: JournalEntry[]): ReopenPayoffDebugReport {
  const sorted = sortedEntries(entries);
  if (sorted.length < 2) {
    return {
      moments: [],
      avgPayoffScore: 0,
      strongMomentCount: 0,
      revisitConversionAfterPayoff: "—",
      hasData: false,
    };
  }

  const moments: ReopenPayoffMomentRow[] = [];

  for (const anchor of sorted.slice(0, -1)) {
    const later = sorted.filter(
      (row) => new Date(row.createdAt).getTime() > new Date(anchor.createdAt).getTime(),
    );
    const linked = later.find((row) => sharedThemes(anchor, row).length > 0) ?? later[later.length - 1];
    if (!linked) continue;

    const note: MemoryNote = {
      id: `reopen-debug-${anchor.id}-${linked.id}`,
      text: "",
      category: "returned",
      confidence: 68,
      pastQuote: trimRevisitQuote(snippet(anchor)),
      currentQuote: trimRevisitQuote(snippet(linked)),
      pastEntryId: anchor.id,
      entryId: linked.id,
    };

    const score = scoreReopenPayoff(note, entries);
    const prepared = selectReopenQuotePair(note, entries);
    if (!prepared && score.suppressed) continue;

    const firstLine = pickReopenFirstLine(prepared ?? note, entries, score);
    const conversion = conversionForEntry(anchor.id);

    moments.push({
      entryId: anchor.id,
      anchorEntryId: linked.id,
      payoffScore: score.total,
      signals: score.signals.map((row) => row.id),
      firstLine,
      pastQuote: prepared?.pastQuote ?? note.pastQuote,
      currentQuote: prepared?.currentQuote ?? note.currentQuote,
      gapDays: score.gapDays,
      hasAudio: Boolean(anchor.audioId && linked.audioId),
      suppressed: score.suppressed || shouldSuppressReopenPayoff(note, entries),
      suppressReason: score.suppressReason,
      ...conversion,
    });
  }

  const ranked = moments
    .filter((row) => !row.suppressed)
    .sort((a, b) => b.payoffScore - a.payoffScore)
    .slice(0, 12);

  const strong = ranked.filter((row) => row.payoffScore >= REOPEN_PAYOFF_STRONG);
  const avgPayoffScore =
    ranked.length > 0
      ? Math.round(ranked.reduce((sum, row) => sum + row.payoffScore, 0) / ranked.length)
      : 0;

  const totalRevisits = ranked.reduce((sum, row) => sum + row.revisitCount, 0);
  const totalReflections = ranked.reduce((sum, row) => sum + row.reflectionAfterPayoff, 0);
  const revisitConversionAfterPayoff =
    totalRevisits > 0 ? `${Math.round((totalReflections / totalRevisits) * 100)}%` : "—";

  return {
    moments: ranked,
    avgPayoffScore,
    strongMomentCount: strong.length,
    revisitConversionAfterPayoff,
    hasData: ranked.length > 0 || entries.length >= 2,
  };
}

export function formatReopenPayoffSummary(report: ReopenPayoffDebugReport): string {
  return `${report.strongMomentCount} strong · avg ${report.avgPayoffScore} · conversion ${report.revisitConversionAfterPayoff}`;
}
