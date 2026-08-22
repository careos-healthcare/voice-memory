/**
 * Grief / Loss thematic lens — cyclical patterns, non-linear movement,
 * no progress or healing pressure.
 */

export const GRIEF_LOSS_LENS_ID = "griefLoss" as const;

export const GRIEF_LOSS_LISTEN_TARGETS = [
  "cyclical patterns (time of day, day of week, anniversaries, seasons)",
  "non-linear emotional movement (okay in mornings, harder Sunday evenings — cite both)",
  "avoidance and sudden reversals in meaning-making language",
  "relationship and routine changes after the loss without labeling stages",
] as const;

export const GRIEF_LOSS_FORBIDDEN_OUTPUT = [
  "progress, healing, closure, or \"moving forward\" framing",
  "stages-of-grief or therapeutic directives",
  "reassurance not grounded in cited ledger entries",
] as const;

export const GRIEF_LOSS_SYSTEM_PROMPT_INJECTION = [
  "GRIEF / LOSS LENS — cyclical mirror only:",
  ...GRIEF_LOSS_LISTEN_TARGETS.map((target, index) => `${index + 1}. ${target}`),
  "STRICT PROHIBITIONS:",
  ...GRIEF_LOSS_FORBIDDEN_OUTPUT.map((rule) => `- ${rule}`),
  "Describe movement across dates without implying linear improvement.",
  "Quote the user's phrasing for when things feel lighter vs heavier.",
  "If evidence is thin, say so plainly — never fill gaps with comfort language.",
].join("\n");

export const GRIEF_LOSS_COLD_START_PROMPTS = [
  "What time of day or day of week feels hardest lately — and when feels lighter?",
  "What routine changed after the loss that still catches you off guard?",
  "What phrase do you use when you feel okay — and what replaces it later?",
  "What anniversary, place, or object keeps returning in your entries?",
] as const;

export const GRIEF_LOSS_COMPARISON_SYSTEM_ADDENDUM = `GRIEF/LOSS COMPARISON — compare 2-week and 1-month intervals:
- Identify cyclical patterns (e.g., okay in mornings, harder Sunday evenings) using exact quotes and dates.
- Show non-linear movement — do not imply progress, healing, closure, or stages of grief.
- When the user feels stuck, prove baseline shifts across intervals with cited evidence only.
- Forbidden comparison framing: "moving forward", "healing journey", "getting better", "making progress".`;

export function buildGriefLossColdStartAddendum(): string {
  return `GRIEF/LOSS COLD START — capture time-of-day, day-of-week, and anniversary language verbatim.
Never imply linear healing; cite cyclical movement only.`;
}
