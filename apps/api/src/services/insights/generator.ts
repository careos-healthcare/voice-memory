import "server-only";

import { extractJsonObject } from "@/lib/analyze/parse-reflection-response";
import { getOpenAIClient } from "@/lib/openai";

import type { EvidenceMatch } from "@/src/services/ledger/retrieve";
import { retrieveEvidence } from "@/src/services/ledger/retrieve";

import type { ArchiveInsightKind } from "@/types/insights";
import type { PatternMatchConfidenceBand } from "@/types/insights";
import {
  ARCHIVE_INSIGHT_KINDS,
  isArchiveInsightKind,
  isPatternMatchConfidenceBand,
  PATTERN_MATCH_CONFIDENCE_BANDS,
} from "@/types/insights";
import { composeFactLedgerSystemPrompt } from "@/lib/archive-synthesis/prompt-context-contract";
import { buildCareerTransitionColdStartAddendum } from "@/lib/lenses/career-transition-lens";
import { buildGriefLossColdStartAddendum } from "@/lib/lenses/grief-loss-lens";
import { buildNewParentColdStartAddendum } from "@/lib/lenses/new-parent-lens";
import { buildRecoveryColdStartAddendum } from "@/lib/lenses/recovery-lens";
import type { LifeStageLens } from "@/types/user-context";
import { normalizeLifeStageLens } from "@/types/user-context";

export interface EvidenceBackedInsight {
  insightText: string;
  kind: ArchiveInsightKind;
  confidenceBand: PatternMatchConfidenceBand;
  citedEntryIds: string[];
}

export interface GenerateEvidenceBackedInsightResult extends EvidenceBackedInsight {
  retrievedMatches: EvidenceMatch[];
}

const INSIGHT_MODEL =
  process.env.VOICEMEMORY_EVIDENCE_INSIGHT_MODEL?.trim() || "gpt-4o-mini";

const RETRIEVAL_LIMIT = 5;
const COLD_START_RETRIEVAL_LIMIT = 15;

const COLD_START_SYSTEM_PROMPT_ADDENDUM = `COLD START PASS — high-effort historical review (Day 1 backlog import):
- The user just imported a historical backlog. Aggressively scan ALL retrieved historical entries for a cross-entry theme OR a meaningful contradiction.
- Prefer kind "theme" when the same topic, worry, or goal repeats across dates; prefer kind "contradiction" when entries disagree, reverse course, or hold incompatible stances.
- Cross-reference dates and exact wording — cite at least two entryId values when the evidence supports it.
- Do not settle for a thin single-entry observation when multiple entries are available.
- Raise confidenceBand when several entries reinforce the same pattern; use "solid" or "strong" when warranted by the backlog breadth.`;

export interface GenerateEvidenceBackedInsightOptions {
  isColdStartPass?: boolean;
  activeLens?: LifeStageLens | null;
}

function buildSystemPrompt(options?: GenerateEvidenceBackedInsightOptions): string {
  let prompt = SYSTEM_PROMPT;
  if (options?.isColdStartPass) {
    prompt = `${prompt}\n\n${COLD_START_SYSTEM_PROMPT_ADDENDUM}`;
    const lens = normalizeLifeStageLens(options?.activeLens ?? "default");
    if (lens === "careerTransition") {
      prompt = `${prompt}\n\n${buildCareerTransitionColdStartAddendum()}`;
    }
    if (lens === "recovery") {
      prompt = `${prompt}\n\n${buildRecoveryColdStartAddendum()}`;
    }
    if (lens === "newParent") {
      prompt = `${prompt}\n\n${buildNewParentColdStartAddendum()}`;
    }
    if (lens === "griefLoss") {
      prompt = `${prompt}\n\n${buildGriefLossColdStartAddendum()}`;
    }
  }
  return composeFactLedgerSystemPrompt({
    baseSystemPrompt: prompt,
    activeLens: normalizeLifeStageLens(options?.activeLens ?? "default"),
  });
}

const EVIDENCE_INSIGHT_JSON_SCHEMA = {
  type: "object",
  properties: {
    insightText: {
      type: "string",
      description: "1-3 short sentences grounded in cited evidence.",
    },
    kind: {
      type: "string",
      enum: [...ARCHIVE_INSIGHT_KINDS],
      description: "Evidence Method insight taxonomy category.",
    },
    confidenceBand: {
      type: "string",
      enum: [...PATTERN_MATCH_CONFIDENCE_BANDS],
      description: "Pattern match strength based on historical support.",
    },
    citedEntryIds: {
      type: "array",
      items: { type: "string" },
      description: "entryId values copied exactly from provided historical entries.",
    },
  },
  required: ["insightText", "kind", "confidenceBand", "citedEntryIds"],
  additionalProperties: false,
} as const;

