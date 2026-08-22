import "server-only";

import { extractJsonObject } from "@/lib/analyze/parse-reflection-response";
import {
  COMPARISON_CONFIDENCE_LABELS,
  COMPARISON_ENGINE_SYSTEM_PROMPT,
  type ComparisonConfidenceLabel,
  violatesComparisonBannedPhrase,
} from "@/lib/comparison/comparison-engine-prompt";
import { getOpenAIClient } from "@/lib/openai";

import {
  filterUsableLedgerEntries,
  MIN_USABLE_LEDGER_TEXT_CHARS,
} from "@/src/services/ledger/evidence_quality";
import type { EvidenceMatch } from "@/src/services/ledger/retrieve";
import {
  buildRangeRepresentativeQuery,
  countFactLedgerEntriesInRange,
  listFactLedgerEntriesInRange,
  retrieveEvidenceInRange,
  type InsightTimeRange,
} from "@/src/services/ledger/time_range";

export type { InsightTimeRange };

const COMPARISON_MODEL =
  process.env.VOICEMEMORY_COMPARISON_MODEL?.trim() || "gpt-4o-mini";

/** Minimum usable entries required in each comparison window. */
export const COMPARISON_MIN_USABLE_ENTRIES_PER_RANGE = 2;

const INTRA_RANGE_RETRIEVAL_LIMIT = 6;
const CROSS_RANGE_RETRIEVAL_LIMIT = 5;

export interface ComparisonPeriodSnapshot {
  from: string;
  to: string;
  totalEntryCount: number;
  usableEntryCount: number;
  entries: EvidenceMatch[];
  clusterMatches: EvidenceMatch[];
  crossPeriodMatches: EvidenceMatch[];
}

export interface ThenVsNowComparisonResult {
  evolutionText: string;
  confidenceLabel: ComparisonConfidenceLabel;
  whatRepeated: string;
  whatChanged: string;
  thinEvidencePhrase?: string;
  periodA: ComparisonPeriodSnapshot;
  periodB: ComparisonPeriodSnapshot;
  citedEntryIds: string[];
}

export class ThenVsNowComparisonBlockedError extends Error {
  readonly code = "INSUFFICIENT_EVIDENCE" as const;

  constructor(message: string) {
    super(message);
    this.name = "ThenVsNowComparisonBlockedError";
  }
}

const COMPARISON_JSON_SCHEMA = {
  type: "object",
  properties: {
    confidenceLabel: {
      type: "string",
      enum: [...COMPARISON_CONFIDENCE_LABELS],
    },
    whatRepeated: { type: "string" },
    whatChanged: { type: "string" },
    evolutionText: {
      type: "string",
      description: "1-3 sentences linking both periods with cited evidence.",
    },
    thinEvidencePhrase: { type: "string" },
    citedEntryIds: {
      type: "array",
      items: { type: "string" },
    },
  },
  required: [
    "confidenceLabel",
    "whatRepeated",
    "whatChanged",
    "evolutionText",
    "citedEntryIds",
  ],
  additionalProperties: false,
} as const;

function dedupeMatches(matches: readonly EvidenceMatch[]): EvidenceMatch[] {
  const seen = new Set<string>();
  const deduped: EvidenceMatch[] = [];
  for (const match of matches) {
    if (seen.has(match.entryId)) continue;
    seen.add(match.entryId);
    deduped.push(match);
  }
  return deduped;
}

function buildEntriesBlock(label: string, matches: readonly EvidenceMatch[]): string {
  if (matches.length === 0) {
    return `${label}: none`;
  }

  return matches
    .map(
      (match, index) =>
        `${label} [${index + 1}] entryId: ${match.entryId}\ncreatedAt: ${match.createdAt}\nraw_text: ${match.rawText}`,
    )
    .join("\n\n");
}

function parseComparisonResponse(
  raw: string,
  allowedEntryIds: ReadonlySet<string>,
): Omit<ThenVsNowComparisonResult, "periodA" | "periodB"> {
  const parsed = JSON.parse(extractJsonObject(raw)) as {
    confidenceLabel?: unknown;
    whatRepeated?: unknown;
    whatChanged?: unknown;
    evolutionText?: unknown;
    thinEvidencePhrase?: unknown;
    citedEntryIds?: unknown;
  };

  const confidenceLabel = parsed.confidenceLabel;
  const whatRepeated =
    typeof parsed.whatRepeated === "string" ? parsed.whatRepeated.trim() : "";
  const whatChanged =
    typeof parsed.whatChanged === "string" ? parsed.whatChanged.trim() : "";
  const evolutionText =
    typeof parsed.evolutionText === "string" ? parsed.evolutionText.trim() : "";
  const thinEvidencePhrase =
    typeof parsed.thinEvidencePhrase === "string"
      ? parsed.thinEvidencePhrase.trim()
      : undefined;

  if (
    typeof confidenceLabel !== "string" ||
    !COMPARISON_CONFIDENCE_LABELS.includes(confidenceLabel as ComparisonConfidenceLabel)
  ) {
    throw new Error("Comparison response missing valid confidenceLabel.");
  }
  if (!whatRepeated || !whatChanged || !evolutionText) {
    throw new Error("Comparison response missing required narrative fields.");
  }
  if (!Array.isArray(parsed.citedEntryIds)) {
    throw new Error("Comparison response missing citedEntryIds array.");
  }

  const citedEntryIds = parsed.citedEntryIds.filter(
    (entryId): entryId is string =>
      typeof entryId === "string" && entryId.trim().length > 0,
  );

  const invalidCitation = citedEntryIds.find((entryId) => !allowedEntryIds.has(entryId));
  if (invalidCitation) {
    throw new Error(`Comparison cited hallucinated entryId: ${invalidCitation}`);
  }

  const combinedText = `${evolutionText}\n${whatRepeated}\n${whatChanged}`;
  if (violatesComparisonBannedPhrase(combinedText)) {
    throw new Error("Comparison response used banned certainty phrasing.");
  }

  return {
    confidenceLabel: confidenceLabel as ComparisonConfidenceLabel,
    whatRepeated,
    whatChanged,
    evolutionText,
    thinEvidencePhrase: thinEvidencePhrase || undefined,
    citedEntryIds: [...new Set(citedEntryIds)],
  };
}

