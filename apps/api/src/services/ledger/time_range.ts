import "server-only";

import { dbQuery, shouldUsePostgresStorage } from "@/lib/server/db";
import { embedText, toPgVectorLiteral } from "@/lib/ledger/embeddings";

import type { EvidenceMatch, EvidenceMatchScored } from "./retrieve";

export interface InsightTimeRange {
  from: Date;
  to: Date;
}

function assertPostgresAvailable(): void {
  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required to query fact ledger time ranges.");
  }
}

function normalizeRange(range: InsightTimeRange): { from: Date; to: Date } {
  const from = range.from;
  const to = range.to;
  if (!(from instanceof Date) || Number.isNaN(from.getTime())) {
    throw new Error("timeRange.from must be a valid Date.");
  }
  if (!(to instanceof Date) || Number.isNaN(to.getTime())) {
    throw new Error("timeRange.to must be a valid Date.");
  }
  if (from.getTime() > to.getTime()) {
    throw new Error("timeRange.from must be before or equal to timeRange.to.");
  }
  return { from, to };
}

function mapEvidenceRow(row: {
  entry_id: string;
  raw_text: string;
  created_at: Date | string;
}): EvidenceMatch {
  return {
    entryId: row.entry_id,
    rawText: row.raw_text,
    createdAt:
      row.created_at instanceof Date
        ? row.created_at.toISOString()
        : String(row.created_at),
  };
}

/**
 * Lists fact_ledger rows for a user within an inclusive created_at window.
 */
export async function listFactLedgerEntriesInRange(
  userId: string,
  range: InsightTimeRange,
  limit = 40,
): Promise<EvidenceMatch[]> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required for time-range ledger queries.");
  }
  if (limit < 1) {
    throw new Error("limit must be at least 1.");
  }

  const { from, to } = normalizeRange(range);

  const result = await dbQuery<{
    entry_id: string;
    raw_text: string;
    created_at: Date | string;
  }>(
    `SELECT entry_id, raw_text, created_at
     FROM fact_ledger
     WHERE user_id = $1
       AND created_at >= $2
       AND created_at <= $3
     ORDER BY created_at ASC
     LIMIT $4`,
    [normalizedUserId, from.toISOString(), to.toISOString(), limit],
  );

  return result.rows.map(mapEvidenceRow);
}

export async function countFactLedgerEntriesInRange(
  userId: string,
  range: InsightTimeRange,
): Promise<number> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required for time-range ledger counts.");
  }

  const { from, to } = normalizeRange(range);

  const result = await dbQuery<{ count: string }>(
    `SELECT COUNT(*)::text AS count
     FROM fact_ledger
     WHERE user_id = $1
       AND created_at >= $2
       AND created_at <= $3`,
    [normalizedUserId, from.toISOString(), to.toISOString()],
  );

  return Number(result.rows[0]?.count ?? 0);
}

/**
 * Vector retrieval scoped to a created_at window — used for cross-period clustering.
 */
export async function retrieveEvidenceInRange(
  userId: string,
  queryText: string,
  range: InsightTimeRange,
  limit = 8,
): Promise<EvidenceMatchScored[]> {
  assertPostgresAvailable();

  const normalizedUserId = userId.trim();
  const normalizedQuery = queryText.trim();
  if (!normalizedUserId) {
    throw new Error("userId is required for time-range evidence retrieval.");
  }
  if (!normalizedQuery) {
    throw new Error("queryText is required for time-range evidence retrieval.");
  }
  if (limit < 1) {
    throw new Error("limit must be at least 1.");
  }

  const { from, to } = normalizeRange(range);
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
       AND created_at >= $3
       AND created_at <= $4
     ORDER BY embedding <=> $2::vector
     LIMIT $5`,
    [
      normalizedUserId,
      embeddingLiteral,
      from.toISOString(),
      to.toISOString(),
      limit,
    ],
  );

  return result.rows.map((row) => ({
    ...mapEvidenceRow(row),
    distance: Number(row.distance),
  }));
}

/**
 * Builds a representative query string for vector clustering within a period.
 */
export function buildRangeRepresentativeQuery(
  entries: readonly EvidenceMatch[],
  maxEntries = 5,
): string {
  if (entries.length === 0) return "";

  const snippets = entries
    .slice(-maxEntries)
    .map((entry) => entry.rawText.trim())
    .filter(Boolean);

  return snippets.join("\n\n").slice(0, 2_500);
}
