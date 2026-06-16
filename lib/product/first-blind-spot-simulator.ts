import { FIRST_BLIND_SPOT_SIMULATOR } from "@/lib/product/first-blind-spot-simulator-copy";
import type { JournalEntry } from "@/types/journal";

export interface FirstBlindSpotSimulatorView {
  reflectionCount: number;
  remainingCount: number;
  progressLine: string;
  headline: string;
  subheadline: string;
  categories: readonly string[];
  curiosityTitle: string;
  curiosityBullets: readonly string[];
}

export interface FirstBlindSpotExampleReview {
  disclaimer: string;
  patternHeadline: string;
  observation: string;
  possibleBelief: string;
  evidenceQuotes: Array<{ dateLabel: string; quote: string }>;
  possibleCost: string;
  experimentSmallThing: string;
  experimentTryNextTime: string;
  whatChanged: string[];
}

/** Show only at exactly 3 or 4 completed reflections — never before, never at 5+. */
export function shouldShowFirstBlindSpotSimulator(reflectionCount: number): boolean {
  return reflectionCount === 3 || reflectionCount === 4;
}

export function countEligibleForSimulator(entries: JournalEntry[]): number {
  return entries.filter((e) => e.reflectionPending !== true).length;
}

export function buildFirstBlindSpotSimulatorView(
  reflectionCount: number,
): FirstBlindSpotSimulatorView | null {
  if (!shouldShowFirstBlindSpotSimulator(reflectionCount)) return null;

  const remainingCount = 5 - reflectionCount;
  const progressLine =
    reflectionCount === 3
      ? FIRST_BLIND_SPOT_SIMULATOR.progressAt3
      : FIRST_BLIND_SPOT_SIMULATOR.progressAt4;

  return {
    reflectionCount,
    remainingCount,
    progressLine,
    headline: FIRST_BLIND_SPOT_SIMULATOR.headline,
    subheadline: FIRST_BLIND_SPOT_SIMULATOR.subheadline,
    categories: FIRST_BLIND_SPOT_SIMULATOR.categories,
    curiosityTitle: FIRST_BLIND_SPOT_SIMULATOR.curiosityTitle,
    curiosityBullets: FIRST_BLIND_SPOT_SIMULATOR.curiosityBullets,
  };
}

/** Static fictional example — demonstrates the full review system, not user data. */
export function buildFirstBlindSpotExampleReview(): FirstBlindSpotExampleReview {
  return {
    disclaimer: FIRST_BLIND_SPOT_SIMULATOR.modalDisclaimer,
    patternHeadline: "One possible pattern: the same concern keeps returning",
    observation:
      "Across several dated reflections, you may keep circling a decision without naming the fork — example only.",
    possibleBelief:
      "Your words might suggest waiting feels safer than choosing — this is illustrative, not about you.",
    evidenceQuotes: [
      {
        dateLabel: "Jan 12",
        quote: "I keep saying I will start Monday but I never do.",
      },
      {
        dateLabel: "Jan 28",
        quote: "Maybe I will eventually tell them — I don't know.",
      },
      {
        dateLabel: "Feb 4",
        quote: "I should have spoken up but I keep waiting.",
      },
    ],
    possibleCost:
      "This may cost energy — repeating the same frame without testing it can keep you circling.",
    experimentSmallThing:
      "Name the avoided decision in one sentence — not a plan yet, just the fork you keep circling.",
    experimentTryNextTime:
      "Try this next time you feel the stall: say the decision out loud once, then stop.",
    whatChanged: [
      "New reflections may be sharpening this thread.",
      "Evidence strength may have moved toward medium.",
    ],
  };
}
