/** Surfaces that must not appear before the mic is engaged. */

const HIDDEN_BEFORE_SPEECH = new Set([
  "circling_thoughts",
  "open_loop_card",
  "open_loop_return_prompt",
  "open_loop_entry_continuity",
  "atmosphere_picker",
  "resurfacing_stack",
  "primary_callback_note",
  "continuation_notes",
  "followup_prompt",
  "contextual_reminders",
  "habit_loop",
  "timeline_block",
  "thought_pattern",
  "why_this_returned",
  "explanation_text",
  "archive_gravity",
  "living_resurfacing",
  "revisit_rhythm",
  "activation_onboarding",
  "calm_comprehension",
  "density_prompt",
]);

const ALLOWED_PRE_SPEECH = new Set(["zero_state_line", "return_quote_line", "recorder"]);

export function shouldHideBeforeSpeaking(surfaceName: string): boolean {
  if (ALLOWED_PRE_SPEECH.has(surfaceName)) return false;
  return HIDDEN_BEFORE_SPEECH.has(surfaceName);
}

export function capPreSpeechSurfaces(surfaceNames: string[]): string[] {
  const allowed = surfaceNames.filter((name) => !shouldHideBeforeSpeaking(name));
  if (allowed.length <= 1) return allowed.slice(0, 1);
  const priority = ["return_quote_line", "zero_state_line"];
  for (const key of priority) {
    if (allowed.includes(key)) return [key];
  }
  return [allowed[0]];
}

export function countPreSpeechContinuitySurfaces(surfaceNames: string[]): number {
  return surfaceNames.filter(
    (name) => !shouldHideBeforeSpeaking(name) && name !== "recorder",
  ).length;
}

/** Validation helper — mic must be the only interactive surface besides one line. */
export function assertMicCentralityBeforeSpeech(surfaceCount: number): boolean {
  return surfaceCount <= 1;
}

export const MAX_PRE_SPEECH_LINES = 1;
