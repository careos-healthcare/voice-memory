/**
 * New Parent thematic lens — capacity shifts, identity contradictions,
 * and temporal comparison guardrails.
 */

export const NEW_PARENT_LENS_ID = "newParent" as const;

export const NEW_PARENT_LISTEN_TARGETS = [
  "fundamental capacity shifts (patience, exhaustion thresholds, tolerance for noise or interruption)",
  "relationship dynamics changing (partner load-sharing, who handles nights, resentment vs gratitude language)",
  "pre-transition vs post-transition identity contradictions (who you said you were vs who entries show now)",
  "sleep fragmentation and recovery language tied to specific dates and roles",
] as const;

export const NEW_PARENT_FORBIDDEN_OUTPUT = [
  "parenting advice or prescriptive routines",
  "clinical labels for postpartum or mood states",
  "generic \"new parent\" platitudes without citing a specific entry",
] as const;

export const NEW_PARENT_SYSTEM_PROMPT_INJECTION = [
  "NEW PARENT LENS — temporal identity comparison:",
  ...NEW_PARENT_LISTEN_TARGETS.map((target, index) => `${index + 1}. ${target}`),
  "STRICT FOCUS:",
  "- Compare pre-transition entries with post-transition entries when both exist — prefer contradiction kind.",
  "- Quote dates, baby age markers, partner names, and night/wake timestamps from the ledger.",
  "- Track whether stated capacities (patience, stamina, emotional bandwidth) rise or fall across weeks.",
  "PROHIBITIONS:",
  ...NEW_PARENT_FORBIDDEN_OUTPUT.map((rule) => `- ${rule}`),
].join("\n");

export const NEW_PARENT_COLD_START_PROMPTS = [
  "Who were you on a typical morning before this transition — and who shows up now?",
  "What is the smallest thing that drains your patience faster than it used to?",
  "When did your partner last carry a load you used to handle alone?",
  "What identity word keeps colliding with how exhausted you actually feel?",
] as const;

export const NEW_PARENT_COMPARISON_SYSTEM_ADDENDUM = `NEW PARENT COMPARISON — compare 2-week and 1-month intervals:
- Surface shifts in patience, exhaustion thresholds, and partner/load-sharing dynamics.
- Isolate pre-transition identity language vs post-transition identity language; cite both with dates.
- When the user feels stuck, show baseline movement across intervals using their exact words.
- Never offer parenting advice; evidence citation only.`;

export function buildNewParentColdStartAddendum(): string {
  return `NEW PARENT COLD START — capture pre/post identity language, sleep fragmentation, and partner roles verbatim.
Prefer contradiction when stated capacities conflict with described behavior in the same week.`;
}
