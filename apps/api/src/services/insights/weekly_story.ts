import "server-only";

import { extractJsonObject } from "@/lib/analyze/parse-reflection-response";
import { getOpenAIClient } from "@/lib/openai";

import {
  filterStrongLedgerEntries,
  filterUsableLedgerEntries,
  MIN_STRONG_LEDGER_ENTRIES_FOR_PROOF,
  MIN_USABLE_LEDGER_TEXT_CHARS,
} from "@/src/services/ledger/evidence_quality";
import type { EvidenceMatch } from "@/src/services/ledger/retrieve";
import {
  buildRangeRepresentativeQuery,
  listFactLedgerEntriesInRange,
  retrieveEvidenceInRange,
  type InsightTimeRange,
} from "@/src/services/ledger/time_range";

import type { PatternMatchConfidenceBand } from "@/types/insights";
import {
  isPatternMatchConfidenceBand,
  PATTERN_MATCH_CONFIDENCE_BANDS,
} from "@/types/insights";

const WEEKLY_STORY_MODEL =
  process.env.VOICEMEMORY_WEEKLY_STORY_MODEL?.trim() || "gpt-4o-mini";

/** Minimum usable entries recorded during the target week. */
export const WEEKLY_STORY_MIN_ENTRIES_THIS_WEEK = 1;

const WEEKLY_RETRIEVAL_LIMIT = 12;

export interface WeeklyStoryWindow {
  weekStart: Date;
  weekEnd: Date;
}

export interface WeeklyStoryBlockedResult {
  blocked: true;
  reason: string;
  weekStart: string;
  weekEnd: string;
  entryCountThisWeek: number;
  usableEntryCountThisWeek: number;
  strongEntryCountTotal: number;
}

export interface WeeklyStoryResult {
  blocked: false;
  storyText: string;
  confidenceBand: PatternMatchConfidenceBand;
  weekStart: string;
  weekEnd: string;
  entryCountThisWeek: number;
  usableEntryCountThisWeek: number;
  citedEntryIds: string[];
  retrievedMatches: EvidenceMatch[];
}

export type GenerateWeeklyStoryOutcome = WeeklyStoryResult | WeeklyStoryBlockedResult;

export class WeeklyStoryBlockedError extends Error {
  readonly code = "INSUFFICIENT_EVIDENCE" as const;
  readonly details: WeeklyStoryBlockedResult;

  constructor(details: WeeklyStoryBlockedResult) {
    super(details.reason);
    this.name = "WeeklyStoryBlockedError";
    this.details = details;
  }
}

const WEEKLY_STORY_JSON_SCHEMA = {
  type: "object",
  properties: {
    storyText: {
      type: "string",
      description: "2-4 sentences summarizing the week from cited evidence only.",
    },
    confidenceBand: {
      type: "string",
      enum: [...PATTERN_MATCH_CONFIDENCE_BANDS],
    },
    citedEntryIds: {
      type: "array",
      items: { type: "string" },
    },
  },
  required: ["storyText", "confidenceBand", "citedEntryIds"],
  additionalProperties: false,
} as const;

const WEEKLY_STORY_SYSTEM_PROMPT = `You write "Your Week in Reflection" summaries for ArchiveMe.

NON-NEGOTIABLE:
- Only describe what appears in the provided fact_ledger entries for this week.
- Cite exact entryId values from the entries block — copy character-for-character.
- Do NOT invent themes, emotions, stats, or events not supported by the entries.
- If the week is thin, say so plainly, set confidenceBand to "weak", and keep citedEntryIds minimal.
- No therapy-speak, coaching, diagnosis, or synthetic filler to pad a sparse week.
- Never mention being an AI.`;

function endOfLocalDay(date: Date): Date {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    23,
    59,
    59,
    999,
  );
}

function startOfLocalDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
}

/** Resolves a 7-day window ending on the provided date (inclusive). */
export function resolveWeeklyStoryWindow(weekEnding: Date = new Date()): WeeklyStoryWindow {
  const weekEnd = endOfLocalDay(weekEnding);
  const weekStart = startOfLocalDay(
    new Date(weekEnd.getTime() - 6 * 24 * 60 * 60 * 1000),
  );
  return { weekStart, weekEnd };
}

function buildBlockedResult(
  window: WeeklyStoryWindow,
  entryCountThisWeek: number,
  usableEntryCountThisWeek: number,
  strongEntryCountTotal: number,
  reason: string,
): WeeklyStoryBlockedResult {
  return {
    blocked: true,
    reason,
    weekStart: window.weekStart.toISOString(),
    weekEnd: window.weekEnd.toISOString(),
    entryCountThisWeek,
    usableEntryCountThisWeek,
    strongEntryCountTotal,
  };
}

