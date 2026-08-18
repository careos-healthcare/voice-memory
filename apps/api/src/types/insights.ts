/**
 * Evidence Method insight taxonomy — API entry point.
 * Canonical definitions live in `packages/shared/types/insights.ts`.
 */
export type {
  ArchiveInsightKind,
  EvidenceBackedInsightPayload,
  FactLedgerRow,
  PatternMatchConfidenceBand,
} from "../../types/insights";

export {
  ARCHIVE_INSIGHT_KINDS,
  FACT_LEDGER_EMBEDDING_DIMENSIONS,
  isArchiveInsightKind,
  isPatternMatchConfidenceBand,
  PATTERN_MATCH_CONFIDENCE_BANDS,
} from "../../types/insights";
