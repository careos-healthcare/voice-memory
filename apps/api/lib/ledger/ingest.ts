import "server-only";

import {
  ingestTranscriptChunk,
  type IngestTranscriptChunkResult,
} from "@/src/services/ledger/ingest";

export type { IngestTranscriptChunkResult };
export { ingestTranscriptChunk };

/** @deprecated Use `ingestTranscriptChunk` from `@/src/services/ledger/ingest`. */
export interface IngestFactLedgerInput {
  userId: string;
  entryId: string;
  rawText: string;
}

/** @deprecated Use `IngestTranscriptChunkResult`. */
export type IngestFactLedgerResult = IngestTranscriptChunkResult;

/** @deprecated Use `ingestTranscriptChunk`. */
export async function ingestFactLedgerChunk(
  input: IngestFactLedgerInput,
): Promise<IngestFactLedgerResult> {
  return ingestTranscriptChunk(input.userId, input.entryId, input.rawText);
}