function parseWeeklyStoryResponse(
  raw: string,
  allowedEntryIds: ReadonlySet<string>,
): Pick<WeeklyStoryResult, "storyText" | "confidenceBand" | "citedEntryIds"> {
  const parsed = JSON.parse(extractJsonObject(raw)) as {
    storyText?: unknown;
    confidenceBand?: unknown;
    citedEntryIds?: unknown;
  };

  const storyText =
    typeof parsed.storyText === "string" ? parsed.storyText.trim() : "";
  const confidenceBand = parsed.confidenceBand;

  if (!storyText) {
    throw new Error("Weekly story response missing storyText.");
  }
  if (
    typeof confidenceBand !== "string" ||
    !isPatternMatchConfidenceBand(confidenceBand)
  ) {
    throw new Error("Weekly story response missing valid confidenceBand.");
  }
  if (!Array.isArray(parsed.citedEntryIds)) {
    throw new Error("Weekly story response missing citedEntryIds array.");
  }

  const citedEntryIds = parsed.citedEntryIds.filter(
    (entryId): entryId is string =>
      typeof entryId === "string" && entryId.trim().length > 0,
  );

  const invalidCitation = citedEntryIds.find((entryId) => !allowedEntryIds.has(entryId));
  if (invalidCitation) {
    throw new Error(`Weekly story cited hallucinated entryId: ${invalidCitation}`);
  }

  return {
    storyText,
    confidenceBand,
    citedEntryIds: [...new Set(citedEntryIds)],
  };
}

/**
 * Evaluates whether the user's ledger meets real-entry thresholds for a weekly story.
 * Returns a blocked result instead of generating synthetic filler when evidence is thin.
 */
export async function evaluateWeeklyStoryEligibility(
  userId: string,
  window: WeeklyStoryWindow = resolveWeeklyStoryWindow(),
): Promise<WeeklyStoryBlockedResult | null> {
  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required for weekly story eligibility.");
  }

  const range: InsightTimeRange = {
    from: window.weekStart,
    to: window.weekEnd,
  };

  const thisWeekEntries = await listFactLedgerEntriesInRange(
    normalizedUserId,
    range,
    80,
  );
  const usableThisWeek = filterUsableLedgerEntries(thisWeekEntries);

  const allStrongEntries = filterStrongLedgerEntries(
    await listFactLedgerEntriesInRange(
      normalizedUserId,
      { from: new Date(0), to: window.weekEnd },
      200,
    ),
  );

  const entryCountThisWeek = thisWeekEntries.length;
  const usableEntryCountThisWeek = usableThisWeek.length;
  const strongEntryCountTotal = allStrongEntries.length;

  if (usableEntryCountThisWeek < WEEKLY_STORY_MIN_ENTRIES_THIS_WEEK) {
    return buildBlockedResult(
      window,
      entryCountThisWeek,
      usableEntryCountThisWeek,
      strongEntryCountTotal,
      `No usable entries this week (${usableEntryCountThisWeek}/${WEEKLY_STORY_MIN_ENTRIES_THIS_WEEK} required; ${MIN_USABLE_LEDGER_TEXT_CHARS}+ chars each).`,
    );
  }

  if (strongEntryCountTotal < MIN_STRONG_LEDGER_ENTRIES_FOR_PROOF) {
    return buildBlockedResult(
      window,
      entryCountThisWeek,
      usableEntryCountThisWeek,
      strongEntryCountTotal,
      `Archive needs ${MIN_STRONG_LEDGER_ENTRIES_FOR_PROOF}+ strong entries before weekly stories generate (${strongEntryCountTotal} found).`,
    );
  }

  return null;
}

/**
 * Generates a weekly review story when real-entry thresholds are met; otherwise blocks.
 */
export async function generateWeeklyStory(
  userId: string,
  window: WeeklyStoryWindow = resolveWeeklyStoryWindow(),
): Promise<GenerateWeeklyStoryOutcome> {
  const blocked = await evaluateWeeklyStoryEligibility(userId, window);
  if (blocked) {
    return blocked;
  }

  const normalizedUserId = userId.trim();
  const range: InsightTimeRange = {
    from: window.weekStart,
    to: window.weekEnd,
  };

  const thisWeekEntries = filterUsableLedgerEntries(
    await listFactLedgerEntriesInRange(normalizedUserId, range, 80),
  );

  const representativeQuery = buildRangeRepresentativeQuery(thisWeekEntries);
  const retrievedMatches = representativeQuery
    ? await retrieveEvidenceInRange(
        normalizedUserId,
        representativeQuery,
        range,
        WEEKLY_RETRIEVAL_LIMIT,
      )
    : thisWeekEntries;

  const allowedEntryIds = new Set(retrievedMatches.map((match) => match.entryId));
  const entriesBlock = retrievedMatches
    .map(
      (match, index) =>
        `[${index + 1}] entryId: ${match.entryId}\ncreatedAt: ${match.createdAt}\nraw_text: ${match.rawText}`,
    )
    .join("\n\n");

  const openai = getOpenAIClient();
  const completion = await openai.chat.completions.create({
    model: WEEKLY_STORY_MODEL,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "weekly_story",
        strict: true,
        schema: WEEKLY_STORY_JSON_SCHEMA,
      },
    },
    temperature: 0.25,
    messages: [
      { role: "system", content: WEEKLY_STORY_SYSTEM_PROMPT },
      {
        role: "user",
        content: `WEEK WINDOW: ${window.weekStart.toISOString()} → ${window.weekEnd.toISOString()}

THIS WEEK ENTRIES (only these may be cited):
${entriesBlock || "none"}

Write the weekly story. Do not invent filler if the week is sparse.`,
      },
    ],
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) {
    throw new Error("No weekly story returned from model.");
  }

  const parsed = parseWeeklyStoryResponse(content, allowedEntryIds);

  return {
    blocked: false,
    ...parsed,
    weekStart: window.weekStart.toISOString(),
    weekEnd: window.weekEnd.toISOString(),
    entryCountThisWeek: thisWeekEntries.length,
    usableEntryCountThisWeek: thisWeekEntries.length,
    retrievedMatches,
  };
}
