import "server-only";

import { isGenericResurfacing, scoreSpecificity } from "@/lib/resurfacing/genericity-filter";
import {
  CAREER_TRANSITION_PLATITUDE_PATTERNS,
  CAREER_TRANSITION_QA_MIN_ANCHOR_MATCHES,
  CAREER_TRANSITION_QA_QUERY_TRANSCRIPT,
  CAREER_TRANSITION_QA_REQUIRED_ANCHORS,
  CAREER_TRANSITION_QA_SEED_ENTRIES,
  CAREER_TRANSITION_QA_USER_ID,
} from "@/lib/lenses/career-transition-lens";
import {
  RECOVERY_QA_MIN_ANCHOR_MATCHES,
  RECOVERY_QA_QUERY_TRANSCRIPT,
  RECOVERY_QA_REQUIRED_ANCHORS,
  RECOVERY_QA_SEED_ENTRIES,
  RECOVERY_QA_USER_ID,
  validateRecoveryTone,
} from "@/lib/lenses/recovery-lens";
import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { generateEvidenceBackedInsight } from "@/src/services/insights/generator";
import { bulkIngestHistoricalChunks } from "@/src/services/ledger/bulk_ingest";

/** Isolated QA user — never a production account id pattern. */
export const GENERICNESS_QA_USER_ID = "qa-genericness-prd-user";

export interface GenericnessQaSeedEntry {
  entryId: string;
  createdAt: string;
  rawText: string;
}

/**
 * Highly specific mock archive for PRD genericness QA.
 * Unique project names, named conflicts, and concrete calendar dates.
 */
export const GENERICNESS_QA_SEED_ENTRIES: readonly GenericnessQaSeedEntry[] = [
  {
    entryId: "qa-helios-mar14-2026",
    createdAt: "2026-03-14T09:15:00.000Z",
    rawText:
      "On March 14, 2026 I told Mara I might delay the Helios Bridge retrofit because the Lisbon relocation budget got cut by finance.",
  },
  {
    entryId: "qa-helios-mar22-2026",
    createdAt: "2026-03-22T16:40:00.000Z",
    rawText:
      "March 22, 2026 — Mara said the Helios Bridge vendor Northwind Fabrication would walk if we do not sign by April 3.",
  },
  {
    entryId: "qa-lisbon-apr01-2026",
    createdAt: "2026-04-01T08:05:00.000Z",
    rawText:
      "April 1, 2026: torn between the Helios Bridge safety audit and packing for the Lisbon relocation. Mara thinks I am avoiding that conflict.",
  },
  {
    entryId: "qa-nightingale-mar30-2026",
    createdAt: "2026-03-30T19:22:00.000Z",
    rawText:
      "Still angry about the March 30 call with Mara where she accused me of sabotaging Project Nightingale QA to stall the Helios Bridge sign-off.",
  },
] as const;

/** Entities or phrases that must appear in a user-specific insight for this seed. */
export const GENERICNESS_QA_REQUIRED_ANCHORS = [
  "Helios Bridge",
  "Mara",
  "Lisbon",
  "Northwind Fabrication",
  "Project Nightingale",
  "March 30",
  "April 3",
] as const;

/** Minimum distinct anchors required to avoid category-core trust failure. */
export const GENERICNESS_QA_MIN_ANCHOR_MATCHES = 2;

/** Query transcript tied to the seeded Helios Bridge / Mara / Lisbon thread. */
export const GENERICNESS_QA_QUERY_TRANSCRIPT =
  "I keep replaying the Helios Bridge argument with Mara and whether the Lisbon relocation is making me delay the Northwind Fabrication sign-off before April 3.";

