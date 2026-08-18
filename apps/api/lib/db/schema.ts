/**
 * Evidence Method database schema — re-exported for apps/api consumers.
 *
 * Canonical SQL lives in `packages/shared/lib/server/evidence-schema.ts`
 * and is applied at runtime via `AUTH_SYNC_SCHEMA_STATEMENTS`.
 */
export {
  EVIDENCE_METHOD_REQUIRED_INDEXES,
  EVIDENCE_METHOD_SCHEMA_STATEMENTS,
  FACT_LEDGER_EMBEDDING_DIMENSIONS,
} from "@/lib/server/evidence-schema";

export type {
  ArchiveInsightKind,
  EvidenceBackedInsightPayload,
  FactLedgerRow,
  PatternMatchConfidenceBand,
} from "@/types/insights";

export {
  ARCHIVE_INSIGHT_KINDS,
  isArchiveInsightKind,
  isPatternMatchConfidenceBand,
  PATTERN_MATCH_CONFIDENCE_BANDS,
} from "@/types/insights";
