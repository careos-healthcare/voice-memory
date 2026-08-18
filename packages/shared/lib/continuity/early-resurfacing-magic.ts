import { buildReturnThreads } from "@/lib/continuity/return-threads";
import {
  gateContinuityLine,
  gateContinuityQuote,
} from "@/lib/continuity/continuity-quality-gate";
import { isPrimarySurfacedReflection } from "@/lib/reflection/reflection-quality-gate";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import type { ReturnThread, ReturnThreadType } from "@/types/return-thread";
import type { JournalEntry } from "@/types/journal";

const EARLY_LINE_MAX = 88;
const MIN_PHRASE_LEN = 4;
const MIN_PERSON_LEN = 2;
const MIN_SCORE_TWO_REFLECTIONS = 58;
const MIN_SCORE_THREE_PLUS = 50;

const STOP_WORDS = new Set([
  "a",
  "an",
  "the",
  "and",
  "or",
  "but",
  "so",
  "to",
  "of",
  "in",
  "on",
  "at",
  "it",
  "is",
  "was",
  "are",
  "be",
  "i",
  "you",
  "we",
  "my",
  "me",
  "that",
  "this",
  "with",
  "for",
  "just",
  "like",
  "really",
  "very",
  "uh",
  "um",
]);

function qualityEntries(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter(isPrimarySurfacedReflection);
}

function quotePhrase(phrase: string): string {
  const trimmed = phrase.trim().slice(0, 48);
  if (!trimmed) return "";
  if (
    (trimmed.startsWith("'") && trimmed.endsWith("'")) ||
    (trimmed.startsWith('"') && trimmed.endsWith('"'))
  ) {
    return trimmed;
  }
  return `'${trimmed}'`;
}

function weekdayLabel(iso: string): string {
  return new Intl.DateTimeFormat("en-US", { weekday: "long" }).format(new Date(iso));
}

function meaningfulTokens(text: string): Set<string> {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9'\s]/g, " ")
    .split(/\s+/)
    .map((w) => w.replace(/[^a-z0-9']/g, ""))
    .filter((w) => w.length > 2 && !STOP_WORDS.has(w));
  return new Set(words);
}

function transcriptsEcho(a: string, b: string): boolean {
  const ta = meaningfulTokens(a);
  const tb = meaningfulTokens(b);
  if (ta.size < 3 || tb.size < 3) return false;
  let shared = 0;
  for (const token of ta) {
    if (tb.has(token)) shared += 1;
  }
  return shared >= 3;
}

function trimLine(line: string): string {
  const trimmed = line.trim();
  if (trimmed.length <= EARLY_LINE_MAX) return trimmed;
  return `${trimmed.slice(0, EARLY_LINE_MAX - 1)}…`;
}

function scoreThread(thread: ReturnThread, minScore: number): number {
  const anchor = gateContinuityQuote(thread.anchorQuote);
  const latest = gateContinuityQuote(thread.latestQuote);
  if (!anchor && !latest) return 0;
  if (thread.appearances < 2) return 0;

  let score = 40 + thread.appearances * 6;
  if (anchor && latest && anchor !== latest) score += 8;
  if (thread.gapDays != null && thread.gapDays >= 1) score += 4;

  const typeBoost: Partial<Record<ReturnThreadType, number>> = {
    repeated_phrase: 18,
    recurring_person: 16,
    recurring_uncertainty: 12,
    unresolved_problem: 10,
    silence_then_return: 8,
  };
  score += typeBoost[thread.type] ?? 4;

  return score >= minScore ? score : 0;
}

function lineFromThread(thread: ReturnThread): string | null {
  const label = thread.contextLabel?.trim();
  switch (thread.type) {
    case "repeated_phrase": {
      const phrase = label || gateContinuityQuote(thread.anchorQuote) || "";
      if (phrase.length < MIN_PHRASE_LEN) return null;
      return trimLine(`You mentioned ${quotePhrase(phrase)} again.`);
    }
    case "recurring_person": {
      if (!label || label.length < MIN_PERSON_LEN) return null;
      return trimLine(`You talked about ${label} again.`);
    }
    case "recurring_uncertainty": {
      if (label && label.length >= MIN_PHRASE_LEN) {
        return trimLine(`The same uncertainty about ${label} showed up again.`);
      }
      return "The same uncertainty showed up again.";
    }
    case "unresolved_problem":
      return "This thread still feels unfinished.";
    case "silence_then_return": {
      const day = weekdayLabel(thread.firstSeenAt);
      return trimLine(`This sounds close to what you said on ${day}.`);
    }
    default:
      return null;
  }
}

function lineFromRecentEcho(entries: JournalEntry[]): string | null {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  if (sorted.length < 2) return null;
  const prior = sorted[sorted.length - 2];
  const latest = sorted[sorted.length - 1];
  const priorText = prior.transcript?.trim();
  const latestText = latest.transcript?.trim();
  if (!priorText || !latestText) return null;
  if (!transcriptsEcho(latestText, priorText)) return null;
  return trimLine(`This sounds close to what you said on ${weekdayLabel(prior.createdAt)}.`);
}

function lineFromPhraseMemory(entries: JournalEntry[]): string | null {
  for (const record of buildPhraseMemory(entries)) {
    if (record.entryIds.length < 2 || record.count < 2) continue;
    const phrase = record.phrase.trim();
    if (phrase.length < MIN_PHRASE_LEN || phrase.length > 56) continue;
    const line = trimLine(`You mentioned ${quotePhrase(phrase)} again.`);
    if (gateContinuityLine(line)) return line;
  }
  return null;
}

interface ScoredLine {
  line: string;
  score: number;
}

/** One short quote-led line after 2+ quality reflections — null when confidence is weak. */
export function pickEarlyResurfacingMagicLine(entries: JournalEntry[]): string | null {
  const quality = qualityEntries(entries);
  const count = quality.length;
  if (count < 2) return null;

  const minScore = count >= 3 ? MIN_SCORE_THREE_PLUS : MIN_SCORE_TWO_REFLECTIONS;
  const { threads } = buildReturnThreads(quality);
  const candidates: ScoredLine[] = [];

  for (const thread of threads) {
    const score = scoreThread(thread, minScore);
    if (!score) continue;
    const line = lineFromThread(thread);
    if (!line || !gateContinuityLine(line)) continue;
    candidates.push({ line, score });
  }

  const echoLine = lineFromRecentEcho(quality);
  if (echoLine && gateContinuityLine(echoLine)) {
    candidates.push({ line: echoLine, score: minScore + 6 });
  }

  const phraseLine = lineFromPhraseMemory(quality);
  if (phraseLine) {
    candidates.push({ line: phraseLine, score: minScore + 4 });
  }

  if (candidates.length === 0) return null;

  candidates.sort((a, b) => b.score - a.score);
  return candidates[0]?.line ?? null;
}
