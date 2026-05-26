import { trackLocalEvent } from "@/lib/local-analytics";
import type { JournalEntry } from "@/types/journal";
import type {
  CollapsedRepetition,
  PreservedPhrase,
  PreservedPhraseReason,
  PunctuationChange,
  TranscriptCleanupConfidence,
  TranscriptCleanupMeta,
  TranscriptCleanupResult,
} from "@/types/transcript-cleanup";

export const TRANSCRIPT_CLEANUP_EVENTS = {
  applied: "transcript_cleanup_applied",
  lowConfidence: "transcript_cleanup_low_confidence",
  phrasePreserved: "transcript_phrase_preserved",
} as const;

const PAUSE_MARKER_RES =
  /\[pause\]|\[long pause\]|\[silence\]|\.{3,}|…+|long silence/gi;

const STUTTER_WORD_BLOCKLIST = new Set([
  "again",
  "know",
  "dont",
  "don't",
  "same",
  "never",
  "always",
  "more",
  "still",
  "really",
  "just",
]);

const INTENTIONAL_REPEAT_PHRASE_RES = [
  /\bi don'?t know,\s*i don'?t know\b/gi,
  /\bagain and again\b/gi,
  /\bsame thing again\b/gi,
  /\bover and over\b/gi,
  /\bmore and more\b/gi,
];

