import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { formatRelativeDate } from "@/lib/utils";
import type { JournalEntry } from "@/types/journal";

const LOOP_RE =
  /\b(same loop|loop came back|keep coming back|again before|imagining everyone judging|standup loop)\b/i;
const ANXIOUS_RE = /\b(anxious|tighten|tense|spiral|dread|worried|pressure)\b/i;

export interface RecoveryCandidate {
  id: string;
  kind: "recovery_after_topic" | "calmer_return" | "shorter_spiral";
  text: string;
  strength: number;
  pastEntryId: string;
  entryId: string;
  pastQuote: string;
  currentQuote: string;
  pastDateLabel: string;
  currentDateLabel: string;
}

function snippet(entry: JournalEntry): string {
  const fromReflection =
    entry.reflection.exactLanguagePattern?.trim() ||
    entry.reflection.concreteObservation?.trim();
  if (fromReflection) return fromReflection.slice(0, 160);
  return entry.transcript.trim().slice(0, 160);
}

function roundAvg(values: number[]): number {
  if (values.length === 0) return 0;
  return Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 10) / 10;
}

function hasTheme(entry: JournalEntry, themeKey: string): boolean {
  return entry.reflection.recurringThemes.some((t) => t.toLowerCase() === themeKey);
}

function evidence(past: JournalEntry, current: JournalEntry) {
  return {
    pastEntryId: past.id,
    entryId: current.id,
    pastQuote: snippet(past),
    currentQuote: snippet(current),
    pastDateLabel: formatRelativeDate(past.createdAt),
    currentDateLabel: formatRelativeDate(current.createdAt),
  };
}

/** Recovery-shaped shifts after a topic or loop has repeated. */
export function detectRecoveryCandidates(
  current: JournalEntry,
  prior: JournalEntry[],
): RecoveryCandidate[] {
  const results: RecoveryCandidate[] = [];
  const currentDay = toDayKey(current.createdAt);

  for (const theme of current.reflection.recurringThemes) {
    const themeKey = theme.toLowerCase();
    const priorMatches = prior.filter((e) => hasTheme(e, themeKey));
    if (priorMatches.length < 2) continue;

    const lastPrior = priorMatches[priorMatches.length - 1];
    const gap = daysBetweenKeys(toDayKey(lastPrior.createdAt), currentDay);
    const priorAvg = roundAvg(priorMatches.map((e) => e.reflection.emotionalIntensity));
    const delta = priorAvg - current.reflection.emotionalIntensity;
    const ev = evidence(lastPrior, current);

    if (priorMatches.length >= 3 && priorAvg >= 5.5 && delta >= 1.5) {
      results.push({
        id: `recovery-topic-${themeKey}-${current.id}`,
        kind: "recovery_after_topic",
        text: "You came back with less tension.",
        strength: 66 + Math.round(delta * 4) + priorMatches.length,
        ...ev,
      });
    }

    if (gap >= 7 && delta >= 1.5) {
      results.push({
        id: `recovery-calmer-${themeKey}-${current.id}`,
        kind: "calmer_return",
        text:
          gap >= 14
            ? "There was more pressure before."
            : "You came back with less tension.",
        strength: 64 + Math.round(delta * 3) + Math.min(gap, 10),
        ...ev,
      });
    }

    const priorLoop = priorMatches.filter(
      (e) => LOOP_RE.test(e.transcript) || ANXIOUS_RE.test(e.transcript),
    );
    if (
      priorLoop.length >= 2 &&
      (LOOP_RE.test(current.transcript) || ANXIOUS_RE.test(current.transcript)) &&
      current.reflection.emotionalIntensity <
        priorLoop[priorLoop.length - 1].reflection.emotionalIntensity - 1
    ) {
      const loopPrior = priorLoop[priorLoop.length - 1];
      const loopEv = evidence(loopPrior, current);
      results.push({
        id: `recovery-spiral-${themeKey}-${current.id}`,
        kind: "shorter_spiral",
        text: "This reads differently here.",
        strength: 63 + Math.round(priorLoop.length * 2),
        ...loopEv,
      });
    }
  }

  return results;
}