const SYSTEM_PROMPT = `You generate Evidence Method insights for ArchiveMe.

THE EVIDENCE METHOD — non-negotiable:
- You may only generate an insight if it is strictly proven by the provided historical entries and the current transcript.
- You must cite the exact entry IDs (entryId values) from the historical entries block. Copy them character-for-character.
- Do NOT invent past events, feelings, patterns, quotes, or entry IDs that are not in the provided context.
- Every claim in insightText must be traceable to the current transcript and/or cited historical entries.

KIND GUIDE (choose one):
- belief: a stable conviction the user expresses
- beliefChange: evidence that a prior belief shifted
- theme: a recurring topic across entries
- contradiction: tension between statements or stances
- blindSpot: something present in history but absent or avoided now
- chapter: a life phase or narrative segment emerging from entries
- weeklyStory: a coherent story arc across recent entries
- surprise: an unexpected connection or reversal in the record
- challenge: friction, difficulty, or obstacle that repeats or intensifies

CONFIDENCE BAND GUIDE:
- weak: single mention, thin overlap, or insufficient historical support
- emerging: 2 related mentions or one clear repeat with partial support
- solid: multiple consistent historical mentions aligned with the current transcript
- strong: clear, repeated pattern across several historical entries and the current transcript

If historical entries are empty or too thin to support a pattern, say so plainly in insightText, set confidenceBand to "weak", pick the closest kind, and return citedEntryIds as [].

No therapy-speak, coaching, diagnosis, or generic encouragement. Quote the user's words when possible.
Never mention being an AI.`;

function buildHistoricalEntriesBlock(matches: EvidenceMatch[]): string {
  if (matches.length === 0) {
    return "HISTORICAL ENTRIES: none retrieved.";
  }

  return matches
    .map(
      (match, index) =>
        `[${index + 1}] entryId: ${match.entryId}\ncreatedAt: ${match.createdAt}\nraw_text: ${match.rawText}`,
    )
    .join("\n\n");
}

function buildUserPrompt(currentTranscript: string, matches: EvidenceMatch[]): string {
  return `CURRENT TRANSCRIPT:
${currentTranscript}

HISTORICAL ENTRIES (vector-retrieved from fact_ledger — only these may be cited):
${buildHistoricalEntriesBlock(matches)}

Generate one evidence-backed insight. You may only cite entryId values listed above.`;
}

function parseEvidenceBackedInsight(
  raw: string,
  allowedEntryIds: ReadonlySet<string>,
): EvidenceBackedInsight {
  const parsed = JSON.parse(extractJsonObject(raw)) as {
    insightText?: unknown;
    kind?: unknown;
    confidenceBand?: unknown;
    citedEntryIds?: unknown;
  };

  const insightText =
    typeof parsed.insightText === "string" ? parsed.insightText.trim() : "";
  const kind = parsed.kind;
  const confidenceBand = parsed.confidenceBand;

  if (!insightText) {
    throw new Error("Evidence insight response missing insightText.");
  }
  if (typeof kind !== "string" || !isArchiveInsightKind(kind)) {
    throw new Error("Evidence insight response missing valid kind.");
  }
  if (
    typeof confidenceBand !== "string" ||
    !isPatternMatchConfidenceBand(confidenceBand)
  ) {
    throw new Error("Evidence insight response missing valid confidenceBand.");
  }
  if (!Array.isArray(parsed.citedEntryIds)) {
    throw new Error("Evidence insight response missing citedEntryIds array.");
  }

  const citedEntryIds = parsed.citedEntryIds.filter(
    (entryId): entryId is string =>
      typeof entryId === "string" && entryId.trim().length > 0,
  );

  const invalidCitation = citedEntryIds.find((entryId) => !allowedEntryIds.has(entryId));
  if (invalidCitation) {
    throw new Error(`Evidence insight cited hallucinated entryId: ${invalidCitation}`);
  }

  return {
    insightText,
    kind,
    confidenceBand,
    citedEntryIds: [...new Set(citedEntryIds)],
  };
}

/**
 * Retrieves ledger evidence, prompts an LLM under Evidence Method rules, and
 * validates that every cited entry ID was present in the retrieval context.
 */
export async function generateEvidenceBackedInsight(
  userId: string,
  currentTranscript: string,
  options?: GenerateEvidenceBackedInsightOptions,
): Promise<GenerateEvidenceBackedInsightResult> {
  const transcript = currentTranscript.trim();
  if (!userId.trim()) {
    throw new Error("userId is required to generate an evidence-backed insight.");
  }
  if (!transcript) {
    throw new Error("currentTranscript is required to generate an evidence-backed insight.");
  }

  const retrievalLimit = options?.isColdStartPass
    ? COLD_START_RETRIEVAL_LIMIT
    : RETRIEVAL_LIMIT;
  const retrievedMatches = await retrieveEvidence(userId, transcript, retrievalLimit);
  const allowedEntryIds = new Set(retrievedMatches.map((match) => match.entryId));

  const openai = getOpenAIClient();
  const completion = await openai.chat.completions.create({
    model: INSIGHT_MODEL,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "evidence_backed_insight",
        strict: true,
        schema: EVIDENCE_INSIGHT_JSON_SCHEMA,
      },
    },
    temperature: options?.isColdStartPass ? 0.35 : 0.2,
    messages: [
      { role: "system", content: buildSystemPrompt(options) },
      { role: "user", content: buildUserPrompt(transcript, retrievedMatches) },
    ],
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) {
    throw new Error("No evidence-backed insight returned from model.");
  }

  const insight = parseEvidenceBackedInsight(content, allowedEntryIds);

  return {
    ...insight,
    retrievedMatches,
  };
}
