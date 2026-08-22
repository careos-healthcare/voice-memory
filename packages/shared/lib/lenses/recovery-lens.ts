/**
 * Recovery / sobriety thematic lens — strict neutral-mirror tone, correction
 * loop guardrails, and CI tone validation fixtures.
 */

export const RECOVERY_LENS_ID = "recovery" as const;

/** Neutral mirror targets — behavior, triggers, rationalizations only. */
export const RECOVERY_LISTEN_TARGETS = [
  "behavior sequences the user describes (where, when, with whom — cite entry dates)",
  "triggers and cue language in their own words (places, people, times, emotions)",
  "rationalizations and reversals (\"just this once\", \"I can handle it\", later regret)",
  "setback-and-return cycles without labeling them clinically",
] as const;

export const RECOVERY_FORBIDDEN_OUTPUT = [
  "clinical advice, diagnoses, or disorder labels",
  "therapeutic directives (\"you should\", \"try\", \"consider seeking\")",
  "motivational coaching or reassurance not grounded in cited ledger entries",
  "treatment plans, step-work instructions, or sobriety prescriptions",
] as const;

export const RECOVERY_SYSTEM_PROMPT_INJECTION = [
  "RECOVERY / SOBRIETY LENS — neutral mirror only:",
  ...RECOVERY_LISTEN_TARGETS.map((target, index) => `${index + 1}. ${target}`),
  "STRICT PROHIBITIONS:",
  ...RECOVERY_FORBIDDEN_OUTPUT.map((rule) => `- ${rule}`),
  "Reflect only what appears in fact_ledger entries — quote dates, places, and the user's phrasing.",
  "Prefer contradiction kind when stated intent conflicts with described behavior in the same week.",
  "If evidence is thin, say so plainly; never fill gaps with clinical or coaching language.",
].join("\n");

/** Heavy multiplier applied to correction suppression history under this lens. */
export const RECOVERY_SUPPRESSION_HISTORY_MULTIPLIER = 3;

export const RECOVERY_COLD_START_PROMPTS = [
  "What happened right before the urge or behavior you are tracking?",
  "Where were you, and who was around, the last time this pattern showed up?",
  "What story did you tell yourself in the moment — and what changed afterward?",
  "What trigger keeps returning even when you say you are done with it?",
] as const;

/** Language CI must reject — clinical / therapeutic guidance, not evidence citation. */
export const RECOVERY_CLINICAL_LANGUAGE_PATTERNS: readonly RegExp[] = [
  /\byou should\b/i,
  /\byou need to\b/i,
  /\bconsider (?:trying|seeking|calling)\b/i,
  /\bseek (?:professional|therapy|counseling|help)\b/i,
  /\b(?:diagnos|disorder|addict|alcoholic|substance use disorder)\b/i,
  /\b(?:coping strategy|treatment plan|relapse prevention plan)\b/i,
  /\b(?:hold space|self-care|healing journey)\b/i,
  /\b(?:it sounds like you(?:'re| are)|you may be experiencing)\b/i,
  /\b(?:recommend|prescribe|intervention)\b/i,
  /\bstep(?:ping)? (?:down|up) (?:your|a) (?:program|recovery)\b/i,
];

/** Acceptable neutral-mirror examples for validator self-checks. */
export const RECOVERY_ACCEPTABLE_MIRROR_EXAMPLES: readonly string[] = [
  'On March 12 you wrote that you drove past the old bar after work and told yourself you were "only checking the parking lot."',
  'Your April 3 entry names the argument with Sam as the hour before you skipped the meeting you said mattered.',
];

/** Mock outputs that must fail recovery tone CI. */
export const RECOVERY_FORBIDDEN_MOCK_OUTPUTS: readonly string[] = [
  "You should consider seeking therapy to work through these triggers.",
  "It sounds like you may be experiencing relapse warning signs and need a coping strategy.",
  "You need to prioritize self-care during this healing journey.",
];

export interface RecoveryToneValidationInput {
  insightText: string;
  requireEvidenceAnchor?: boolean;
}

export function validateRecoveryTone(input: RecoveryToneValidationInput): string[] {
  const failures: string[] = [];
  const text = input.insightText.trim();
  if (!text) {
    failures.push("recoveryTone: insightText is empty");
    return failures;
  }

  const clinicalHit = RECOVERY_CLINICAL_LANGUAGE_PATTERNS.find((pattern) =>
    pattern.test(text),
  );
  if (clinicalHit) {
    failures.push(
      `recoveryTone: clinical or therapeutic language detected (${clinicalHit})`,
    );
  }

  if (input.requireEvidenceAnchor !== false) {
    const hasDateOrQuote =
      /\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{4}|\d{1,2}\/\d{1,2})\b/i.test(
        text,
      ) || /["']/.test(text);
    if (!hasDateOrQuote && clinicalHit == null) {
      // Still require some concrete anchor for recovery mirror copy
      const hasBehaviorAnchor =
        /\b(wrote|said|told|entry|after|before|when you)\b/i.test(text);
      if (!hasBehaviorAnchor) {
        failures.push(
          "recoveryTone: missing evidence-style anchor (date, quote, or described behavior)",
        );
      }
    }
  }

  return failures;
}

export function buildRecoveryColdStartAddendum(): string {
  return `RECOVERY COLD START — capture trigger, place, time, and rationalization language verbatim.
Never infer clinical labels; cite only what entries contain.`;
}

export interface RecoveryQaSeedEntry {
  entryId: string;
  createdAt: string;
  rawText: string;
}

/** Behavior-specific mock archive for recovery genericness QA. */
export const RECOVERY_QA_SEED_ENTRIES: readonly RecoveryQaSeedEntry[] = [
  {
    entryId: "qa-riverside-mar12-2026",
    createdAt: "2026-03-12T21:10:00.000Z",
    rawText:
      'On March 12 I drove past the Riverside Bar after work and told myself I was "only checking the parking lot."',
  },
  {
    entryId: "qa-sam-apr03-2026",
    createdAt: "2026-04-03T22:40:00.000Z",
    rawText:
      "April 3 — Sam texted about the group meeting and I skipped it, then wrote that I could handle one drink because the week had been brutal.",
  },
  {
    entryId: "qa-urge-apr18-2026",
    createdAt: "2026-04-18T07:55:00.000Z",
    rawText:
      "April 18 morning: same Riverside route, same rationalization about just looking, then regret by noon.",
  },
] as const;

export const RECOVERY_QA_REQUIRED_ANCHORS = [
  "Riverside",
  "Sam",
  "March 12",
  "April 3",
  "parking lot",
  "group meeting",
] as const;

export const RECOVERY_QA_MIN_ANCHOR_MATCHES = 2;

export const RECOVERY_QA_QUERY_TRANSCRIPT =
  "I keep replaying the March 12 Riverside Bar drive and what I told Sam before skipping the April 3 group meeting.";

export const RECOVERY_QA_USER_ID = "qa-recovery-prd-user";