const SELF_SPECIFIC_PHRASE_RES: Array<{ pattern: RegExp; reason: PreservedPhraseReason }> = [
  { pattern: /\bi keep [^.?!]{4,60}/gi, reason: "self_specific" },
  { pattern: /\bi thought i would be [^.?!]{4,60}/gi, reason: "self_specific" },
  { pattern: /\bi don'?t know why [^.?!]{4,80}/gi, reason: "emotional_load" },
  { pattern: /\bi guess [^.?!]{4,60}/gi, reason: "unusual_wording" },
  { pattern: /\bsort of [^.?!]{4,60}/gi, reason: "unusual_wording" },
  { pattern: /\bi'?m not sure [^.?!]{4,60}/gi, reason: "unusual_wording" },
  { pattern: /\bsame loop\b/gi, reason: "pattern_match" },
  { pattern: /\bcircling (?:this|it|around)\b/gi, reason: "pattern_match" },
];

const EMOTIONAL_LOAD_RES = [
  /\bi keep avoiding [^.?!]{2,40}/gi,
  /\bstill bothers me\b/gi,
  /\bcan'?t stop thinking\b/gi,
  /\bi thought i would be further ahead\b/gi,
];

const NAMED_ENTITY_RE = /\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b/g;

const FILLER_RULES: Array<{
  pattern: RegExp;
  label: string;
  replace: string | ((match: string) => string);
}> = [
  { pattern: /\b(u+m+|uh+|er+|ah+)\b[,.]?/gi, label: "um/uh", replace: " " },
  { pattern: /,\s*you know\s*,/gi, label: "you know", replace: ", " },
  { pattern: /(?:^|[.!?]\s+)you know\s*,\s*/gi, label: "you know", replace: " " },
  { pattern: /,\s*i mean\s*,/gi, label: "I mean", replace: ", " },
  { pattern: /(?:^|[.!?]\s+)i mean\s*,\s*/gi, label: "I mean", replace: " " },
  { pattern: /,\s*like\s*,/gi, label: "like", replace: ", " },
  { pattern: /(?:^|[.!?]\s+)basically\s+/gi, label: "basically", replace: " " },
  { pattern: /(?:^|[.!?]\s+)actually\s+/gi, label: "actually", replace: " " },
  { pattern: /(?:^|[.!?]\s+)literally\s+/gi, label: "literally", replace: " " },
  { pattern: /(?:^|[.!?]\s+)okay\s*,\s*/gi, label: "okay", replace: " " },
  { pattern: /(?:^|[.!?]\s+)so\s+(?=[A-Z])/gi, label: "so", replace: " " },
  { pattern: /,\s*sort of\s*,/gi, label: "sort of", replace: ", " },
  { pattern: /,\s*kind of\s*,/gi, label: "kind of", replace: ", " },
];

const QUESTION_START_RE =
  /^(who|what|when|where|why|how|is|are|am|was|were|do|does|did|can|could|would|will|should)\b/i;

export const TRANSCRIPT_CLEANUP_FIXTURES: Array<{ label: string; raw: string }> = [
  {
    label: "Filler-heavy stutter",
    raw: "um so like I I I keep avoiding this you know um I thought I would be further ahead",
  },
  {
    label: "Pause markers + repetition",
    raw: "I don't know why this still bothers me [pause] this this this came up again ... um yeah",
  },
  {
    label: "Intentional emotional repetition",
    raw: "I don't know, I don't know why it still hits me again and again same thing again",
  },
  {
    label: "Messy question",
    raw: "uh why do I keep circling this with Maya um I mean is this ever going to change",
  },
  {
    label: "Minimal noise",
    raw: "Today felt quieter. I named the thing I was avoiding.",
  },
];

function normalizeWhitespace(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function uniqueStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    const key = value.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(value);
  }
  return out;
}

function addPhrase(
  phrases: PreservedPhrase[],
  text: string,
  reason: PreservedPhraseReason,
): void {
  const trimmed = text.trim().replace(/\s+/g, " ");
  if (trimmed.length < 4 || trimmed.length > 120) return;
  phrases.push({ text: trimmed, reason });
}

function extractRepeatedExactPhrases(raw: string): PreservedPhrase[] {
  const phrases: PreservedPhrase[] = [];
  const lower = raw.toLowerCase();
  const words = lower.replace(/[^\w\s']/g, " ").split(/\s+/).filter(Boolean);

  for (let size = 3; size <= 6; size += 1) {
    const counts = new Map<string, number>();
    for (let i = 0; i <= words.length - size; i += 1) {
      const chunk = words.slice(i, i + size).join(" ");
      counts.set(chunk, (counts.get(chunk) ?? 0) + 1);
    }
    for (const [chunk, count] of counts.entries()) {
      if (count < 2) continue;
      const start = lower.indexOf(chunk);
      if (start < 0) continue;
      const original = raw.slice(start, start + chunk.length);
      addPhrase(phrases, original, "repeated_exact");
    }
  }

  return phrases;
}

function extractPreservedPhrases(raw: string): PreservedPhrase[] {
  const phrases: PreservedPhrase[] = [];

  for (const pattern of INTENTIONAL_REPEAT_PHRASE_RES) {
    const re = new RegExp(pattern.source, pattern.flags);
    let match: RegExpExecArray | null;
    while ((match = re.exec(raw)) !== null) {
      addPhrase(phrases, match[0], "repeated_exact");
    }
  }

  for (const { pattern, reason } of SELF_SPECIFIC_PHRASE_RES) {
    const re = new RegExp(pattern.source, pattern.flags);
    let match: RegExpExecArray | null;
    while ((match = re.exec(raw)) !== null) {
      addPhrase(phrases, match[0], reason);
    }
  }

  for (const pattern of EMOTIONAL_LOAD_RES) {
    const re = new RegExp(pattern.source, pattern.flags);
    let match: RegExpExecArray | null;
    while ((match = re.exec(raw)) !== null) {
      addPhrase(phrases, match[0], "emotional_load");
    }
  }

  phrases.push(...extractRepeatedExactPhrases(raw));

  const entityRe = new RegExp(NAMED_ENTITY_RE.source, NAMED_ENTITY_RE.flags);
  let entityMatch: RegExpExecArray | null;
  while ((entityMatch = entityRe.exec(raw)) !== null) {
    const name = entityMatch[0].trim();
    if (["I", "Today", "Yesterday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].includes(name)) {
      continue;
    }
    addPhrase(phrases, name, "named_entity");
  }

  const deduped = new Map<string, PreservedPhrase>();
  for (const phrase of phrases) {
    const key = phrase.text.toLowerCase();
    if (!deduped.has(key)) deduped.set(key, phrase);
  }

  return [...deduped.values()].slice(0, 12);
}

function overlapsProtected(text: string, start: number, end: number, protectedPhrases: PreservedPhrase[]): boolean {
  const slice = text.slice(start, end).toLowerCase();
  return protectedPhrases.some((phrase) => {
    const lower = phrase.text.toLowerCase();
    return slice.includes(lower) || lower.includes(slice.trim());
  });
}

function normalizePauses(
  text: string,
  punctuationChanges: PunctuationChange[],
): string {
  return text.replace(PAUSE_MARKER_RES, (match, offset) => {
    punctuationChanges.push({
      kind: "pause_normalized",
      at: offset,
      detail: `Pause marker "${match.trim()}" became a sentence break`,
    });
    return ". ";
  });
}

function removeFillers(
  text: string,
  preservedPhrases: PreservedPhrase[],
  removedFillers: string[],
): string {
  let output = text;

  for (const rule of FILLER_RULES) {
    const re = new RegExp(rule.pattern.source, rule.pattern.flags);
    output = output.replace(re, (match, offset) => {
      if (overlapsProtected(output, offset, offset + match.length, preservedPhrases)) {
        return match;
      }
      removedFillers.push(rule.label);
      return typeof rule.replace === "string" ? rule.replace : rule.replace(match);
    });
  }

  return normalizeWhitespace(output);
}

function collapseWordStutters(
  text: string,
  preservedPhrases: PreservedPhrase[],
  collapsedRepetitions: CollapsedRepetition[],
): string {
  return text.replace(/\b([A-Za-z']{1,14})(?:\s+\1){1,}\b/gi, (match, word, offset) => {
    const lower = word.toLowerCase();
    if (STUTTER_WORD_BLOCKLIST.has(lower)) return match;
    if (overlapsProtected(text, offset, offset + match.length, preservedPhrases)) return match;

    collapsedRepetitions.push({ original: match, collapsed: word });
    return word;
  });
}

function recoverPunctuation(
  text: string,
  punctuationChanges: PunctuationChange[],
): string {
  let output = text;

  const sentences = output
    .split(/(?<=[.!?])\s+/)
    .flatMap((part) => {
      if (part.length <= 140) return [part];
      punctuationChanges.push({
        kind: "sentence_break",
        at: output.indexOf(part),
        detail: "Split a long stretch into shorter sentences",
      });
      return part
        .split(/,\s+(?=[a-z])/g)
        .map((chunk, index, arr) => (index < arr.length - 1 ? `${chunk}.` : chunk));
    })
    .join(" ");

  output = sentences.replace(/\s+([,.!?])/g, "$1");

  output = output.replace(
    /(?:^|[.!?]\s+)([^.?!]{8,120}\?)/g,
    (match, clause: string, offset) => {
      const trimmed = clause.trim();
      if (trimmed.endsWith("?")) return match;
      if (!QUESTION_START_RE.test(trimmed)) return match;
      punctuationChanges.push({
        kind: "question_mark",
        at: offset,
        detail: `Added question mark to "${trimmed.slice(0, 40)}…"`,
      });
      return match.replace(clause, `${trimmed}?`);
    },
  );

  output = output.replace(/\?\?+/g, "?");
  output = output.replace(/\.{2,}/g, ".");
  output = output.replace(/\s+/g, " ").trim();

  if (output && !/[.!?]$/.test(output)) {
    output += ".";
    punctuationChanges.push({
      kind: "sentence_break",
      at: output.length - 1,
      detail: "Closed an unfinished sentence",
    });
  }

  return output;
}

function computeConfidence(
  raw: string,
  cleaned: string,
  removedFillers: string[],
  preservedPhrases: PreservedPhrase[],
  warnings: string[],
): TranscriptCleanupConfidence {
  const rawWords = raw.split(/\s+/).filter(Boolean).length;
  const cleanedWords = cleaned.split(/\s+/).filter(Boolean).length;
  if (rawWords === 0) return "low";

  const retention = cleanedWords / rawWords;
  const fillerRatio = removedFillers.length / Math.max(rawWords, 1);

  for (const phrase of preservedPhrases) {
    if (!cleaned.toLowerCase().includes(phrase.text.toLowerCase())) {
      warnings.push(`Preserved phrase may have shifted: "${phrase.text}"`);
    }
  }

  if (retention < 0.55 || fillerRatio > 0.35 || warnings.length >= 3) return "low";
  if (retention < 0.75 || fillerRatio > 0.18 || warnings.length > 0) return "medium";
  return "high";
}

/** Clean obvious ASR noise while preserving distinctive self-language. */
export function cleanupTranscript(rawTranscript: string): TranscriptCleanupResult {
  const raw = rawTranscript.trim();
  const cleanupWarnings: string[] = [];
  const removedFillers: string[] = [];
  const collapsedRepetitions: CollapsedRepetition[] = [];
  const punctuationChanges: PunctuationChange[] = [];

  if (!raw) {
    return {
      rawTranscript: raw,
      cleanedTranscript: "",
      preservedPhrases: [],
      removedFillers: [],
      collapsedRepetitions: [],
      punctuationChanges: [],
      confidence: "low",
      cleanupWarnings: ["Empty transcript"],
    };
  }

  const preservedPhrases = extractPreservedPhrases(raw);

  let working = normalizePauses(raw, punctuationChanges);
  working = removeFillers(working, preservedPhrases, removedFillers);
  working = collapseWordStutters(working, preservedPhrases, collapsedRepetitions);
  working = recoverPunctuation(working, punctuationChanges);

  const confidence = computeConfidence(
    raw,
    working,
    removedFillers,
    preservedPhrases,
    cleanupWarnings,
  );

  if (working.length < raw.length * 0.45) {
    cleanupWarnings.push("Cleanup removed a large share of the transcript — review recommended.");
  }

  return {
    rawTranscript: raw,
    cleanedTranscript: working,
    preservedPhrases,
    removedFillers: uniqueStrings(removedFillers),
    collapsedRepetitions,
    punctuationChanges,
    confidence,
    cleanupWarnings,
  };
}

export function toTranscriptCleanupMeta(result: TranscriptCleanupResult): TranscriptCleanupMeta {
  return {
    preservedPhrases: result.preservedPhrases.map((phrase) => phrase.text),
    confidence: result.confidence,
    appliedAt: new Date().toISOString(),
  };
}

export function prepareTranscriptForSave(rawTranscript: string): {
  transcript: string;
  rawTranscript: string;
  transcriptCleanup: TranscriptCleanupMeta;
  result: TranscriptCleanupResult;
} {
  const result = cleanupTranscript(rawTranscript);
  return {
    transcript: result.cleanedTranscript || result.rawTranscript,
    rawTranscript: result.rawTranscript,
    transcriptCleanup: toTranscriptCleanupMeta(result),
    result,
  };
}

export function trackTranscriptCleanupEvents(result: TranscriptCleanupResult, entryId?: string): void {
  const meta = entryId ? { entryId } : undefined;
  trackLocalEvent(TRANSCRIPT_CLEANUP_EVENTS.applied, {
    ...meta,
    confidence: result.confidence,
  });

  if (result.confidence === "low") {
    trackLocalEvent(TRANSCRIPT_CLEANUP_EVENTS.lowConfidence, meta);
  }

  for (const phrase of result.preservedPhrases) {
    trackLocalEvent(TRANSCRIPT_CLEANUP_EVENTS.phrasePreserved, {
      ...meta,
      phrase: phrase.text.slice(0, 80),
      reason: phrase.reason,
    });
  }
}

/** Display transcript — cleaned when available. */
export function transcriptForDisplay(entry: JournalEntry): string {
  return entry.transcript.trim();
}

/** Phrase scanning text — cleaned transcript plus preserved anchors when needed. */
export function transcriptForPhraseScanning(entry: JournalEntry): string {
  let text = entry.transcript.trim();
  const preserved = entry.transcriptCleanup?.preservedPhrases ?? [];

  for (const phrase of preserved) {
    const trimmed = phrase.trim();
    if (!trimmed) continue;
    if (!text.toLowerCase().includes(trimmed.toLowerCase())) {
      text = `${text} ${trimmed}`.trim();
    }
  }

  return text;
}

/** Audit transcript — raw ASR when stored, otherwise cleaned. */
export function transcriptForAudit(entry: JournalEntry): string {
  return entry.rawTranscript?.trim() || entry.transcript.trim();
}
