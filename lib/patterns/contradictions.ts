import { addDaysToKey, toDayKey } from "@/lib/dates";
import { formatEntryDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

export type ContradictionKind =
  | "conflicting_statement"
  | "failed_intention"
  | "emotional_reversal"
  | "goal_behavior_tension"
  | "want_vs_keep_doing";

export interface ContradictionEvidence {
  entryId: string;
  dateKey: string;
  dateLabel: string;
  phrase: string;
  mood?: string;
}

export interface Contradiction {
  id: string;
  kind: ContradictionKind;
  title: string;
  explanation: string;
  evidence: ContradictionEvidence[];
  confidence: number;
  entryIds: string[];
  theme?: string;
}

const INTENTION_PATTERNS = [
  /\bi(?:'ll| will)\s+([^,.!?]{4,50})/gi,
  /\bi(?:'m| am) going to\s+([^,.!?]{4,50})/gi,
  /\bi need to\s+([^,.!?]{4,50})/gi,
];

const WANT_PATTERNS = [
  /\bi want to\s+([^,.!?]{4,60})/gi,
  /\bi wanted to\s+([^,.!?]{4,60})/gi,
  /\bi'd like to\s+([^,.!?]{4,60})/gi,
];

const KEEP_PATTERNS = [
  /\bi keep\s+([^,.!?]{4,60})/gi,
  /\bi kept\s+([^,.!?]{4,60})/gi,
  /\bi always\s+([^,.!?]{4,60})/gi,
];

const GOAL_MARKERS = ["want to", "trying to", "plan to", "hope to", "goal", "intention"];
const BEHAVIOR_MARKERS = [
  "didn't",
  "did not",
  "avoided",
  "skipped",
  "put off",
  "again",
  "still haven't",
  "keep",
  "kept",
];

const POSITIVE_MOODS = new Set(["hopeful", "calm", "relieved", "grounded", "steady", "content"]);
const NEGATIVE_MOODS = new Set([
  "anxious",
  "worried",
  "stressed",
  "overwhelmed",
  "conflicted",
  "frustrated",
]);

function sortedEntries(entries: JournalEntry[]): JournalEntry[] {
  return [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
}

function themeOverlap(a: string[], b: string[]): string[] {
  const setB = new Set(b.map((t) => t.toLowerCase()));
  return a.filter((t) => setB.has(t.toLowerCase()));
}

function moodValence(mood: string): "positive" | "negative" | "neutral" {
  const m = mood.toLowerCase();
  if (POSITIVE_MOODS.has(m)) return "positive";
  if (NEGATIVE_MOODS.has(m)) return "negative";
  return "neutral";
}

function supportingPhrase(entry: JournalEntry): string {
  if (entry.reflection.exactLanguagePattern?.trim()) {
    return entry.reflection.exactLanguagePattern.trim().slice(0, 140);
  }
  const obs = entry.reflection.patternObservations?.find((o) => o.trim());
  if (obs) return obs.trim().slice(0, 140);
  if (entry.reflection.concreteObservation?.trim()) {
    return entry.reflection.concreteObservation.trim().slice(0, 140);
  }
  if (entry.reflection.repeatedSignal?.trim()) {
    return entry.reflection.repeatedSignal.trim().slice(0, 140);
  }
  const sentence = entry.transcript.match(/[^.!?]+[.!?]/)?.[0];
  return (sentence ?? entry.transcript).trim().slice(0, 140);
}

function evidenceFrom(entry: JournalEntry): ContradictionEvidence {
  return {
    entryId: entry.id,
    dateKey: toDayKey(entry.createdAt),
    dateLabel: formatEntryDate(entry.createdAt),
    phrase: supportingPhrase(entry),
    mood: entry.reflection.mood,
  };
}

function extractMatches(text: string, patterns: RegExp[]): string[] {
  const results: string[] = [];
  for (const pattern of patterns) {
    const re = new RegExp(pattern.source, pattern.flags);
    let match: RegExpExecArray | null;
    while ((match = re.exec(text)) !== null) {
      const value = (match[1] ?? match[0]).trim().toLowerCase();
      if (value.length >= 4) results.push(value);
    }
  }
  return results;
}

function wordOverlap(a: string, b: string): number {
  const wordsA = new Set(a.toLowerCase().split(/\s+/).filter((w) => w.length > 3));
  return b
    .toLowerCase()
    .split(/\s+/)
    .filter((w) => w.length > 3 && wordsA.has(w)).length;
}

function scoreConfidence(
  evidence: ContradictionEvidence[],
  opts: { sharedTheme?: boolean; phraseOverlap?: number; sameWeek?: boolean },
): number {
  let score = evidence.length >= 3 ? 55 : evidence.length >= 2 ? 42 : 28;
  if (opts.sharedTheme) score += 15;
  if ((opts.phraseOverlap ?? 0) >= 2) score += 12;
  if (opts.sameWeek) score += 8;
  return Math.min(95, score);
}

function dedupeContradictions(items: Contradiction[]): Contradiction[] {
  const seen = new Set<string>();
  return items
    .sort((a, b) => b.confidence - a.confidence)
    .filter((item) => {
      const key = `${item.kind}:${item.theme ?? item.title}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
}

function detectEmotionalReversals(sorted: JournalEntry[]): Contradiction[] {
  const results: Contradiction[] = [];

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    for (let j = Math.max(0, i - 8); j < i; j += 1) {
      const prev = sorted[j];
      const shared = themeOverlap(
        current.reflection.recurringThemes,
        prev.reflection.recurringThemes,
      );
      if (shared.length === 0) continue;

      const prevValence = moodValence(prev.reflection.mood);
      const currentValence = moodValence(current.reflection.mood);
      if (
        prevValence === "neutral" ||
        currentValence === "neutral" ||
        prevValence === currentValence
      ) {
        continue;
      }

      const theme = shared[0];
      const evidence = [evidenceFrom(prev), evidenceFrom(current)];
      results.push({
        id: `reversal-${prev.id}-${current.id}`,
        kind: "emotional_reversal",
        title: `Emotional shift around "${theme}"`,
        explanation: `You described this differently over time — ${prev.reflection.mood} earlier and ${current.reflection.mood} later when "${theme}" came up. This notes a shift in your language, not a diagnosis.`,
        evidence,
        confidence: scoreConfidence(evidence, {
          sharedTheme: true,
          sameWeek:
            toDayKey(prev.createdAt) >= addDaysToKey(toDayKey(current.createdAt), -7),
        }),
        entryIds: [prev.id, current.id],
        theme,
      });
    }
  }

  return results;
}

function detectFailedIntentions(sorted: JournalEntry[]): Contradiction[] {
  const results: Contradiction[] = [];

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    const currentText = current.transcript.toLowerCase();

    for (let j = Math.max(0, i - 6); j < i; j += 1) {
      const prev = sorted[j];
      const intentions = extractMatches(prev.transcript, INTENTION_PATTERNS);
      if (intentions.length === 0) continue;

      for (const intention of intentions) {
        const stem = intention.split(" ")[0];
        const repeatedLater = extractMatches(current.transcript, INTENTION_PATTERNS).some(
          (i) => i.includes(stem),
        );
        const stalled =
          BEHAVIOR_MARKERS.some((m) => currentText.includes(m)) &&
          wordOverlap(intention, currentText) >= 1;

        if (!repeatedLater && !stalled) continue;

        const evidence = [evidenceFrom(prev), evidenceFrom(current)];
        results.push({
          id: `intention-${prev.id}-${current.id}-${stem}`,
          kind: "failed_intention",
          title: "Repeated or stalled intention",
          explanation: `There may be tension between stating "${intention}" and how you describe things later. This flags a language pattern — not a personal failure.`,
          evidence,
          confidence: scoreConfidence(evidence, {
            phraseOverlap: wordOverlap(intention, currentText),
            sameWeek:
              toDayKey(prev.createdAt) >= addDaysToKey(toDayKey(current.createdAt), -14),
          }),
          entryIds: [prev.id, current.id],
        });
        break;
      }
    }
  }

  return results;
}

function detectGoalBehaviorTension(sorted: JournalEntry[]): Contradiction[] {
  const results: Contradiction[] = [];

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    const currentText = current.transcript.toLowerCase();

    for (let j = Math.max(0, i - 5); j < i; j += 1) {
      const prev = sorted[j];
      const prevText = prev.transcript.toLowerCase();
      const hasGoal = GOAL_MARKERS.some((g) => prevText.includes(g));
      const hasBehavior = BEHAVIOR_MARKERS.some((b) => currentText.includes(b));
      const shared = themeOverlap(
        current.reflection.recurringThemes,
        prev.reflection.recurringThemes,
      );

      if (!hasGoal || !hasBehavior || shared.length === 0) continue;

      const theme = shared[0];
      const evidence = [evidenceFrom(prev), evidenceFrom(current)];
      results.push({
        id: `goal-behavior-${prev.id}-${current.id}`,
        kind: "goal_behavior_tension",
        title: `Stated aim vs described behavior`,
        explanation: `There may be tension between a stated aim around "${theme}" and behavior you describe later (avoidance, delay, or repetition). This compares your words over time — not a clinical assessment.`,
        evidence,
        confidence: scoreConfidence(evidence, { sharedTheme: true }),
        entryIds: [prev.id, current.id],
        theme,
      });
      break;
    }
  }

  return results;
}

function detectWantVsKeepDoing(sorted: JournalEntry[]): Contradiction[] {
  const results: Contradiction[] = [];

  for (let i = 0; i < sorted.length; i += 1) {
    const entry = sorted[i];
    const wants = extractMatches(entry.transcript, WANT_PATTERNS);
    const keeps = extractMatches(entry.transcript, KEEP_PATTERNS);

    for (const want of wants) {
      for (const keep of keeps) {
        if (wordOverlap(want, keep) >= 1 || want.split(" ")[0] === keep.split(" ")[0]) {
          const evidence = [evidenceFrom(entry)];
          results.push({
            id: `want-keep-${entry.id}-${want.slice(0, 8)}`,
            kind: "want_vs_keep_doing",
            title: `"I want" vs "I keep" in the same thread`,
            explanation: `There may be tension between wanting "${want}" and describing that you keep "${keep}". This surfaces both framings in your words — not a judgment about what you should do.`,
            evidence,
            confidence: scoreConfidence(evidence, { phraseOverlap: 2 }),
            entryIds: [entry.id],
            theme: want.split(" ").slice(0, 3).join(" "),
          });
        }
      }
    }

    for (let j = i + 1; j < Math.min(sorted.length, i + 6); j += 1) {
      const later = sorted[j];
      const laterKeeps = extractMatches(later.transcript, KEEP_PATTERNS);
      for (const want of wants) {
        for (const keep of laterKeeps) {
          if (wordOverlap(want, keep) < 1 && !later.transcript.toLowerCase().includes(want.split(" ")[0])) {
            continue;
          }
          const evidence = [evidenceFrom(entry), evidenceFrom(later)];
          results.push({
            id: `want-keep-cross-${entry.id}-${later.id}`,
            kind: "want_vs_keep_doing",
            title: `Wanting one thing, describing another`,
            explanation: `You said you want "${want}" in one entry and later describe that you keep "${keep}". There may be tension between those two ways of framing the same thread.`,
            evidence,
            confidence: scoreConfidence(evidence, {
              phraseOverlap: wordOverlap(want, keep),
              sameWeek:
                toDayKey(entry.createdAt) >= addDaysToKey(toDayKey(later.createdAt), -7),
            }),
            entryIds: [entry.id, later.id],
            theme: want.split(" ").slice(0, 3).join(" "),
          });
        }
      }
    }
  }

  return results;
}

function detectConflictingStatements(sorted: JournalEntry[]): Contradiction[] {
  const results: Contradiction[] = [];

  for (let i = 1; i < sorted.length; i += 1) {
    const current = sorted[i];
    const currentObs =
      current.reflection.concreteObservation ??
      current.reflection.patternObservations?.[0] ??
      "";

    for (let j = Math.max(0, i - 4); j < i; j += 1) {
      const prev = sorted[j];
      const prevObs =
        prev.reflection.concreteObservation ??
        prev.reflection.patternObservations?.[0] ??
        "";
      const shared = themeOverlap(
        current.reflection.recurringThemes,
        prev.reflection.recurringThemes,
      );

      if (!prevObs || !currentObs || prevObs === currentObs || shared.length === 0) {
        continue;
      }

      const overlap = wordOverlap(prevObs, currentObs);
      if (overlap < 2) continue;

      const theme = shared[0];
      const evidence = [evidenceFrom(prev), evidenceFrom(current)];
      results.push({
        id: `conflict-${prev.id}-${current.id}`,
        kind: "conflicting_statement",
        title: `Different framing of "${theme}"`,
        explanation: `You described this differently over time around "${theme}". The entries below use overlapping language but point in different directions — a pattern in your words, not a diagnosis.`,
        evidence,
        confidence: scoreConfidence(evidence, {
          sharedTheme: true,
          phraseOverlap: overlap,
        }),
        entryIds: [prev.id, current.id],
        theme,
      });
    }
  }

  return results;
}

/** Detect contradictions across the full entry archive. */
export function detectAllContradictions(entries: JournalEntry[]): Contradiction[] {
  if (entries.length < 2) return [];

  const sorted = sortedEntries(entries);
  const combined = [
    ...detectConflictingStatements(sorted),
    ...detectEmotionalReversals(sorted),
    ...detectFailedIntentions(sorted),
    ...detectGoalBehaviorTension(sorted),
    ...detectWantVsKeepDoing(sorted),
  ];

  return dedupeContradictions(combined).slice(0, 12);
}

/** Contradictions involving a specific entry. */
export function detectContradictionsForEntry(
  entries: JournalEntry[],
  entryId: string,
): Contradiction[] {
  return detectAllContradictions(entries).filter((c) => c.entryIds.includes(entryId));
}

/** Contradictions with evidence in the last N days. */
export function detectRecentContradictions(
  entries: JournalEntry[],
  days = 7,
): Contradiction[] {
  const cutoff = addDaysToKey(toDayKey(new Date().toISOString()), -(days - 1));
  return detectAllContradictions(entries).filter((c) =>
    c.evidence.some((e) => e.dateKey >= cutoff),
  );
}

/** Adapter for legacy pattern-insights shape. */
export function toLegacyContradictionMatch(c: Contradiction): {
  id: string;
  label: string;
  detail: string;
  priorEntryId?: string;
  kind: ContradictionKind;
} {
  return {
    id: c.id,
    kind: c.kind,
    label: c.title,
    detail: c.explanation,
    priorEntryId: c.entryIds.length > 1 ? c.entryIds[0] : undefined,
  };
}
