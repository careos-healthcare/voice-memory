import "server-only";

import type { Pool, QueryResult, QueryResultRow } from "pg";
import { Pool as PgPool } from "pg";

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
] as const;

let lastConnectionError: string | null = null;

function logDbError(scope: string, error: unknown, extra: Record<string, unknown> = {}): void {
  const err = error instanceof Error ? error : new Error(String(error));
  console.error(
    "[VoiceMemory auth]",
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

function resolvePoolSsl(connectionString: string): boolean | { rejectUnauthorized: boolean } | undefined {
  const lower = connectionString.toLowerCase();
  if (lower.includes("sslmode=disable") || lower.includes("ssl=false")) {
    return undefined;
  }
  if (lower.includes("sslmode=require") || lower.includes("sslmode=verify-full")) {
    return { rejectUnauthorized: false };
  }
  if (
    lower.includes("neon.tech") ||
    lower.includes("supabase.co") ||
    lower.includes("pooler.supabase") ||
    lower.includes("vercel-storage.com") ||
    isProductionRuntime()
  ) {
    return { rejectUnauthorized: false };
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

export async function closeDatabasePool(): Promise<void> {
  if (!pool) return;
  await pool.end();
  pool = null;
  schemaReady = null;
}
