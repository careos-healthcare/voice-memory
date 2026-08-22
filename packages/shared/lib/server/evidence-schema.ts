/**
 * Evidence Method — Postgres schema (pgvector fact ledger).
 *
 * Runtime: bundled into [AUTH_SYNC_SCHEMA_STATEMENTS] in
 * `packages/shared/lib/server/db.ts` for idempotent cold starts.
 */

import { FACT_LEDGER_EMBEDDING_DIMENSIONS } from "@/types/insights";

export { FACT_LEDGER_EMBEDDING_DIMENSIONS };

/** pgvector extension + fact_ledger table and indexes. */
export const EVIDENCE_METHOD_SCHEMA_STATEMENTS = [
  `CREATE EXTENSION IF NOT EXISTS vector`,
  `CREATE TABLE IF NOT EXISTS fact_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  entry_id text NOT NULL,
  raw_text text NOT NULL,
  embedding vector(${FACT_LEDGER_EMBEDDING_DIMENSIONS}) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS fact_ledger_user_id_idx ON fact_ledger (user_id)`,
  `CREATE INDEX IF NOT EXISTS fact_ledger_entry_id_idx ON fact_ledger (entry_id)`,
  `CREATE INDEX IF NOT EXISTS fact_ledger_user_created_idx ON fact_ledger (user_id, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS fact_ledger_embedding_hnsw_idx ON fact_ledger USING hnsw (embedding vector_cosine_ops)`,
  `CREATE TABLE IF NOT EXISTS insight_corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  insight_id text NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS insight_corrections_user_insight_idx ON insight_corrections (user_id, insight_id)`,
  `CREATE INDEX IF NOT EXISTS insight_corrections_user_created_idx ON insight_corrections (user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS brain_dump_uploads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  entry_id text NOT NULL,
  duration_seconds integer NOT NULL,
  encrypted_bytes bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS brain_dump_uploads_user_created_idx ON brain_dump_uploads (user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS curiosity_notification_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  device_id text NOT NULL,
  hook_id text NOT NULL,
  query_text text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  cited_entry_ids text[] NOT NULL DEFAULT '{}',
  fire_at timestamptz NOT NULL,
  sent_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS curiosity_notification_queue_fire_idx ON curiosity_notification_queue (fire_at) WHERE sent_at IS NULL AND cancelled_at IS NULL`,
  `CREATE INDEX IF NOT EXISTS curiosity_notification_queue_user_idx ON curiosity_notification_queue (user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS curiosity_notification_surfaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  surface_key text NOT NULL,
  kind text NOT NULL,
  cited_entry_ids text[] NOT NULL DEFAULT '{}',
  surfaced_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, surface_key)
)`,
  `CREATE INDEX IF NOT EXISTS curiosity_notification_surfaces_user_idx ON curiosity_notification_surfaces (user_id, surfaced_at DESC)`,
] as const;

export const EVIDENCE_METHOD_REQUIRED_INDEXES = [
  { table: "fact_ledger", index: "fact_ledger_user_id_idx" },
  { table: "fact_ledger", index: "fact_ledger_entry_id_idx" },
  { table: "fact_ledger", index: "fact_ledger_embedding_hnsw_idx" },
  { table: "insight_corrections", index: "insight_corrections_user_insight_idx" },
] as const;
