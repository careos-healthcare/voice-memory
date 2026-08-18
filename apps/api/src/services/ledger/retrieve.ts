import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { embedText, toPgVectorLiteral } from "@/lib/ledger/embeddings";

export interface EvidenceMatch {
  entryId: string;
  rawText: string;
  createdAt: string;
}

export interface EvidenceMatchScored extends EvidenceMatch {
  /** Cosine distance from query embedding (lower = closer). */
  distance: number;
}

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to retrieve fact ledger entries.");
  }
}

/**
 * Embeds `queryText` and returns the closest `fact_ledger` rows for `userId`
 * ordered by cosine distance (`<=>`).
 */
export async function retrieveEvidence(
  userId: string,
  queryText: string,
  limit = 5,
): Promise<EvidenceMatch[]> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  const normalizedQuery = queryText.trim();

  if (!normalizedUserId) {
    throw new Error("userId is required for evidence retrieval.");
  }
  if (!normalizedQuery) {
    throw new Error("queryText is required for evidence retrieval.");
  }
  if (limit < 1) {
    throw new Error("limit must be at least 1.");
  }

  const queryEmbedding = await embedText(normalizedQuery);
  const embeddingLiteral = toPgVectorLiteral(queryEmbedding);

  const result = await dbQuery<{
    entry_id: string;
    raw_text: string;
    created_at: Date | string;
  }>(
    `SELECT
       entry_id,
       raw_text,
       created_at
     FROM fact_ledger
     WHERE user_id = $1
     ORDER BY embedding <=> $2::vector
     LIMIT $3`,
    [normalizedUserId, embeddingLiteral, limit],
  );

  return result.rows.map((row) => ({
    entryId: row.entry_id,
    rawText: row.raw_text,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
  }));
}

/**
 * Like [retrieveEvidence] but includes pgvector cosine distance for ranking gates.
 */
export async function retrieveEvidenceScored(
  userId: string,
  queryText: string,
  limit = 8,
): Promise<EvidenceMatchScored[]> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  const normalizedQuery = queryText.trim();

  if (!normalizedUserId) {
    throw new Error("userId is required for evidence retrieval.");
  }
  if (!normalizedQuery) {
    throw new Error("queryText is required for evidence retrieval.");
  }
  if (limit < 1) {
    throw new Error("limit must be at least 1.");
  }

  const queryEmbedding = await embedText(normalizedQuery);
  const embeddingLiteral = toPgVectorLiteral(queryEmbedding);

  const result = await dbQuery<{
    entry_id: string;
    raw_text: string;
    created_at: Date | string;
    distance: number | string;
  }>(
    `SELECT
       entry_id,
       raw_text,
       created_at,
       embedding <=> $2::vector AS distance
     FROM fact_ledger
     WHERE user_id = $1
     ORDER BY embedding <=> $2::vector
     LIMIT $3`,
    [normalizedUserId, embeddingLiteral, limit],
  );

  return result.rows.map((row) => ({
    entryId: row.entry_id,
    rawText: row.raw_text,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
    distance: Number(row.distance),
  }));
}
