import { formatEntryDate } from "@/lib/utils";
import type { PredictionCandidate, PredictionPolarity } from "@/types/blind-spot-acceleration";
import type { JournalEntry } from "@/types/journal";

const PREDICTION_KEY = "voicememory_blind_spot_predictions";

const TRIGGER_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /\bi think\b/gi, label: "I think" },
  { re: /\bthis will\b/gi, label: "This will" },
  { re: /\bprobably\b/gi, label: "Probably" },
  { re: /\bdefinitely\b/gi, label: "Definitely" },
  { re: /\bi'?m sure\b/gi, label: "I'm sure" },
];

const NEGATIVE_MARKERS =
  /\b(fail|won'?t|will not|terrible|awful|disaster|ruin|never work|go wrong|fall apart|mess up)\b/i;
const POSITIVE_MARKERS =
  /\b(will work|going great|succeed|turn out well|be fine|work out|get better)\b/i;
const FAILURE_MARKERS = /\b(fail|failure|mess up|fall apart|go wrong)\b/i;

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function newId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `pred-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function sentenceAround(text: string, index: number): string {
  const before = text.slice(0, index);
  const after = text.slice(index);
  const start = Math.max(
    0,
    Math.max(before.lastIndexOf("."), before.lastIndexOf("!"), before.lastIndexOf("?")) + 1,
  );
  let end = after.search(/[.!?]/);
  if (end === -1) end = after.length;
  else end += 1;
  return text.slice(start, index + end).replace(/\s+/g, " ").trim();
}

function polarityFor(clause: string): PredictionPolarity {
  if (NEGATIVE_MARKERS.test(clause) || FAILURE_MARKERS.test(clause)) return "negative";
  if (POSITIVE_MARKERS.test(clause)) return "positive";
  return "neutral";
}

/** Extract prediction clauses from a transcript. */
export function extractPredictionsFromText(
  entryId: string,
  createdAt: string,
  transcript: string,
): PredictionCandidate[] {
  const results: PredictionCandidate[] = [];
  const seen = new Set<string>();

  for (const { re, label } of TRIGGER_PATTERNS) {
    re.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = re.exec(transcript)) !== null) {
      const quote = sentenceAround(transcript, match.index);
      if (quote.length < 12 || quote.length > 240) continue;
      const key = quote.toLowerCase().slice(0, 80);
      if (seen.has(key)) continue;
      seen.add(key);

      results.push({
        id: `pred:${entryId}:${label}:${key.slice(0, 24)}`,
        entryId,
        predictedAt: createdAt,
        dateLabel: formatEntryDate(createdAt),
        quote,
        triggerPhrase: label,
        polarity: polarityFor(quote),
      });
    }
  }

  return results;
}

export function extractPredictionsFromEntries(entries: JournalEntry[]): PredictionCandidate[] {
  const all: PredictionCandidate[] = [];
  for (const entry of entries) {
    if (entry.reflectionPending) continue;
    const text = entry.transcript.trim();
    if (!text) continue;
    all.push(...extractPredictionsFromText(entry.id, entry.createdAt, text));
  }
  return all;
}

function readStored(): PredictionCandidate[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(PREDICTION_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (row): row is PredictionCandidate =>
        Boolean(row) &&
        typeof row === "object" &&
        typeof (row as PredictionCandidate).quote === "string" &&
        typeof (row as PredictionCandidate).entryId === "string",
    );
  } catch {
    return [];
  }
}

function writeStored(candidates: PredictionCandidate[]): void {
  const store = getStorage();
  if (!store) return;
  store.setItem(PREDICTION_KEY, JSON.stringify(candidates.slice(-300)));
}

/** Merge freshly extracted candidates into local storage. */
export function syncPredictionCandidates(entries: JournalEntry[]): PredictionCandidate[] {
  const extracted = extractPredictionsFromEntries(entries);
  const byId = new Map<string, PredictionCandidate>();
  for (const row of readStored()) {
    byId.set(row.id, row);
  }
  for (const row of extracted) {
    byId.set(row.id, row);
  }
  const merged = [...byId.values()].sort(
    (a, b) => new Date(b.predictedAt).getTime() - new Date(a.predictedAt).getTime(),
  );
  writeStored(merged);
  return merged;
}

export function readPredictionCandidates(): PredictionCandidate[] {
  return readStored();
}

export function clearPredictionCandidatesForEval(): void {
  getStorage()?.removeItem(PREDICTION_KEY);
}
