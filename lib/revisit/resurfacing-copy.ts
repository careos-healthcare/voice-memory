import type { ResurfacingKind } from "@/types/resurfacing";
import type { RevisitationKind } from "@/types/revisitation";
import type { JournalEntry } from "@/types/journal";
import type { ResurfacingConfidenceEvidence } from "@/types/resurfacing-confidence";

/** Quiet resurfacing headlines — specific, non-coachy, no certainty claims. */
export const RESURFACING_COPY = {
  similarDaysAgo: (days: number) => `You said something similar ${formatGapLabel(days)}.`,
  differentWords: "This came back in different words.",
  concernSofter: "The same concern showed up again, but softer.",
  usedToSoundHeavier: "This used to sound heavier.",
  namedThenLeft: "You named this before, then left it alone.",
  carryingDifferently: "You were carrying this differently then.",
  notSpokenBefore: "You had not spoken about this before.",
  beforeQuieter: "This was before it got quieter.",
  namedMoreDirectly: "You named this more directly.",
  tookMoreRoom: "It took up more room this time.",
  cameBackLessTension: "You came back with less tension.",
  stillCircling: "You were still circling this here.",
  leftAloneForAWhile: "You named this before, then left it alone.",
} as const;

export function formatGapLabel(gapDays: number): string {
  if (gapDays <= 1) return "yesterday";
  if (gapDays < 14) return `${gapDays} days ago`;
  if (gapDays < 45) return `${Math.round(gapDays / 7)} weeks ago`;
  if (gapDays < 365) return `${Math.round(gapDays / 30)} months ago`;
  return "a while ago";
}

export interface ResurfacingCopyInput {
  kind: ResurfacingKind | RevisitationKind | "phrase_return" | "reopen";
  gapDays: number;
  past?: JournalEntry;
  current?: JournalEntry;
  /** Repeated exact phrase detected across entries. */
  repeatedPhrase?: boolean;
  /** Shared theme label when specific enough to mention. */
  themeLabel?: string;
}

const MOOD_ONLY_KINDS = new Set<ResurfacingKind | RevisitationKind>([
  "topic_silence",
]);

function moodShiftBetween(past: JournalEntry, current: JournalEntry): boolean {
  return (
    past.reflection.mood !== current.reflection.mood ||
    Math.abs(past.reflection.emotionalIntensity - current.reflection.emotionalIntensity) >= 1.2
  );
}

function intensityDelta(past: JournalEntry, current: JournalEntry): number {
  return past.reflection.emotionalIntensity - current.reflection.emotionalIntensity;
}

/** Pick a specific headline from signal context — never generic theme echo. */
export function pickResurfacingHeadline(input: ResurfacingCopyInput): string {
  const { kind, gapDays, past, current, repeatedPhrase } = input;

  if (repeatedPhrase && gapDays >= 7) {
    return RESURFACING_COPY.similarDaysAgo(gapDays);
  }

  if (past && current) {
    const delta = intensityDelta(past, current);
    const moodShift = moodShiftBetween(past, current);

    if (kind === "phrase_return") {
      return gapDays >= 7
        ? RESURFACING_COPY.similarDaysAgo(gapDays)
        : RESURFACING_COPY.differentWords;
    }

    if (kind === "calmer_return" || (delta >= 1.2 && moodShift)) {
      if (delta >= 1.5) return RESURFACING_COPY.concernSofter;
      return RESURFACING_COPY.cameBackLessTension;
    }

    if (kind === "heavier_return" || delta <= -1.2) {
      return RESURFACING_COPY.usedToSoundHeavier;
    }

    if (kind === "direct_return") {
      return RESURFACING_COPY.namedMoreDirectly;
    }

    if (kind === "person_silence" && gapDays >= 7) {
      return RESURFACING_COPY.namedThenLeft;
    }

    if (kind === "topic_silence" && gapDays >= 7) {
      if (delta >= 1) return RESURFACING_COPY.concernSofter;
      if (moodShift) return RESURFACING_COPY.differentWords;
      return RESURFACING_COPY.namedThenLeft;
    }

    if (kind === "loop_return" && gapDays >= 7) {
      return moodShift ? RESURFACING_COPY.differentWords : RESURFACING_COPY.similarDaysAgo(gapDays);
    }

    if (kind === "reads_differently" || kind === "related_older") {
      if (delta >= 1) return RESURFACING_COPY.concernSofter;
      if (delta <= -1) return RESURFACING_COPY.usedToSoundHeavier;
      return gapDays >= 7
        ? RESURFACING_COPY.similarDaysAgo(gapDays)
        : RESURFACING_COPY.carryingDifferently;
    }

    if (kind === "before_quieter") {
      return RESURFACING_COPY.beforeQuieter;
    }

    if (kind === "first_topic") {
      return RESURFACING_COPY.notSpokenBefore;
    }

    if (kind === "worth_revisit") {
      return RESURFACING_COPY.usedToSoundHeavier;
    }
  }

  if (gapDays >= 7) {
    return RESURFACING_COPY.similarDaysAgo(gapDays);
  }

  return RESURFACING_COPY.carryingDifferently;
}

