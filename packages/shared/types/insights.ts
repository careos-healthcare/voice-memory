/**
 * Evidence Method — insight taxonomy shared by API routes and generators.
 */

export type ArchiveInsightKind =
  | "belief"
  | "beliefChange"
  | "theme"
  | "contradiction"
  | "blindSpot"
  | "chapter"
  | "weeklyStory"
  | "surprise"
  | "challenge"
  | "breakthrough";

export type PatternMatchConfidenceBand = "weak" | "emerging" | "solid" | "strong";

export const ARCHIVE_INSIGHT_KINDS = [
  "belief",
  "beliefChange",
  "theme",
  "contradiction",
  "blindSpot",
  "chapter",
  "weeklyStory",
  "surprise",
  "challenge",
  "breakthrough",
] as const satisfies readonly ArchiveInsightKind[];

export const PATTERN_MATCH_CONFIDENCE_BANDS = [
  "weak",
  "emerging",
  "solid",
  "strong",
] as const satisfies readonly PatternMatchConfidenceBand[];

export function isArchiveInsightKind(value: string): value is ArchiveInsightKind {
  return (ARCHIVE_INSIGHT_KINDS as readonly string[]).includes(value);
}

export function isPatternMatchConfidenceBand(
  value: string,
): value is PatternMatchConfidenceBand {
  return (PATTERN_MATCH_CONFIDENCE_BANDS as readonly string[]).includes(value);
}

/** Gemini text-embedding-004 / gemini-embedding-001 @ 768-d — see ledger constants. */
export const FACT_LEDGER_EMBEDDING_DIMENSIONS = 768;

export interface FactLedgerRow {
  id: string;
  userId: string;
  entryId: string;
  rawText: string;
  createdAt: string;
  /** When set, this row cites image-evidence caption metadata. */
  imageEvidenceId?: string;
  mimeType?: string;
}

export interface EvidenceBackedInsightPayload {
  insightText: string;
  confidenceBand: PatternMatchConfidenceBand;
  citedEntryIds: string[];
  kind?: ArchiveInsightKind;
}
