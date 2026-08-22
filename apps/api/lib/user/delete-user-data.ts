import "server-only";

import type { PoolClient } from "pg";

import { hashUserIdForAudit } from "@/lib/server/auth-crypto";
import { shouldUsePostgresStorage, withDbTransaction } from "@/lib/server/db";
import { logServerEvent } from "@/lib/server/structured-log";

import {
  getUserAudioStorageProvider,
  type UserAudioStorageProvider,
} from "./user-audio-storage";

export interface CompleteUserDataDeletionResult {
  ok: boolean;
  deleted: {
    relational_data: boolean;
    vectors: boolean;
    audio_files: boolean;
  };
  counts: {
    relational_rows: number;
    vector_rows: number;
    audio_objects: number;
  };
}

interface RelationalDeleteCounts {
  vectorRows: number;
  relationalRows: number;
}

async function deleteRelationalUserDataInTransaction(
  client: PoolClient,
  userId: string,
  email: string,
): Promise<RelationalDeleteCounts> {
  const subjectKey = `user:${userId}`;
  const normalizedEmail = email.trim().toLowerCase();
  let relationalRows = 0;

  const factLedger = await client.query(
    `DELETE FROM fact_ledger WHERE user_id = $1`,
    [userId],
  );
  const vectorRows = factLedger.rowCount ?? 0;
  relationalRows += vectorRows;

  const tables: Array<{ sql: string; params: unknown[] }> = [
    { sql: `DELETE FROM journal_entries WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM sync_blobs WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM sync_change_log WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM mobile_push_devices WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM curiosity_notification_queue WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM curiosity_notification_surfaces WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM resurfacing_events WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM resurfacing_feedback WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM sessions WHERE user_id = $1`, params: [userId] },
    { sql: `DELETE FROM billing_entitlements WHERE user_id = $1`, params: [userId] },
    {
      sql: `DELETE FROM user_relationships WHERE client_id = $1 OR professional_id = $1`,
      params: [userId],
    },
    { sql: `DELETE FROM api_usage WHERE subject_key = $1`, params: [subjectKey] },
    { sql: `DELETE FROM api_minute_usage WHERE subject_key = $1`, params: [subjectKey] },
    { sql: `DELETE FROM openai_daily_spend WHERE subject_key = $1`, params: [subjectKey] },
  ];

  if (normalizedEmail) {
    tables.push({
      sql: `DELETE FROM auth_codes WHERE email = $1`,
      params: [normalizedEmail],
    });
  }

  for (const statement of tables) {
    const result = await client.query(statement.sql, statement.params);
    relationalRows += result.rowCount ?? 0;
  }

  return { vectorRows, relationalRows };
}

/**
 * Guarantees a complete user data wipe across Postgres (transactional),
 * pgvector fact ledger rows, and object storage audio prefixes.
 */
export async function deleteUserDataCompletely(
  userId: string,
  email: string,
  options?: {
    audioStorage?: UserAudioStorageProvider;
  },
): Promise<CompleteUserDataDeletionResult> {
  if (!userId.trim()) {
    throw new Error("userId is required for complete data deletion.");
  }

  if (!shouldUsePostgresStorage()) {
    throw new Error("DATABASE_URL is required for complete user data deletion.");
  }

  const { vectorRows, relationalRows } = await withDbTransaction((client) =>
    deleteRelationalUserDataInTransaction(client, userId, email),
  );

  const audioStorage = options?.audioStorage ?? getUserAudioStorageProvider();
  const audioResult = await audioStorage.deleteUserAudioPrefix(userId);

  const deleted = {
    relational_data: true,
    vectors: true,
    audio_files: audioResult.ok,
  };
  const ok = deleted.relational_data && deleted.vectors && deleted.audio_files;

  logServerEvent("user_data_wipe", {
    userHash: hashUserIdForAudit(userId),
    ok,
    relationalRows,
    vectorRows,
    audioObjects: audioResult.deletedCount,
    audioPrefix: audioResult.prefix,
  });

  return {
    ok,
    deleted,
    counts: {
      relational_rows: relationalRows,
      vector_rows: vectorRows,
      audio_objects: audioResult.deletedCount,
    },
  };
}
