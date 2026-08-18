import type { JournalEntry } from "@/types/journal";
import type {
  ContradictionMatch,
  EntryPatternInsights,
  PatternDebugScore,
  RepeatedPhraseMatch,
} from "@/types/pattern-insights";

import { detectAvoidanceSignals } from "./avoidance-detection";
import { detectContradictions } from "./contradiction-engine";
import { detectEmotionalEvolution } from "./emotional-evolution";
import { detectRepeatedPhrases } from "./phrase-memory";

const ADVICE_PATTERNS = [
  /\byou should\b/i,
  /\bconsider trying\b/i,
  /\btry to\b/i,
  /\bbe kind to yourself\b/i,
  /\bhold space\b/i,
];

function buildObservations(
  entry: JournalEntry,
  contradictions: ContradictionMatch[],
  phrases: RepeatedPhraseMatch[],
  avoidanceCount: number,
): string[] {
  const observations: string[] = [];

  if (entry.reflection.patternObservations?.length) {
    observations.push(...entry.reflection.patternObservations);
  }

  if (entry.reflection.repeatedSignal) {
    const signal = entry.reflection.repeatedSignal.trim();
    if (signal && !signal.toLowerCase().startsWith("no clear repeat")) {
      observations.push(
        signal.startsWith("You ") ? signal : `You repeatedly ${signal.charAt(0).toLowerCase()}${signal.slice(1)}`,
      );
    }
  }

  for (const phrase of phrases.slice(0, 2)) {
    observations.push(
      `You tend to use "${phrase.phrase}" — ${phrase.count} times across ${phrase.entryCount} entries.`,
    );
  }

  for (const c of contradictions.slice(0, 2)) {
    observations.push(c.detail);
  }

  if (avoidanceCount > 0) {
    observations.push(
      "You describe pressure or topics indirectly in this entry — hedging or unnamed references show up in your language.",
    );
  }

  if (entry.reflection.exactLanguagePattern) {
    observations.push(
      `You describe it as: "${entry.reflection.exactLanguagePattern.slice(0, 120)}"`,
    );
  }

  return [...new Set(observations.map((o) => o.trim()).filter(Boolean))].slice(0, 6);
}

function buildRecurringPatterns(entry: JournalEntry, entries: JournalEntry[]): string[] {
  const patterns: string[] = [];
  const themeCounts = new Map<string, number>();

  for (const e of entries) {
    for (const theme of e.reflection.recurringThemes) {
      const key = theme.toLowerCase();
      themeCounts.set(key, (themeCounts.get(key) ?? 0) + 1);
    }
  }

  for (const theme of entry.reflection.recurringThemes) {
    const count = themeCounts.get(theme.toLowerCase()) ?? 0;
    if (count >= 2) {
      patterns.push(`"${theme}" recurs across ${count} entries in your archive.`);
    }
  }

  if (entry.reflection.concreteObservation) {
    patterns.push(entry.reflection.concreteObservation);
  }

  return patterns.slice(0, 5);
}

export function scorePatternSpecificity(
  entry: JournalEntry,
  entries: JournalEntry[],
  contradictions: ContradictionMatch[],
  phrases: RepeatedPhraseMatch[],
): PatternDebugScore {
  const reasons: string[] = [];
  let exactPhraseReferences = 0;
  let recurrenceCount = 0;
  let crossEntryGrounding = 0;
  const contradictionEvidence = contradictions.length;

  const transcript = entry.transcript.toLowerCase();

  if (entry.reflection.exactLanguagePattern) {
    const quote = entry.reflection.exactLanguagePattern.toLowerCase().slice(0, 40);
    if (quote.length > 8 && transcript.includes(quote.slice(0, 20))) {
      exactPhraseReferences += 2;
      reasons.push("Grounded in an exact phrase from this transcript.");
    } else {
      exactPhraseReferences += 1;
      reasons.push("Uses paraphrased language from this entry.");
    }
  }

  recurrenceCount += phrases.filter((p) => p.entryCount >= 2).length;
  if (recurrenceCount > 0) {
    reasons.push(`${recurrenceCount} repeated phrase(s) found across entries.`);
  }

  const priorWithSharedTheme = entries.filter(
    (e) =>
      e.id !== entry.id &&
      e.reflection.recurringThemes.some((t) =>
        entry.reflection.recurringThemes.some(
          (ct) => ct.toLowerCase() === t.toLowerCase(),
        ),
      ),
  ).length;

  crossEntryGrounding = Math.min(5, priorWithSharedTheme + contradictions.length);
  if (crossEntryGrounding > 0) {
    reasons.push(`Cross-entry grounding from ${priorWithSharedTheme} prior reflection(s) on shared themes.`);
  }

  if (contradictionEvidence > 0) {
    reasons.push(`${contradictionEvidence} contradiction or reversal signal(s) detected.`);
  }

  const adviceFree =
    !ADVICE_PATTERNS.some((p) =>
      [
        entry.reflection.recommendation,
        entry.reflection.nextSmallAction ?? "",
        ...(entry.reflection.patternObservations ?? []),
      ].some((t) => p.test(t)),
    );

  if (adviceFree) {
    reasons.push("Output avoids generic advice phrasing.");
  }

  const total =
    exactPhraseReferences * 15 +
    recurrenceCount * 12 +
    crossEntryGrounding * 10 +
    contradictionEvidence * 8;

  return {
    exactPhraseReferences,
    recurrenceCount,
    crossEntryGrounding,
    contradictionEvidence,
    total: Math.min(100, total),
    specificityReasons: reasons,
  };
}

export function buildEntryPatternInsights(
  entry: JournalEntry,
  allEntries: JournalEntry[],
): EntryPatternInsights {
  const contradictions = detectContradictions(allEntries, entry.id);
  const repeatedPhrases = detectRepeatedPhrases(allEntries, entry.id);
  const avoidanceSignals = detectAvoidanceSignals(entry, allEntries);
  const emotionalEvolution = detectEmotionalEvolution(allEntries, entry.id);
  const recurringPatterns = buildRecurringPatterns(entry, allEntries);
  const observations = buildObservations(
    entry,
    contradictions,
    repeatedPhrases,
    avoidanceSignals.length,
  );
  const debug = scorePatternSpecificity(
    entry,
    allEntries,
    contradictions,
    repeatedPhrases,
  );

  return {
    entryId: entry.id,
    recurringPatterns,
    observations,
    contradictions,
    repeatedPhrases,
    avoidanceSignals,
    emotionalEvolution,
    debug,
  };
}

export function buildAllEntryDebugSummaries(
  entries: JournalEntry[],
): Array<{ entryId: string; date: string; score: number; topReason: string }> {
  return entries.map((entry) => {
    const insights = buildEntryPatternInsights(entry, entries);
    return {
      entryId: entry.id,
      date: entry.createdAt,
      score: insights.debug.total,
      topReason: insights.debug.specificityReasons[0] ?? "No specificity signals",
    };
  });
}
