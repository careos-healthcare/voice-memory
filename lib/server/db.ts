import "server-only";

import fs from "node:fs";
import path from "node:path";

import type { Pool, QueryResult, QueryResultRow } from "pg";
import { Pool as PgPool } from "pg";

const SCHEMA_RELATIVE = "docs/sql/001_auth_sync_schema.sql";

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

export function getDatabasePool(): Pool {
  if (!hasDatabaseUrl()) {
    throw new Error("DATABASE_URL is not configured.");
  }

  if (!pool) {
    pool = new PgPool({
      connectionString: process.env.DATABASE_URL,
      max: 10,
      ssl: process.env.DATABASE_URL?.includes("sslmode=require")
        ? { rejectUnauthorized: false }
        : undefined,
    });
  }

  return pool;
}

async function runSchemaStatements(client: Pool): Promise<void> {
  const schemaPath = path.join(process.cwd(), SCHEMA_RELATIVE);
  const sql = fs.readFileSync(schemaPath, "utf8");
  const statements = sql
    .split(";")
    .map((statement) => statement.trim())
    .filter((statement) => statement.length > 0 && !statement.startsWith("--"));

  for (const statement of statements) {
    await client.query(statement);
  }
}

/** Idempotent table setup — safe on cold starts. */
export async function ensureDatabaseSchema(): Promise<void> {
  if (!hasDatabaseUrl()) return;
  if (!schemaReady) {
    schemaReady = runSchemaStatements(getDatabasePool()).catch((error) => {
      schemaReady = null;
      throw error;
    });
  }
  await schemaReady;
}

export async function dbQuery<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params: unknown[] = [],
): Promise<QueryResult<T>> {
  await ensureDatabaseSchema();
  return getDatabasePool().query<T>(text, params);
}

export async function closeDatabasePool(): Promise<void> {
  if (!pool) return;
  await pool.end();
  pool = null;
  schemaReady = null;
}
