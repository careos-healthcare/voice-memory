/** User-facing clarity copy — scanned by validate:clarity-restraint. */

export const CLARITY_PROMPT_TITLE = "Sort this out aloud";

export const CLARITY_PROMPT_BODY =
  "Record what happened, what you assumed, and what still feels unresolved.";

export const CLARITY_RECORD_CTA = "Record where this is now";

export const CLARITY_DISMISS_CTA = "Leave it for later";

export const CLARITY_CIRCLING_SECTION_TITLE = "Thoughts that kept circling";

export const CLARITY_RECORDER_PROMPTS: Record<
  import("@/types/clarity").ClarityRecorderPromptKey,
  string
> = {
  what_happened: "What happened?",
  what_assumed: "What did I assume?",
  what_avoided: "What did I want to say but avoid?",
  what_unresolved: "What still feels unresolved?",
  what_changed: "What changed since I first recorded this?",
};

export const CLARITY_AFTER_SAVE_LINES = {
  separatedHappenedFromMeaning:
    "You separated what happened from what it meant to you.",
  returnedUnresolved: "You came back to what still felt unresolved.",
  saidWhatAvoided: "You said what you avoided saying earlier.",
  changedInOwnWords: "This changed in your own words.",
} as const;

export const CLARITY_RESURFACE_LINES = {
  misunderstood: "You came back to feeling misunderstood.",
  avoidedAgain: "You mentioned avoiding this again.",
  questionReturned: "This question returned in different words.",
  similarAssumption: "You assumed something similar before.",
} as const;