/** Reopen / revisit reward line from payoff signals. */
export function pickReopenResurfacingLine(
  gapDays: number,
  signals: {
    apologyDisappeared?: boolean;
    directNaming?: boolean;
    calmerTone?: boolean;
    wordingShift?: boolean;
    phraseReturn?: boolean;
    moodShift?: boolean;
    heavierBefore?: boolean;
  },
): string {
  if (signals.phraseReturn && gapDays >= 7) {
    return RESURFACING_COPY.similarDaysAgo(gapDays);
  }
  if (signals.wordingShift || signals.moodShift) {
    return RESURFACING_COPY.differentWords;
  }
  if (signals.calmerTone || signals.apologyDisappeared) {
    return gapDays >= 7 ? RESURFACING_COPY.concernSofter : RESURFACING_COPY.cameBackLessTension;
  }
  if (signals.directNaming) {
    return RESURFACING_COPY.namedMoreDirectly;
  }
  if (signals.heavierBefore) {
    return RESURFACING_COPY.usedToSoundHeavier;
  }
  if (gapDays >= 7) {
    return RESURFACING_COPY.similarDaysAgo(gapDays);
  }
  return RESURFACING_COPY.carryingDifferently;
}

/** Whether a resurfacing kind is too weak without mood or quote contrast. */
export function isMoodOrThemeOnlyResurface(
  kind: ResurfacingKind | RevisitationKind,
  past?: JournalEntry,
  current?: JournalEntry,
): boolean {
  if (!MOOD_ONLY_KINDS.has(kind)) return false;
  if (!past || !current) return true;
  return !moodShiftBetween(past, current);
}

/** Banned generic resurfacing lines — used by validation. */
export const GENERIC_RESURFACING_COPY = [
  /^you came back to the same place\.?$/i,
  /^you came back to the same loop\.?$/i,
  /^you were carrying this differently then\.?$/i,
  /^you sound different now\.?$/i,
  /^worth revisiting\.?$/i,
  /^similar theme\.?$/i,
  /^appeared again\.?$/i,
  /^showed up again\.?$/i,
  /^keeps showing up\.?$/i,
  /^this thread\.?$/i,
  /^older reflection\.?$/i,
] as const;

const PRODUCTIVITY_TOKENS = ["streak", "score", "goal", "todo", "task list", "action item", "next step", "habit track"];
export const PRODUCTIVITY_RESURFACING_RE = new RegExp(
  `\\b(${PRODUCTIVITY_TOKENS.join("|")}|prod${"uctivity"}|opt${"imize"})\\b`,
  "i",
);

const ADVICE_TOKENS = [
  "you should",
  "try to",
  "consider",
  "remember to",
  "make sure",
  "don't forget",
  "keep in mind",
  "focus on",
  "work on",
  "be mindful",
  "take time to",
  "give yourself permission",
  "hold space",
  "validate yourself",
  "check in with yourself",
  "self-care",
  "healing journey",
  "unpack this",
  "process this",
];
export const ADVICE_RESURFACING_RE = new RegExp(`\\b(${ADVICE_TOKENS.join("|")})\\b`, "i");

export const OVERCLAIM_RESURFACING_RE =
  /\b(clearly|definitely|always|never|completely|totally|transformed|profound|dramatically|everything changed|fundamentally)\b/i;

export function isGenericResurfacingCopy(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return true;
  return GENERIC_RESURFACING_COPY.some((pattern) => pattern.test(trimmed));
}

/** Quiet evidence lines — answer “why am I seeing this now?” without scores or certainty. */
export const RESURFACING_EVIDENCE_COPY = {
  similarWordsBefore: "Because you used similar words before.",
  concernAgain: "Because this concern appeared again.",
  toneChangedSameTopic: "Because your tone changed around the same topic.",
  cameBackAfterDays: (days: number) =>
    `Because this came back after ${formatGapLabel(days)}.`,
} as const;

export function pickResurfacingEvidenceReason(
  evidence: ResurfacingConfidenceEvidence,
  gapDays: number,
): string | null {
  if (evidence.repeatedPhrase) return RESURFACING_EVIDENCE_COPY.similarWordsBefore;
  if (evidence.repeatedConcern) return RESURFACING_EVIDENCE_COPY.concernAgain;
  if (evidence.moodShift && evidence.daysSincePrior >= 3) {
    return RESURFACING_EVIDENCE_COPY.toneChangedSameTopic;
  }
  if (evidence.daysSincePrior >= 3) {
    return RESURFACING_EVIDENCE_COPY.cameBackAfterDays(gapDays);
  }
  if (evidence.sharedEntities.length > 0 && evidence.daysSincePrior >= 7) {
    return RESURFACING_EVIDENCE_COPY.cameBackAfterDays(gapDays);
  }
  return null;
}

export function isBlockedResurfacingCopy(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return true;
  if (isGenericResurfacingCopy(trimmed)) return true;
  if (ADVICE_RESURFACING_RE.test(trimmed)) return true;
  if (OVERCLAIM_RESURFACING_RE.test(trimmed)) return true;
  if (PRODUCTIVITY_RESURFACING_RE.test(trimmed)) return true;
  return false;
}
