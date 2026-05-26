import type { CallbackLearningEventName } from "@/types/callback-learning";

/** Callback learning event names — no heavy imports (avoids circular init). */
export const CALLBACK_LEARNING_EVENTS = {
  shown: "callback_shown",
  ignored: "callback_ignored",
  opened: "callback_opened",
  reread: "callback_reread",
  saved: "callback_saved",
  shared: "callback_shared",
  dismissed: "callback_dismissed",
  reflectionAfter: "reflection_after_callback",
  returnAfter: "return_after_callback",
} as const satisfies Record<string, CallbackLearningEventName>;
