import { toDayKey } from "@/lib/dates";
import type { JournalEntry } from "@/types/journal";
import type { ContradictionMatch } from "@/types/pattern-insights";

const INTENTION_PATTERNS = [
  /\bi(?:'ll| will)\s+(\w+(?:\s+\w+){0,4})/gi,
  /\bi(?:'m| am) going to\s+(\w+(?:\s+\w+){0,4})/gi,
  /\bi need to\s+(\w+(?:\s+\w+){0,4})/gi,
  /\btomorrow i(?:'ll| will)\s+(\w+(?:\s+\w+){0,4})/gi,
];

const POSITIVE_MOODS = new Set(["hopeful", "calm", "relieved", "grounded", "steady", "content"]);
const NEGATIVE_MOODS = new Set(["anxious", "worried", "stressed", "overwhelmed", "conflicted", "frustrated"]);

const GOAL_WORDS = ["want to", "trying to", "plan to", "hope to", "goal", "intention"];
const BEHAVIOR_WORDS = ["didn't", "did not", "avoided", "skipped", "put off", "again", "still haven't"];

function normalizeTopic(text: string): string {
  return text.toLowerCase().replace(/[^\w\s]/g, " ").trim();
}

function themeOverlap(a: string[], b: string[]): string[] {
  const setB = new Set(b.map((t) => t.toLowerCase()));
  return a.filter((t) => setB.has(t.toLowerCase()));
}

function extractIntentions(text: string): string[] {
  const intentions: string[] = [];
  for (const pattern of INTENTION_PATTERNS) {
    const re = new RegExp(pattern.source, pattern.flags);
    let match: RegExpExecArray | null;
    while ((match = re.exec(text)) !== null) {
      intentions.push(normalizeTopic(match[1] ?? match[0]));
    }
  }
  return intentions;
}

function moodValence(mood: string): "positive" | "negative" | "neutral" {
  const m = mood.toLowerCase();
  if (POSITIVE_MOODS.has(m)) return "positive";
  if (NEGATIVE_MOODS.has(m)) return "negative";
  return "neutral";
}

export function detectContradictions(
  entries: JournalEntry[],
  currentEntryId: string,
): ContradictionMatch[] {
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const currentIndex = sorted.findIndex((e) => e.id === currentEntryId);
  if (currentIndex < 0) return [];

  const current = sorted[currentIndex];
  const prior = sorted.slice(0, currentIndex);
  const results: ContradictionMatch[] = [];

  for (const prev of prior.slice(-8)) {
    const sharedThemes = themeOverlap(current.reflection.recurringThemes, prev.reflection.recurringThemes);
    if (sharedThemes.length === 0) continue;

    const currentValence = moodValence(current.reflection.mood);
    const prevValence = moodValence(prev.reflection.mood);

    if (
      currentValence !== "neutral" &&
      prevValence !== "neutral" &&
      currentValence !== prevValence
    ) {
      results.push({
        id: `reversal-${prev.id}-${current.id}`,
        kind: "emotional_reversal",
        label: "Emotional reversal on a recurring theme",
        detail: `You describe "${sharedThemes[0]}" as ${prev.reflection.mood} earlier (${toDayKey(prev.createdAt)}) and ${current.reflection.mood} here — a shift in how you frame the same thread.`,
        priorEntryId: prev.id,
      });
    }
  }

  for (const prev of prior.slice(-6)) {
    const prevIntentions = extractIntentions(prev.transcript);
    const currentText = current.transcript.toLowerCase();

    for (const intention of prevIntentions) {
      if (intention.length < 4) continue;
      const failed =
        BEHAVIOR_WORDS.some((w) => currentText.includes(w)) &&
        currentText.includes(intention.split(" ")[0]);
      const repeatedIntention = extractIntentions(current.transcript).some((i) =>
        i.includes(intention.split(" ")[0]),
      );

      if (failed || (repeatedIntention && prev.id !== current.id)) {
        results.push({
          id: `intention-${prev.id}-${intention.slice(0, 12)}`,
          kind: "failed_intention",
          label: "Repeated or stalled intention",
          detail: `You mentioned "${intention}" before (${toDayKey(prev.createdAt)}). This entry circles the same intention without a clear follow-through — worth noticing as a language pattern, not a failure.`,
          priorEntryId: prev.id,
        });
        break;
      }
    }
  }

  for (const prev of prior.slice(-5)) {
    const prevGoals = GOAL_WORDS.filter((g) => prev.transcript.toLowerCase().includes(g));
    const currentBehavior = BEHAVIOR_WORDS.filter((b) =>
      current.transcript.toLowerCase().includes(b),
    );
    const shared = themeOverlap(current.reflection.recurringThemes, prev.reflection.recurringThemes);

    if (prevGoals.length > 0 && currentBehavior.length > 0 && shared.length > 0) {
      results.push({
        id: `goal-behavior-${prev.id}-${current.id}`,
        kind: "goal_behavior_tension",
        label: "Gap between stated aim and described behavior",
        detail: `Around "${shared[0]}", you named an aim earlier and describe avoidance or delay here — tension between what you say you want and what you report doing.`,
        priorEntryId: prev.id,
      });
      break;
    }
  }

  for (const prev of prior.slice(-4)) {
    const prevObs = prev.reflection.concreteObservation ?? prev.reflection.hiddenConcern;
    const currentObs = current.reflection.concreteObservation ?? current.reflection.hiddenConcern;
    const shared = themeOverlap(current.reflection.recurringThemes, prev.reflection.recurringThemes);

    if (shared.length > 0 && prevObs && currentObs && prevObs !== currentObs) {
      const prevWords = new Set(normalizeTopic(prevObs).split(/\s+/).filter((w) => w.length > 4));
      const overlap = normalizeTopic(currentObs)
        .split(/\s+/)
        .filter((w) => prevWords.has(w)).length;

      if (overlap >= 2) {
        results.push({
          id: `conflict-${prev.id}-${current.id}`,
          kind: "conflicting_statement",
          label: "You describe the same thread differently",
          detail: `On "${shared[0]}": earlier you noted "${prevObs.slice(0, 80)}…" — here "${currentObs.slice(0, 80)}…". Same topic, different framing.`,
          priorEntryId: prev.id,
        });
        break;
      }
    }
  }

  const seen = new Set<string>();
  return results.filter((r) => {
    if (seen.has(r.kind + r.label)) return false;
    seen.add(r.kind + r.label);
    return true;
  }).slice(0, 5);
}
