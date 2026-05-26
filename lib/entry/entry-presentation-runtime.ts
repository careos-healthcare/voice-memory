import { emptyPresentationSideEffects } from "@/lib/refinement/presentation-side-effects";
import type { RevisitExperiencePresentation } from "@/lib/refinement/revisit-experience";
import { runPresentationBuild } from "@/lib/tracking/presentation-guard";

export const EMPTY_REVISIT_EXPERIENCE: RevisitExperiencePresentation = {
  isRevisit: false,
  sources: [],
  revisitReward: null,
  thenVsNow: null,
  livingResurfacing: null,
  voiceIdentity: null,
  emotionalChapter: null,
  followupPrompt: null,
  reopenPayoffScore: null,
  followupDelayMs: 0,
  sideEffects: emptyPresentationSideEffects(),
};

/** Fail-closed presentation build — never throw through the entry route. */
export function runEntryPresentationSafe<T>(run: () => T, fallback: T): T {
  try {
    return runPresentationBuild(run);
  } catch (error) {
    if (process.env.NODE_ENV !== "production") {
      console.warn("[entry-presentation]", error);
    }
    return fallback;
  }
}
