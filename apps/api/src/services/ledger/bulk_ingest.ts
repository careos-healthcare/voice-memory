import "server-only";

import type { PoolClient, QueryResultRow } from "pg";

import { dbQuery, shouldUsePostgresStorage, withDbTransaction } from "@/lib/server/db";
import { embedText, toPgVectorLiteral } from "@/lib/ledger/embeddings";

import type { IngestTranscriptChunkResult } from "./ingest";

export interface BulkIngestChunkInput {
  entryId: string;
  rawText: string;
  createdAt?: Date;
}

export interface BulkIngestFailure {
  entryId: string;
  error: string;
}

export interface BulkIngestResult {
  imported: IngestTranscriptChunkResult[];
  failed: BulkIngestFailure[];
}

const EMBEDDING_BATCH_SIZE = 8;

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to ingest fact ledger entries.");
  }
}

function parseCreatedAt(value: string | undefined): Date | undefined {
  if (!value?.trim()) return undefined;
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) return undefined;
  return new Date(parsed);
}

export function normalizeBulkIngestChunk(input: {
  entryId?: string;
  rawText?: string;
  createdAt?: string;
}): BulkIngestChunkInput | null {
  const entryId = input.entryId?.trim() ?? "";
  const rawText = input.rawText?.trim() ?? "";
  if (!entryId || !rawText) return null;

  return {
    entryId,
    rawText,
    createdAt: parseCreatedAt(input.createdAt),
  };
}

async function insertFactLedgerRow(
  client: PoolClient,
  userId: string,
  chunk: BulkIngestChunkInput,
  embedding: readonly number[],
): Promise<IngestTranscriptChunkResult> {
  const embeddingLiteral = toPgVectorLiteral(embedding);
  const createdAt = chunk.createdAt ?? new Date();

  const result = await client.query<QueryResultRow>(
    `INSERT INTO fact_ledger (user_id, entry_id, raw_text, embedding, created_at)
     VALUES ($1, $2, $3, $4::vector, $5::timestamptz)
     RETURNING id, created_at`,
    [userId, chunk.entryId, chunk.rawText, embeddingLiteral, createdAt.toISOString()],
  );

  const row = result.rows[0];
  if (!row) {
    throw new Error(`Failed to insert fact ledger row for entry ${chunk.entryId}.`);
  }

  return {
    id: String(row.id),
    userId,
    entryId: chunk.entryId,
    rawText: chunk.rawText,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
  };
}

/**
 * Embeds chunks in parallel batches, then inserts each batch inside a DB transaction
 * so historical `created_at` values are preserved on `fact_ledger`.
 */
export async function bulkIngestHistoricalChunks(
  userId: string,
  chunks: BulkIngestChunkInput[],
): Promise<BulkIngestResult> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required for bulk ledger ingestion.");
  }
  if (chunks.length === 0) {
    return { imported: [], failed: [] };
  }

  const imported: IngestTranscriptChunkResult[] = [];
  const failed: BulkIngestFailure[] = [];

  for (let index = 0; index < chunks.length; index += EMBEDDING_BATCH_SIZE) {
    const batch = chunks.slice(index, index + EMBEDDING_BATCH_SIZE);

    const embedded = await Promise.all(
      batch.map(async (chunk) => {
        try {
          const embedding = await embedText(chunk.rawText);
          return { ok: true as const, chunk, embedding };
        } catch (error) {
          return {
            ok: false as const,
            chunk,
            error: error instanceof Error ? error.message : "Embedding failed.",
          };
        }
      }),
    );

    for (const result of embedded) {
      if (!result.ok) {
        failed.push({ entryId: result.chunk.entryId, error: result.error });
      }
    }

    const ready = embedded.filter(
      (result): result is { ok: true; chunk: BulkIngestChunkInput; embedding: number[] } =>
        result.ok,
    );
    if (ready.length === 0) continue;

    try {
      const inserted = await withDbTransaction(async (client) => {
        const rows: IngestTranscriptChunkResult[] = [];
        for (const row of ready) {
          rows.push(
            await insertFactLedgerRow(client, normalizedUserId, row.chunk, row.embedding),
          );
        }
        return rows;
      });
      imported.push(...inserted);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Bulk insert failed.";
      for (const row of ready) {
        failed.push({ entryId: row.chunk.entryId, error: message });
      }
    }
  }

  return { imported, failed };
}

/** Picks the newest imported chunk (by created_at) for cold-start insight context. */
export function pickLatestImportedChunkText(
  imported: readonly IngestTranscriptChunkResult[],
): string {
  if (imported.length === 0) return "";

  const sorted = [...imported].sort(
    (left, right) =>
      Date.parse(right.createdAt) - Date.parse(left.createdAt),
  );
  return sorted[0]?.rawText.trim() ?? "";
}

/** Returns whether a user already has ledger rows (for idempotent cold-start guards). */
export async function countFactLedgerRowsForUser(userId: string): Promise<number> {
  assertPostgresAvailable();
  const result = await dbQuery<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM fact_ledger WHERE user_id = $1`,
    [userId.trim()],
  );
  return Number(result.rows[0]?.count ?? 0);
}
