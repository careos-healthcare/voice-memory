import { trackLocalEvent } from "@/lib/local-analytics";
import { isSideEffectBlocked } from "@/lib/tracking/presentation-guard";
import { withTrackingGuard } from "@/lib/tracking/sync-guard";

export const CLARITY_EVENTS = {
  promptShown: "clarity_prompt_shown",
  recordClicked: "clarity_record_clicked",
  followupSaved: "clarity_followup_saved",
  thoughtPatternResurfaced: "thought_pattern_resurfaced",
  reflectionAfterPrompt: "reflection_after_clarity_prompt",
  abandoned: "clarity_abandoned_after_prompt",
} as const;

export type ClarityEventName = (typeof CLARITY_EVENTS)[keyof typeof CLARITY_EVENTS];

export function trackClarityEvent(
  name: ClarityEventName,
  meta?: Record<string, string>,
): void {
  if (typeof window === "undefined" || isSideEffectBlocked()) return;
  withTrackingGuard(() => {
    trackLocalEvent(name, meta);
  });
}
