import type { EmotionalShiftKind } from "@/types/open-loop";
import type { JournalEntry } from "@/types/journal";

const UNCERTAIN_MOOD_RE = /\b(uncertain|unsure|anxious|worried|confused|stuck)\b/i;
const SOFT_MOOD_RE = /\b(calm|quiet|peace|steady|relieved|lighter)\b/i;
const HEAVY_MOOD_RE = /\b(heavy|low|sad|tense|stressed|overwhelm|drained)\b/i;

export interface ShiftEvidence {
  shift?: EmotionalShiftKind;
  confidence: "low" | "high";
}

function entryIntensity(entry: JournalEntry): number {
  return entry.reflection.emotionalIntensity ?? 5;
}

function daysBetween(a: string, b: string): number {
  const ms = Math.abs(new Date(b).getTime() - new Date(a).getTime());
  return Math.round(ms / (1000 * 60 * 60 * 24));
}

/** Restrained shift — only when archive evidence is strong. */
export function detectEmotionalShift(
  entries: JournalEntry[],
  anchorPhrases: string[],
): ShiftEvidence {
  if (entries.length < 2) {
    return { confidence: "low" };
  }

  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  const gapDays = daysBetween(first.createdAt, last.createdAt);

  const intensities = sorted.map(entryIntensity);
  const firstIntensity = intensities[0];
  const lastIntensity = intensities[intensities.length - 1];
  const delta = lastIntensity - firstIntensity;

  if (delta >= 2 && lastIntensity >= 6) {
    return { shift: "heavier", confidence: "high" };
  }
  if (delta <= -2 && lastIntensity <= 5) {
    return { shift: "softer", confidence: "high" };
  }

  if (gapDays >= 7) {
    const earlyText = [first.transcript, ...anchorPhrases].join(" ").toLowerCase();
    const lateText = [last.transcript, ...anchorPhrases].join(" ").toLowerCase();
    const avoidedEarly = /\b(avoid(?:ing|ed|s)?|put off|not yet|can't face)\b/i.test(earlyText);
    const revisitedLate = /\b(came back|returned|mentioned|still|again)\b/i.test(lateText);
    if (avoidedEarly && revisitedLate) {
      return { shift: "avoided_then_revisited", confidence: "high" };
    }
  }

  const uncertainHits = sorted.filter((entry) =>
    UNCERTAIN_MOOD_RE.test(entry.reflection.mood ?? ""),
  ).length;
  if (uncertainHits >= 2 && uncertainHits / sorted.length >= 0.5) {
    return { shift: "uncertain", confidence: "high" };
  }

  const softHits = sorted.filter((entry) => SOFT_MOOD_RE.test(entry.reflection.mood ?? "")).length;
  const heavyHits = sorted.filter((entry) => HEAVY_MOOD_RE.test(entry.reflection.mood ?? "")).length;
  if (softHits >= 2 && heavyHits === 0 && lastIntensity <= 5) {
    return { shift: "softer", confidence: "high" };
  }
  if (heavyHits >= 2 && lastIntensity >= 6) {
    return { shift: "heavier", confidence: "high" };
  }

  if (sorted.length >= 3 && Math.abs(delta) <= 1) {
    return { shift: "unresolved", confidence: "high" };
  }

  return { confidence: "low" };
}

export function moodLabelIfConfident(entry: JournalEntry): string | undefined {
  const mood = entry.reflection.mood?.trim();
  if (!mood || mood.length < 3) return undefined;
  if (/^(quiet|neutral|mixed|unknown|fine|okay)$/i.test(mood)) return undefined;
  if (mood.length > 24) return undefined;
  return mood.charAt(0).toUpperCase() + mood.slice(1);
}
