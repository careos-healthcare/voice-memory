import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { embedText, toPgVectorLiteral } from "@/lib/ledger/embeddings";

export interface IngestTranscriptChunkResult {
  id: string;
  userId: string;
  entryId: string;
  rawText: string;
  createdAt: string;
}

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to ingest fact ledger entries.");
  }
}

/**
 * Embeds a transcript chunk and stores it in `fact_ledger`.
 */
export async function ingestTranscriptChunk(
  userId: string,
  entryId: string,
  transcriptText: string,
  createdAt?: string | null,
): Promise<IngestTranscriptChunkResult> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  const normalizedEntryId = entryId.trim();
  const rawText = transcriptText.trim();

  if (!normalizedUserId || !normalizedEntryId || !rawText) {
    throw new Error("userId, entryId, and transcriptText are required for ledger ingestion.");
  }

  const embedding = await embedText(rawText);
  const embeddingLiteral = toPgVectorLiteral(embedding);
  const storedAt = createdAt?.trim() || new Date().toISOString();

  const result = await dbQuery<{
    id: string | number;
    created_at: Date | string;
  }>(
    `INSERT INTO fact_ledger (user_id, entry_id, raw_text, embedding, created_at)
     VALUES ($1, $2, $3, $4::vector, $5::timestamptz)
     RETURNING id, created_at`,
    [normalizedUserId, normalizedEntryId, rawText, embeddingLiteral, storedAt],
  );

  const row = result.rows[0];
  if (!row) {
    throw new Error("Failed to insert fact ledger row.");
  }

  return {
    id: String(row.id),
    userId: normalizedUserId,
    entryId: normalizedEntryId,
    rawText,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
  };
}

/** Replaces any stored text for this entry, then stores the current transcript. */
export async function replaceJournalTranscript(
  userId: string,
  entryId: string,
  transcriptText: string,
  createdAt?: string | null,
): Promise<IngestTranscriptChunkResult> {
  assertPostgresAvailable();
  const normalizedUserId = userId.trim();
  const normalizedEntryId = entryId.trim();
  if (!normalizedUserId || !normalizedEntryId) {
    throw new Error("userId and entryId are required for ledger ingestion.");
  }

  await dbQuery(
    `DELETE FROM fact_ledger WHERE user_id = $1 AND entry_id = $2`,
    [normalizedUserId, normalizedEntryId],
  );
  return ingestTranscriptChunk(
    normalizedUserId,
    normalizedEntryId,
    transcriptText,
    createdAt,
  );
}

/** Removes one entry from the server ledger. Other entries stay. */
export async function deleteLedgerEntry(
  userId: string,
  entryId: string,
): Promise<number> {
  assertPostgresAvailable();
  const normalizedUserId = userId.trim();
  const normalizedEntryId = entryId.trim();
  if (!normalizedUserId || !normalizedEntryId) {
    throw new Error("userId and entryId are required to delete a ledger entry.");
  }
  const result = await dbQuery(
    `DELETE FROM fact_ledger WHERE user_id = $1 AND entry_id = $2`,
    [normalizedUserId, normalizedEntryId],
  );
  return result.rowCount ?? 0;
}
