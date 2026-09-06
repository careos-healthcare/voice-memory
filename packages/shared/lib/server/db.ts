import type { Pool, PoolClient, QueryResult, QueryResultRow } from "pg";
import { readFileSync } from "node:fs";
import { Pool as PgPool } from "pg";

import { EVIDENCE_METHOD_SCHEMA_STATEMENTS } from "@/lib/server/evidence-schema";

/** Bundled schema — must not rely on docs/ at runtime (Vercel serverless omits it). */
export const AUTH_SYNC_SCHEMA_STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS auth_codes (
  email text PRIMARY KEY,
  code_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS auth_codes_expires_at_idx ON auth_codes (expires_at)`,
  `CREATE TABLE IF NOT EXISTS sessions (
  token_hash text PRIMARY KEY,
  user_id text NOT NULL,
  email text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions (user_id)`,
  `CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions (expires_at)`,
  `CREATE TABLE IF NOT EXISTS sync_blobs (
  user_id text NOT NULL,
  blob_type text NOT NULL,
  blob_id text NOT NULL,
  encrypted_payload jsonb NOT NULL,
  updated_at timestamptz NOT NULL,
  PRIMARY KEY (user_id, blob_type, blob_id)
)`,
  `CREATE INDEX IF NOT EXISTS sync_blobs_user_updated_idx ON sync_blobs (user_id, updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS api_usage (
  subject_key text NOT NULL,
  day_key text NOT NULL,
  transcribe_count integer NOT NULL DEFAULT 0,
  analyze_count integer NOT NULL DEFAULT 0,
  atmosphere_count integer NOT NULL DEFAULT 0,
  attest_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, day_key)
)`,
  `CREATE TABLE IF NOT EXISTS api_minute_usage (
  subject_key text NOT NULL,
  endpoint text NOT NULL,
  minute_key text NOT NULL,
  request_count integer NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, endpoint, minute_key)
)`,
  `CREATE TABLE IF NOT EXISTS openai_daily_spend (
  subject_key text NOT NULL,
  day_key text NOT NULL,
  spend_micro_usd bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (subject_key, day_key)
)`,
  `CREATE TABLE IF NOT EXISTS billing_entitlements (
  user_id text PRIMARY KEY,
  stripe_customer_id text,
  stripe_subscription_id text,
  status text NOT NULL DEFAULT 'canceled',
  tier text NOT NULL DEFAULT 'free',
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE TABLE IF NOT EXISTS capture_attestations (
  token_jti text PRIMARY KEY,
  device_id text NOT NULL,
  ip_hash text NOT NULL,
  ua_hash text NOT NULL,
  issued_at timestamptz NOT NULL DEFAULT now(),
  use_count integer NOT NULL DEFAULT 0,
  max_uses integer NOT NULL DEFAULT 500
)`,
  `CREATE TABLE IF NOT EXISTS journal_entries (
  user_id text NOT NULL,
  entry_id text NOT NULL,
  payload jsonb NOT NULL,
  sync_status text NOT NULL DEFAULT 'synced',
  client_updated_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, entry_id)
)`,
  `CREATE INDEX IF NOT EXISTS journal_entries_user_updated_idx ON journal_entries (user_id, updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS resurfacing_events (
  id bigserial PRIMARY KEY,
  user_id text,
  subject_key text NOT NULL,
  event_name text NOT NULL,
  confidence_bucket text,
  phrase_key_hash text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS resurfacing_events_subject_created_idx ON resurfacing_events (subject_key, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS resurfacing_feedback (
  id bigserial PRIMARY KEY,
  user_id text NOT NULL,
  phrase_key_hash text NOT NULL,
  feedback_type text NOT NULL,
  feedback_weight integer NOT NULL,
  evidence_cluster_hash text,
  topic_hash text,
  person_hash text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS resurfacing_feedback_user_created_idx ON resurfacing_feedback (user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS stripe_webhook_events (
  event_id text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
)`,
  `ALTER TABLE api_usage ADD COLUMN IF NOT EXISTS atmosphere_count integer NOT NULL DEFAULT 0`,
  `ALTER TABLE api_usage ADD COLUMN IF NOT EXISTS attest_count integer NOT NULL DEFAULT 0`,
  `ALTER TABLE auth_codes ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0`,
  `CREATE TABLE IF NOT EXISTS mobile_push_devices (
  user_id text NOT NULL,
  device_id text PRIMARY KEY,
  platform text NOT NULL,
  fcm_token text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS mobile_push_devices_user_id_idx ON mobile_push_devices (user_id)`,
  `CREATE INDEX IF NOT EXISTS mobile_push_devices_updated_at_idx ON mobile_push_devices (updated_at DESC)`,
  `CREATE TABLE IF NOT EXISTS sync_change_log (
  user_id text NOT NULL,
  sequence bigint NOT NULL,
  blob_type text NOT NULL,
  blob_id text NOT NULL,
  change_kind text NOT NULL,
  updated_at timestamptz NOT NULL,
  tombstone boolean NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, sequence)
)`,
  `CREATE INDEX IF NOT EXISTS sync_change_log_user_sequence_idx ON sync_change_log (user_id, sequence DESC)`,
  `CREATE TABLE IF NOT EXISTS user_relationships (
  id text PRIMARY KEY,
  client_id text NOT NULL,
  professional_id text NOT NULL,
  relationship_type text NOT NULL DEFAULT 'professional',
  consent_status text NOT NULL DEFAULT 'pending',
  agreed_scope jsonb NOT NULL DEFAULT '{}'::jsonb,
  active_consent_token_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS user_relationships_client_idx ON user_relationships (client_id)`,
  `CREATE INDEX IF NOT EXISTS user_relationships_professional_idx ON user_relationships (professional_id)`,
  `CREATE INDEX IF NOT EXISTS user_relationships_status_idx ON user_relationships (consent_status)`,
  // Consent grant registry and revocation list. Rows are never deleted and
  // never expire: a revocation record has to outlive the token it revokes, or
  // the access it withdrew comes back. Do not add a cleanup job or a retention
  // policy to this table — see packages/shared/lib/server/consent-revocation-store.ts.
  `CREATE TABLE IF NOT EXISTS consent_grants (
  token_id text PRIMARY KEY,
  grant_kind text NOT NULL,
  subject_account_id text NOT NULL,
  party_id text NOT NULL DEFAULT '',
  relationship_id text,
  issued_at timestamptz,
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_by text,
  revocation_reason text,
  permissions jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE INDEX IF NOT EXISTS consent_grants_subject_idx ON consent_grants (subject_account_id)`,
  `CREATE INDEX IF NOT EXISTS consent_grants_revoked_idx ON consent_grants (revoked_at)`,
  `CREATE TABLE IF NOT EXISTS caregiver_redemption_codes (
  id text PRIMARY KEY,
  token_id text NOT NULL REFERENCES consent_grants (token_id),
  reference text NOT NULL,
  link_token_hash text NOT NULL,
  manual_code_hash text NOT NULL,
  manual_code_attempts integer NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  redeemed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
)`,
  `CREATE UNIQUE INDEX IF NOT EXISTS caregiver_redemption_codes_reference_idx ON caregiver_redemption_codes (reference)`,
  `CREATE INDEX IF NOT EXISTS caregiver_redemption_codes_link_idx ON caregiver_redemption_codes (link_token_hash)`,
  `CREATE INDEX IF NOT EXISTS caregiver_redemption_codes_manual_idx ON caregiver_redemption_codes (manual_code_hash)`,
  `CREATE INDEX IF NOT EXISTS caregiver_redemption_codes_token_idx ON caregiver_redemption_codes (token_id)`,
  ...EVIDENCE_METHOD_SCHEMA_STATEMENTS,
] as const;

let lastConnectionError: string | null = null;

function logDbError(scope: string, error: unknown, extra: Record<string, unknown> = {}): void {
  const err = error instanceof Error ? error : new Error(String(error));
  console.error(
    "[ArchiveMe auth]",
    JSON.stringify({
      route: scope,
      message: err.message,
      stack: err.stack ?? null,
      poolInitialized: pool !== null,
      databaseUrlPresent: hasDatabaseUrl(),
      ...extra,
    }),
  );
}

let pool: Pool | null = null;
let schemaReady: Promise<void> | null = null;

export function hasDatabaseUrl(): boolean {
  return Boolean(process.env.DATABASE_URL?.trim());
}

export function shouldUsePostgresStorage(): boolean {
  return hasDatabaseUrl();
}

export function isProductionRuntime(): boolean {
  return process.env.NODE_ENV === "production";
}

/** Production must not fall back to local filesystem when DATABASE_URL is set. */
export function shouldUseFilesystemStorage(): boolean {
  if (shouldUsePostgresStorage()) return false;
  return !isProductionRuntime();
}

function resolvePoolSsl(connectionString: string): boolean | { rejectUnauthorized: boolean; ca?: string } | undefined {
  const lower = connectionString.toLowerCase();
  const explicitInsecure = process.env.DATABASE_SSL_REJECT_UNAUTHORIZED === "false";
  if (lower.includes("sslmode=disable") || lower.includes("ssl=false")) {
    if (isProductionRuntime()) {
      throw new Error(
        "Production DATABASE_URL disables TLS — set sslmode=require and DATABASE_SSL_REJECT_UNAUTHORIZED=true.",
      );
    }
    console.warn("[ArchiveMe db] WARNING: PostgreSQL TLS disabled for development.");
    return undefined;
  }

  const caBundlePath = process.env.DATABASE_SSL_CA_BUNDLE?.trim();
  const caBundle = caBundlePath ? readFileSync(caBundlePath, "utf8") : undefined;

  if (lower.includes("sslmode=verify-full") || lower.includes("sslmode=verify-ca")) {
    return { rejectUnauthorized: true, ...(caBundle ? { ca: caBundle } : {}) };
  }

  if (lower.includes("sslmode=require") || isProductionRuntime()) {
    if (explicitInsecure) {
      if (isProductionRuntime()) {
        throw new Error(
          "DATABASE_SSL_REJECT_UNAUTHORIZED=false is forbidden in production.",
        );
      }
      console.warn(
        "[ArchiveMe db] WARNING: PostgreSQL certificate verification disabled (development override).",
      );
      return { rejectUnauthorized: false };
    }
    return { rejectUnauthorized: true, ...(caBundle ? { ca: caBundle } : {}) };
  }

  return undefined;
}

export function isDatabasePoolInitialized(): boolean {
  return pool !== null;
}

export function getDatabaseDiagnostics(): {
  poolInitialized: boolean;
  schemaReadyPending: boolean;
  lastConnectionError: string | null;
} {
  return {
    poolInitialized: pool !== null,
    schemaReadyPending: schemaReady !== null,
    lastConnectionError,
  };
}

export function getDatabasePool(): Pool {
  if (!hasDatabaseUrl()) {
    throw new Error("DATABASE_URL is not configured.");
  }

  if (!pool) {
    const connectionString = process.env.DATABASE_URL!.trim();
    pool = new PgPool({
      connectionString,
      max: 5,
      idleTimeoutMillis: 10_000,
      connectionTimeoutMillis: 10_000,
      ssl: resolvePoolSsl(connectionString),
    });
    pool.on("error", (error) => {
      lastConnectionError = error.message;
      logDbError("db/pool", error, { event: "idle_client_error" });
    });
  }

  return pool;
}

async function runSchemaStatements(client: Pool): Promise<void> {
  for (const statement of AUTH_SYNC_SCHEMA_STATEMENTS) {
    await client.query(statement);
  }
}

/** Idempotent table setup — safe on cold starts. */
export async function ensureDatabaseSchema(): Promise<void> {
  if (!hasDatabaseUrl()) return;
  if (!schemaReady) {
    schemaReady = runSchemaStatements(getDatabasePool())
      .then(() => {
        lastConnectionError = null;
      })
      .catch((error) => {
        schemaReady = null;
        lastConnectionError = error instanceof Error ? error.message : String(error);
        logDbError("db/schema", error, { statements: AUTH_SYNC_SCHEMA_STATEMENTS.length });
        throw error;
      });
  }
  await schemaReady;
}

export async function dbQuery<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params: unknown[] = [],
): Promise<QueryResult<T>> {
  try {
    await ensureDatabaseSchema();
    return await getDatabasePool().query<T>(text, params);
  } catch (error) {
    lastConnectionError = error instanceof Error ? error.message : String(error);
    logDbError("db/query", error, { queryPrefix: text.slice(0, 48) });
    throw error;
  }
}

export async function withDbTransaction<T>(
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  await ensureDatabaseSchema();
  const client = await getDatabasePool().connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function closeDatabasePool(): Promise<void> {
  if (!pool) return;
  await pool.end();
  pool = null;
  schemaReady = null;
}
