import { trackLocalEvent } from "@/lib/local-analytics";
import type { SilenceIntelligenceState } from "@/types/silence-intelligence";

/** Events: silence_state_entered, silence_state_exited, return_after_silence, reflection_during_silence */
export {
  RETURN_AFTER_SILENCE,
  trackReturnAfterSilence,
} from "@/lib/retention/return-triggers";

export const SILENCE_STATE_ENTERED = "silence_state_entered";
export const SILENCE_STATE_EXITED = "silence_state_exited";
export const REFLECTION_DURING_SILENCE = "reflection_during_silence";

export function trackSilenceStateEntered(state: SilenceIntelligenceState, score: number): void {
  trackLocalEvent(SILENCE_STATE_ENTERED, { state, score: String(score) });
}

export function trackSilenceStateExited(
  from: SilenceIntelligenceState,
  to: SilenceIntelligenceState,
): void {
  trackLocalEvent(SILENCE_STATE_EXITED, { from, to });
}

export function trackReflectionDuringSilence(state: SilenceIntelligenceState): void {
  trackLocalEvent(REFLECTION_DURING_SILENCE, { state });
}
