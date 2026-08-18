/**
 * Career Transition thematic lens — system prompt injection, cold-start
 * onboarding prompts, and genericness QA fixtures.
 *
 * Does not alter ArchiveInsightKind taxonomy; adjusts situational reading
 * of fact_ledger entries only.
 */

export const CAREER_TRANSITION_LENS_ID = "careerTransition" as const;

/** Active listening targets for fact_ledger evaluation. */
export const CAREER_TRANSITION_LISTEN_TARGETS = [
  "professional identity shifts (title, team, industry, founder vs employee)",
  "skill-transfer beliefs (what transfers, what feels obsolete, imposter vs mastery)",
  "risk-tolerance contradictions (stated safety vs leap language in the same week)",
  "changing definitions of success (money, impact, autonomy, prestige, time)",
] as const;

export const CAREER_TRANSITION_SYSTEM_PROMPT_INJECTION = [
  "CAREER TRANSITION LENS — listen actively for:",
  ...CAREER_TRANSITION_LISTEN_TARGETS.map((target, index) => `${index + 1}. ${target}`),
  "Quote job titles, company or team names, project codenames, and calendar dates from entries.",
  "Prefer contradiction and beliefChange kinds when risk talk conflicts with action.",
  "Never output generic career-coaching platitudes without citing a specific workplace situation from the ledger.",
].join("\n");

/** Cold-start onboarding — seeds fact_ledger with transition-specific evidence. */
export const CAREER_TRANSITION_COLD_START_PROMPTS = [
  "What was the tipping point that made you decide to make this change?",
  "What part of your old role do you refuse to carry forward?",
  "What skill from your last job do you believe transfers — and what feels obsolete?",
  "When did your definition of success last change, and what triggered it?",
  "What risk are you taking now that you would not have taken a year ago?",
  "Who at work changed how you see this transition?",
] as const;

export const CAREER_TRANSITION_PRIMARY_COLD_START_PROMPT =
  CAREER_TRANSITION_COLD_START_PROMPTS[0];

export const CAREER_TRANSITION_COLD_START_SYSTEM_ADDENDUM = `CAREER TRANSITION COLD START — prioritize ledger rows that name employers, teams, titles, projects, offers, or deadlines.
Surface professional identity shifts and risk-tolerance contradictions across imported history.
Reject insights that could apply to any generic "job change" without citing a specific workplace situation.`;

export interface CareerTransitionQaSeedEntry {
  entryId: string;
  createdAt: string;
  rawText: string;
}

/** Workplace-specific mock archive for career-transition genericness QA. */
export const CAREER_TRANSITION_QA_SEED_ENTRIES: readonly CareerTransitionQaSeedEntry[] =
  [
    {
      entryId: "qa-meridian-feb12-2026",
      createdAt: "2026-02-12T09:20:00.000Z",
      rawText:
        "On February 12 I told Dana at Meridian Labs I was leaving the platform team after the reorg stripped my staff engineer scope on Project Harbor.",
    },
    {
      entryId: "qa-dana-mar03-2026",
      createdAt: "2026-03-03T16:45:00.000Z",
      rawText:
        "March 3 — Dana asked whether my Rust toolchain work transfers to Meridian's fintech pivot or dies with the old org chart.",
    },
    {
      entryId: "qa-harbor-apr08-2026",
      createdAt: "2026-04-08T08:10:00.000Z",
      rawText:
        "April 8: Harbor Analytics offered me a lead role, but I still say I want stability while rehearsing a resignation speech to Dana.",
    },
    {
      entryId: "qa-success-apr22-2026",
      createdAt: "2026-04-22T19:30:00.000Z",
      rawText:
        "Success used to mean staff engineer at Meridian Labs; now I keep measuring it by whether the fintech pivot lets me keep the Harbor codebase.",
    },
  ] as const;

export const CAREER_TRANSITION_QA_REQUIRED_ANCHORS = [
  "Meridian Labs",
  "Dana",
  "platform team",
  "staff engineer",
  "fintech pivot",
  "Harbor Analytics",
  "Rust",
] as const;

export const CAREER_TRANSITION_QA_MIN_ANCHOR_MATCHES = 2;

export const CAREER_TRANSITION_QA_QUERY_TRANSCRIPT =
  "I keep replaying my conversation with Dana about whether my Rust work at Meridian Labs transfers to the fintech pivot or dies when I leave the platform team before the Harbor Analytics offer deadline.";

/** Platitudes QA must reject when unanchored to workplace specifics. */
export const CAREER_TRANSITION_PLATITUDE_PATTERNS: readonly RegExp[] = [
  /\byou(?:'re| are) facing challenges\b/i,
  /\bcareer transition is\b/i,
  /\bprofessional growth journey\b/i,
  /\bembrace (?:this )?change\b/i,
  /\bstep outside your comfort zone\b/i,
  /\bnavigating change\b/i,
  /\btime of transition\b/i,
  /\bbe patient with yourself\b/i,
];

export const CAREER_TRANSITION_QA_USER_ID = "qa-career-transition-prd-user";

/** Extra system addendum when cold-start insight runs under this lens. */
export function buildCareerTransitionColdStartAddendum(): string {
  return CAREER_TRANSITION_COLD_START_SYSTEM_ADDENDUM;
}