async function buildPeriodSnapshot(
  userId: string,
  range: InsightTimeRange,
): Promise<ComparisonPeriodSnapshot> {
  const [totalEntryCount, listed] = await Promise.all([
    countFactLedgerEntriesInRange(userId, range),
    listFactLedgerEntriesInRange(userId, range),
  ]);

  const usableEntries = filterUsableLedgerEntries(listed);
  const representativeQuery = buildRangeRepresentativeQuery(usableEntries);

  const clusterMatches = representativeQuery
    ? await retrieveEvidenceInRange(
        userId,
        representativeQuery,
        range,
        INTRA_RANGE_RETRIEVAL_LIMIT,
      )
    : [];

  return {
    from: range.from.toISOString(),
    to: range.to.toISOString(),
    totalEntryCount,
    usableEntryCount: usableEntries.length,
    entries: usableEntries,
    clusterMatches: dedupeMatches(clusterMatches),
    crossPeriodMatches: [],
  };
}

/**
 * Queries vector clusters across two distinct fact_ledger timeframes and returns
 * an evidence-linked then-vs-now evolution view.
 */
export async function generateThenVsNowComparison(
  userId: string,
  timeRangeA: InsightTimeRange,
  timeRangeB: InsightTimeRange,
): Promise<ThenVsNowComparisonResult> {
  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required for then-vs-now comparison.");
  }

  const periodA = await buildPeriodSnapshot(normalizedUserId, timeRangeA);
  const periodB = await buildPeriodSnapshot(normalizedUserId, timeRangeB);

  const periodAQuery = buildRangeRepresentativeQuery(periodA.entries);
  const periodBQuery = buildRangeRepresentativeQuery(periodB.entries);

  // Cross-period clusters: THEN themes retrieved inside NOW, and NOW themes inside THEN.
  const [crossIntoB, crossIntoA] = await Promise.all([
    periodAQuery
      ? retrieveEvidenceInRange(
          normalizedUserId,
          periodAQuery,
          timeRangeB,
          CROSS_RANGE_RETRIEVAL_LIMIT,
        )
      : Promise.resolve([]),
    periodBQuery
      ? retrieveEvidenceInRange(
          normalizedUserId,
          periodBQuery,
          timeRangeA,
          CROSS_RANGE_RETRIEVAL_LIMIT,
        )
      : Promise.resolve([]),
  ]);

  periodA.crossPeriodMatches = dedupeMatches(crossIntoB);
  periodB.crossPeriodMatches = dedupeMatches(crossIntoA);

  if (periodA.usableEntryCount < COMPARISON_MIN_USABLE_ENTRIES_PER_RANGE) {
    throw new ThenVsNowComparisonBlockedError(
      `Period A has ${periodA.usableEntryCount} usable entries; need at least ${COMPARISON_MIN_USABLE_ENTRIES_PER_RANGE} entries with ${MIN_USABLE_LEDGER_TEXT_CHARS}+ characters.`,
    );
  }
  if (periodB.usableEntryCount < COMPARISON_MIN_USABLE_ENTRIES_PER_RANGE) {
    throw new ThenVsNowComparisonBlockedError(
      `Period B has ${periodB.usableEntryCount} usable entries; need at least ${COMPARISON_MIN_USABLE_ENTRIES_PER_RANGE} entries with ${MIN_USABLE_LEDGER_TEXT_CHARS}+ characters.`,
    );
  }

  const evidencePool = dedupeMatches([
    ...periodA.entries,
    ...periodB.entries,
    ...periodA.clusterMatches,
    ...periodB.clusterMatches,
    ...periodA.crossPeriodMatches,
    ...periodB.crossPeriodMatches,
  ]);
  const allowedEntryIds = new Set(evidencePool.map((match) => match.entryId));

  const userPrompt = `THEN PERIOD (${periodA.from} → ${periodA.to}):
${buildEntriesBlock("THEN intra-cluster", periodA.clusterMatches)}

Cross-period matches surfaced from THEN representative query against NOW:
${buildEntriesBlock("THEN→NOW cross", periodA.crossPeriodMatches)}

NOW PERIOD (${periodB.from} → ${periodB.to}):
${buildEntriesBlock("NOW intra-cluster", periodB.clusterMatches)}

Cross-period matches surfaced from NOW representative query against THEN:
${buildEntriesBlock("NOW→THEN cross", periodB.crossPeriodMatches)}

Write a then-vs-now evolution view grounded only in the entries above.
Cite entryId values exactly as listed. Prefer "Changed" or "Softened" when stances diverge across periods.`;

  const openai = getOpenAIClient();
  const completion = await openai.chat.completions.create({
    model: COMPARISON_MODEL,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "then_vs_now_comparison",
        strict: true,
        schema: COMPARISON_JSON_SCHEMA,
      },
    },
    temperature: 0.25,
    messages: [
      { role: "system", content: COMPARISON_ENGINE_SYSTEM_PROMPT },
      { role: "user", content: userPrompt },
    ],
  });

  const content = completion.choices[0]?.message?.content;
  if (!content) {
    throw new Error("No then-vs-now comparison returned from model.");
  }

  const parsed = parseComparisonResponse(content, allowedEntryIds);

  return {
    ...parsed,
    periodA,
    periodB,
  };
}