/** Copy that could plausibly apply to any user — QA must reject these patterns when unanchored. */
const TRANSFERABLE_FRAMING_PATTERNS: readonly RegExp[] = [
  /\byou(?:'re| are) (?:going through|dealing with) a lot\b/i,
  /\brelationship tension\b/i,
  /\bwork.?life balance\b/i,
  /\bimportant to (?:you|prioritize self-care)\b/i,
  /\bpatterns (?:of|in) stress\b/i,
  /\bprocessing (?:a lot|your emotions)\b/i,
  /\bself[- ]?discovery\b/i,
  /\bemotional journey\b/i,
  /\bhold(?:ing)? space\b/i,
];

export interface GenericnessQaValidationInput {
  insightText: string;
  citedEntryIds: readonly string[];
  seedEntryIds: readonly string[];
  requiredAnchors?: readonly string[];
  minAnchorMatches?: number;
}

export function countMatchedAnchors(
  insightText: string,
  requiredAnchors: readonly string[],
): string[] {
  const normalized = insightText.toLowerCase();
  return requiredAnchors.filter((anchor) =>
    normalized.includes(anchor.toLowerCase()),
  );
}

/**
 * PRD genericness gate — fails when insight could apply to a different user.
 */
export function validateInsightGenericness(
  input: GenericnessQaValidationInput,
): string[] {
  const failures: string[] = [];
  const insightText = input.insightText.trim();
  const requiredAnchors = input.requiredAnchors ?? GENERICNESS_QA_REQUIRED_ANCHORS;
  const minAnchorMatches = input.minAnchorMatches ?? GENERICNESS_QA_MIN_ANCHOR_MATCHES;

  if (!insightText) {
    failures.push("insightText is empty");
    return failures;
  }

  if (isGenericResurfacing(insightText)) {
    failures.push(
      "insight failed resurfacing genericity gate (category-core trust failure: copy is too vague)",
    );
  }

  const specificity = scoreSpecificity(insightText);
  if (specificity < 42) {
    failures.push(
      `insight specificity score ${specificity} is below minimum 42 (category-core trust failure)`,
    );
  }

  const matchedAnchors = countMatchedAnchors(insightText, requiredAnchors);
  if (matchedAnchors.length < minAnchorMatches) {
    failures.push(
      `insight matched ${matchedAnchors.length}/${minAnchorMatches} required anchors [${matchedAnchors.join(", ") || "none"}]; expected entities from seeded Helios Bridge / Mara / Lisbon history`,
    );
  }

  const transferableHit = TRANSFERABLE_FRAMING_PATTERNS.find((pattern) =>
    pattern.test(insightText),
  );
  if (transferableHit && matchedAnchors.length < minAnchorMatches) {
    failures.push(
      `insight uses transferable framing (${transferableHit}) without enough user-specific anchors`,
    );
  }

  if (input.citedEntryIds.length > 0) {
    const seededCitations = input.citedEntryIds.filter((entryId) =>
      input.seedEntryIds.includes(entryId),
    );
    if (seededCitations.length === 0) {
      failures.push(
        "citedEntryIds do not reference any seeded QA ledger entries (possible hallucination or retrieval miss)",
      );
    }
  }

  const seedSnippetHit = GENERICNESS_QA_SEED_ENTRIES.some((entry) => {
    if (!input.seedEntryIds.includes(entry.entryId)) return false;
    const snippet = entry.rawText.slice(0, 32).toLowerCase();
    return insightText.toLowerCase().includes(snippet.slice(0, 18));
  });
  const hasProperNounAnchor = matchedAnchors.length >= minAnchorMatches;
  if (!seedSnippetHit && !hasProperNounAnchor) {
    failures.push(
      "insight contains neither seeded wording nor enough named entities — could apply to another user",
    );
  }

  return failures;
}

export interface CareerTransitionGenericnessInput {
  insightText: string;
  citedEntryIds: readonly string[];
  seedEntryIds: readonly string[];
  requiredAnchors?: readonly string[];
  minAnchorMatches?: number;
}

/**
 * Career-transition genericness gate — rejects unanchored workplace platitudes.
 */
export function validateCareerTransitionInsightGenericness(
  input: CareerTransitionGenericnessInput,
): string[] {
  const failures: string[] = [];
  const insightText = input.insightText.trim();
  const requiredAnchors =
    input.requiredAnchors ?? CAREER_TRANSITION_QA_REQUIRED_ANCHORS;
  const minAnchorMatches =
    input.minAnchorMatches ?? CAREER_TRANSITION_QA_MIN_ANCHOR_MATCHES;

  if (!insightText) {
    failures.push("careerTransition: insightText is empty");
    return failures;
  }

  if (isGenericResurfacing(insightText)) {
    failures.push(
      "careerTransition: insight failed resurfacing genericity gate",
    );
  }

  const specificity = scoreSpecificity(insightText);
  if (specificity < 42) {
    failures.push(
      `careerTransition: specificity score ${specificity} is below minimum 42`,
    );
  }

  const matchedAnchors = countMatchedAnchors(insightText, requiredAnchors);
  if (matchedAnchors.length < minAnchorMatches) {
    failures.push(
      `careerTransition: matched ${matchedAnchors.length}/${minAnchorMatches} workplace anchors [${matchedAnchors.join(", ") || "none"}]`,
    );
  }

  const platitudeHit = CAREER_TRANSITION_PLATITUDE_PATTERNS.find((pattern) =>
    pattern.test(insightText),
  );
  if (platitudeHit && matchedAnchors.length < minAnchorMatches) {
    failures.push(
      `careerTransition: uses career platitude (${platitudeHit}) without workplace-specific anchors`,
    );
  }

  if (input.citedEntryIds.length > 0) {
    const seededCitations = input.citedEntryIds.filter((entryId) =>
      input.seedEntryIds.includes(entryId),
    );
    if (seededCitations.length === 0) {
      failures.push(
        "careerTransition: citedEntryIds do not reference seeded QA ledger entries",
      );
    }
  }

  const workplaceSnippetHit = CAREER_TRANSITION_QA_SEED_ENTRIES.some((entry) => {
    if (!input.seedEntryIds.includes(entry.entryId)) return false;
    const snippet = entry.rawText.slice(0, 28).toLowerCase();
    return insightText.toLowerCase().includes(snippet.slice(0, 16));
  });
  if (!workplaceSnippetHit && matchedAnchors.length < minAnchorMatches) {
    failures.push(
      "careerTransition: insight lacks seeded workplace wording and named entities",
    );
  }

  return failures;
}

function runCareerTransitionValidatorSelfChecks(): string[] {
  const failures: string[] = [];
  const seedIds = CAREER_TRANSITION_QA_SEED_ENTRIES.map((entry) => entry.entryId);

  const goodInsight =
    "You told Dana on March 3 that your Rust toolchain work might transfer to Meridian Labs' fintech pivot instead of dying with the platform team.";
  failures.push(
    ...validateCareerTransitionInsightGenericness({
      insightText: goodInsight,
      citedEntryIds: ["qa-dana-mar03-2026"],
      seedEntryIds: seedIds,
    }),
  );

  const badInsight =
    "You are facing challenges during this career transition and navigating change at work.";
  const badFailures = validateCareerTransitionInsightGenericness({
    insightText: badInsight,
    citedEntryIds: [],
    seedEntryIds: seedIds,
  });
  if (badFailures.length === 0) {
    failures.push(
      "careerTransition: validator failed to reject generic workplace platitude",
    );
  }

  return failures;
}

async function seedCareerTransitionQaLedger(userId: string): Promise<void> {
  await dbQuery(`DELETE FROM fact_ledger WHERE user_id = $1`, [userId]);
  await bulkIngestHistoricalChunks(
    userId,
    CAREER_TRANSITION_QA_SEED_ENTRIES.map((entry) => ({
      entryId: entry.entryId,
      rawText: entry.rawText,
      createdAt: new Date(entry.createdAt),
    })),
  );
}

async function cleanupCareerTransitionQaUser(userId: string): Promise<void> {
  await dbQuery(`DELETE FROM fact_ledger WHERE user_id = $1`, [userId]);
}

/**
 * Career-transition lens integration — asserts workplace-specific citations.
 */
export async function runCareerTransitionGenericnessQaTest(): Promise<{
  failures: string[];
  skipped?: boolean;
  skipReason?: string;
}> {
  const failures: string[] = [];
  failures.push(...runCareerTransitionValidatorSelfChecks());

  const envError = assertQaEnvironmentReady();
  if (envError) {
    return { failures: [], skipped: true, skipReason: envError };
  }

  try {
    await seedCareerTransitionQaLedger(CAREER_TRANSITION_QA_USER_ID);

    const result = await generateEvidenceBackedInsight(
      CAREER_TRANSITION_QA_USER_ID,
      CAREER_TRANSITION_QA_QUERY_TRANSCRIPT,
      { activeLens: "careerTransition", isColdStartPass: true },
    );

    failures.push(
      ...validateCareerTransitionInsightGenericness({
        insightText: result.insightText,
        citedEntryIds: result.citedEntryIds,
        seedEntryIds: CAREER_TRANSITION_QA_SEED_ENTRIES.map((entry) => entry.entryId),
      }),
    );

    if (result.confidenceBand === "weak" && result.citedEntryIds.length === 0) {
      failures.push(
        "careerTransition: insight returned weak confidence with no citations despite seeded ledger",
      );
    }
  } catch (error) {
    failures.push(
      `careerTransition QA integration failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    try {
      await cleanupCareerTransitionQaUser(CAREER_TRANSITION_QA_USER_ID);
    } catch (cleanupError) {
      failures.push(
        `careerTransition QA cleanup failed: ${cleanupError instanceof Error ? cleanupError.message : String(cleanupError)}`,
      );
    }
  }

  return { failures };
}

export interface RecoveryGenericnessInput {
  insightText: string;
  citedEntryIds: readonly string[];
  seedEntryIds: readonly string[];
  requiredAnchors?: readonly string[];
  minAnchorMatches?: number;
}

/**
 * Recovery lens genericness gate — rejects clinical platitudes; requires evidence anchors.
 */
export function validateRecoveryInsightGenericness(
  input: RecoveryGenericnessInput,
): string[] {
  const failures: string[] = [];
  const insightText = input.insightText.trim();
  const requiredAnchors =
    input.requiredAnchors ?? RECOVERY_QA_REQUIRED_ANCHORS;
  const minAnchorMatches =
    input.minAnchorMatches ?? RECOVERY_QA_MIN_ANCHOR_MATCHES;

  if (!insightText) {
    failures.push("recovery: insightText is empty");
    return failures;
  }

  failures.push(...validateRecoveryTone({ insightText }));

  if (isGenericResurfacing(insightText)) {
    failures.push("recovery: insight failed resurfacing genericity gate");
  }

  const matchedAnchors = countMatchedAnchors(insightText, requiredAnchors);
  if (matchedAnchors.length < minAnchorMatches) {
    failures.push(
      `recovery: matched ${matchedAnchors.length}/${minAnchorMatches} behavior anchors [${matchedAnchors.join(", ") || "none"}]`,
    );
  }

  if (input.citedEntryIds.length > 0) {
    const seededCitations = input.citedEntryIds.filter((entryId) =>
      input.seedEntryIds.includes(entryId),
    );
    if (seededCitations.length === 0) {
      failures.push(
        "recovery: citedEntryIds do not reference seeded QA ledger entries",
      );
    }
  }

  const behaviorSnippetHit = RECOVERY_QA_SEED_ENTRIES.some((entry) => {
    if (!input.seedEntryIds.includes(entry.entryId)) return false;
    const snippet = entry.rawText.slice(0, 28).toLowerCase();
    return insightText.toLowerCase().includes(snippet.slice(0, 16));
  });
  if (!behaviorSnippetHit && matchedAnchors.length < minAnchorMatches) {
    failures.push(
      "recovery: insight lacks seeded behavior wording and named anchors",
    );
  }

  return failures;
}

function runRecoveryValidatorSelfChecks(): string[] {
  const failures: string[] = [];
  const seedIds = RECOVERY_QA_SEED_ENTRIES.map((entry) => entry.entryId);

  const goodInsight =
    'On March 12 you wrote that you drove past the Riverside Bar and told yourself you were "only checking the parking lot."';
  failures.push(
    ...validateRecoveryInsightGenericness({
      insightText: goodInsight,
      citedEntryIds: ["qa-riverside-mar12-2026"],
      seedEntryIds: seedIds,
    }),
  );

  const badInsight =
    "You should consider seeking therapy to work through these triggers during your healing journey.";
  const badFailures = validateRecoveryInsightGenericness({
    insightText: badInsight,
    citedEntryIds: [],
    seedEntryIds: seedIds,
  });
  if (badFailures.length === 0) {
    failures.push(
      "recovery: validator failed to reject clinical therapeutic platitude",
    );
  }

  return failures;
}

async function seedRecoveryQaLedger(userId: string): Promise<void> {
  await dbQuery(`DELETE FROM fact_ledger WHERE user_id = $1`, [userId]);
  await bulkIngestHistoricalChunks(
    userId,
    RECOVERY_QA_SEED_ENTRIES.map((entry) => ({
      entryId: entry.entryId,
      rawText: entry.rawText,
      createdAt: new Date(entry.createdAt),
    })),
  );
}

async function cleanupRecoveryQaUser(userId: string): Promise<void> {
  await dbQuery(`DELETE FROM fact_ledger WHERE user_id = $1`, [userId]);
}

/**
 * Recovery lens integration — asserts neutral-mirror copy cites ledger behavior.
 */
export async function runRecoveryGenericnessQaTest(): Promise<{
  failures: string[];
  skipped?: boolean;
  skipReason?: string;
}> {
  const failures: string[] = [];
  failures.push(...runRecoveryValidatorSelfChecks());

  const envError = assertQaEnvironmentReady();
  if (envError) {
    return { failures: [], skipped: true, skipReason: envError };
  }

  try {
    await seedRecoveryQaLedger(RECOVERY_QA_USER_ID);

    const result = await generateEvidenceBackedInsight(
      RECOVERY_QA_USER_ID,
      RECOVERY_QA_QUERY_TRANSCRIPT,
      { activeLens: "recovery", isColdStartPass: true },
    );

    failures.push(
      ...validateRecoveryInsightGenericness({
        insightText: result.insightText,
        citedEntryIds: result.citedEntryIds,
        seedEntryIds: RECOVERY_QA_SEED_ENTRIES.map((entry) => entry.entryId),
      }),
    );

    if (result.confidenceBand === "weak" && result.citedEntryIds.length === 0) {
      failures.push(
        "recovery: insight returned weak confidence with no citations despite seeded ledger",
      );
    }
  } catch (error) {
    failures.push(
      `recovery QA integration failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    try {
      await cleanupRecoveryQaUser(RECOVERY_QA_USER_ID);
    } catch (cleanupError) {
      failures.push(
        `recovery QA cleanup failed: ${cleanupError instanceof Error ? cleanupError.message : String(cleanupError)}`,
      );
    }
  }

  return { failures };
}

function assertQaEnvironmentReady(): string | null {
  if (!shouldUsePostgresStorage()) {
    return "DATABASE_URL is required for genericness QA acceptance test.";
  }
  if (!process.env.GEMINI_API_KEY?.trim()) {
    return "GEMINI_API_KEY is required to embed seeded fact_ledger rows.";
  }
  if (!process.env.OPENAI_API_KEY?.trim()) {
    return "OPENAI_API_KEY is required to run generateEvidenceBackedInsight.";
  }
  return null;
}

async function cleanupGenericnessQaUser(userId: string): Promise<void> {
  await dbQuery(`DELETE FROM fact_ledger WHERE user_id = $1`, [userId]);
}

async function seedGenericnessQaLedger(userId: string): Promise<void> {
  await cleanupGenericnessQaUser(userId);
  await bulkIngestHistoricalChunks(
    userId,
    GENERICNESS_QA_SEED_ENTRIES.map((entry) => ({
      entryId: entry.entryId,
      rawText: entry.rawText,
      createdAt: new Date(entry.createdAt),
    })),
  );
}

function runValidatorSelfChecks(): string[] {
  const failures: string[] = [];
  const seedIds = GENERICNESS_QA_SEED_ENTRIES.map((entry) => entry.entryId);

  const goodInsight =
    'You told Mara on March 30 that Project Nightingale QA was stalling the Helios Bridge sign-off before the April 3 Northwind Fabrication deadline.';
  failures.push(
    ...validateInsightGenericness({
      insightText: goodInsight,
      citedEntryIds: ["qa-nightingale-mar30-2026"],
      seedEntryIds: seedIds,
    }),
  );

  const badInsight =
    "You are going through a lot lately and processing emotions around relationship tension at work.";
  const badFailures = validateInsightGenericness({
    insightText: badInsight,
    citedEntryIds: [],
    seedEntryIds: seedIds,
  });
  if (badFailures.length === 0) {
    failures.push("validator failed to reject transferable generic insight");
  }

  return failures;
}

/**
 * PRD QA acceptance test — seeds fact_ledger, generates an evidence-backed insight,
 * and asserts user-specific anchors (not category-generic copy).
 */
export async function runGenericnessQaTest(): Promise<{
  failures: string[];
  skipped?: boolean;
  skipReason?: string;
}> {
  const failures: string[] = [];
  failures.push(...runValidatorSelfChecks());

  const envError = assertQaEnvironmentReady();
  if (envError) {
    failures.push(...runCareerTransitionValidatorSelfChecks());
    failures.push(...runRecoveryValidatorSelfChecks());
    return { failures, skipped: true, skipReason: envError };
  }

  try {
    await seedGenericnessQaLedger(GENERICNESS_QA_USER_ID);

    const result = await generateEvidenceBackedInsight(
      GENERICNESS_QA_USER_ID,
      GENERICNESS_QA_QUERY_TRANSCRIPT,
    );

    failures.push(
      ...validateInsightGenericness({
        insightText: result.insightText,
        citedEntryIds: result.citedEntryIds,
        seedEntryIds: GENERICNESS_QA_SEED_ENTRIES.map((entry) => entry.entryId),
      }),
    );

    if (result.confidenceBand === "weak" && result.citedEntryIds.length === 0) {
      failures.push(
        "generateEvidenceBackedInsight returned weak confidence with no citations despite seeded ledger",
      );
    }
  } catch (error) {
    failures.push(
      `genericness QA integration failed: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    try {
      await cleanupGenericnessQaUser(GENERICNESS_QA_USER_ID);
    } catch (cleanupError) {
      failures.push(
        `genericness QA cleanup failed: ${cleanupError instanceof Error ? cleanupError.message : String(cleanupError)}`,
      );
    }
  }

  const careerResult = await runCareerTransitionGenericnessQaTest();
  if (!careerResult.skipped) {
    failures.push(...careerResult.failures);
  } else if (careerResult.skipReason && careerResult.skipReason !== envError) {
    failures.push(`careerTransition QA skipped unexpectedly: ${careerResult.skipReason}`);
  }

  const recoveryResult = await runRecoveryGenericnessQaTest();
  if (!recoveryResult.skipped) {
    failures.push(...recoveryResult.failures);
  } else if (recoveryResult.skipReason && recoveryResult.skipReason !== envError) {
    failures.push(`recovery QA skipped unexpectedly: ${recoveryResult.skipReason}`);
  }

  return { failures };
}
