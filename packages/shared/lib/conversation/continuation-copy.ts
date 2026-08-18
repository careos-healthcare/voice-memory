/** Copy strings only — keep free of imports to avoid SSR init cycles. */

export const CONTINUATION_COPY = {
  stoppedHere: "You stopped here.",
  moreToSay: "There may be more to say now.",
  neverFinished: "You never finished this thought.",
  cameBackNotFully: "You came back, but not fully.",
  sayBackToSelf: "What would you say back to this version of you?",
} as const;
