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

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
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
        title: `${capitalize(theme)} went from ${prev.reflection.mood} to ${current.reflection.mood}.`,
        explanation: `${formatEntryDate(prev.createdAt)}: "${supportingPhrase(prev).slice(0, 90)}" · ${formatEntryDate(current.createdAt)}: "${supportingPhrase(current).slice(0, 90)}"`,
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
          title: `You named "${intention.slice(0, 45)}${intention.length > 45 ? "…" : ""}" — still circling it later.`,
          explanation: `${formatEntryDate(prev.createdAt)} you said you would ${intention.slice(0, 60)}; ${formatEntryDate(current.createdAt)} the same thread reads stalled or repeated.`,
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
        title: `You named an aim around ${theme}; later you describe delay or repetition.`,
        explanation: `Around "${theme}": goal language on ${formatEntryDate(prev.createdAt)}, then avoidance or "again" language on ${formatEntryDate(current.createdAt)}.`,
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
            title: `Same entry: you want "${want.slice(0, 40)}" and keep "${keep.slice(0, 40)}".`,
            explanation: `Both framings sit in one reflection — wanting "${want.slice(0, 50)}" while describing that you keep "${keep.slice(0, 50)}".`,
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
            title: `You wanted "${want.slice(0, 35)}"; later you keep "${keep.slice(0, 35)}".`,
            explanation: `${formatEntryDate(entry.createdAt)}: want "${want.slice(0, 55)}" · ${formatEntryDate(later.createdAt)}: keep "${keep.slice(0, 55)}"`,
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
        title: `"${theme}" reads two different ways across these entries.`,
        explanation: `${formatEntryDate(prev.createdAt)}: "${prevObs.slice(0, 90)}" · ${formatEntryDate(current.createdAt)}: "${currentObs.slice(0, 90)}"`,
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
