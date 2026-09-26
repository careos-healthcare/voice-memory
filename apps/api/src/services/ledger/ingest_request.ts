export interface LedgerIngestRequest {
  entryId: string;
  transcript: string;
}

/** Reads a single journal transcript from a ledger ingest body. */
export function parseLedgerIngestBody(value: unknown): LedgerIngestRequest | null {
  if (!value || typeof value !== "object") return null;
  const body = value as { entryId?: unknown; transcript?: unknown; rawText?: unknown };
  const entryId = typeof body.entryId === "string" ? body.entryId.trim() : "";
  const transcriptSource =
    typeof body.transcript === "string" ? body.transcript : body.rawText;
  const transcript =
    typeof transcriptSource === "string" ? transcriptSource.trim() : "";
  if (!entryId || !transcript) return null;
  return { entryId, transcript };
}
