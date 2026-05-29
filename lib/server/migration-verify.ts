import { AUTH_SYNC_SCHEMA_STATEMENTS, dbQuery, hasDatabaseUrl } from "@/lib/server/db";
import { REQUIRED_INDEXES, REQUIRED_TABLES } from "@/lib/server/migration-manifest";

export interface MigrationVerifyResult {
  ok: boolean;
  skipped: boolean;
  missingTables: string[];
  missingIndexes: string[];
  errors: string[];
}

export async function verifyMigrations(): Promise<MigrationVerifyResult> {
  if (!hasDatabaseUrl()) {
    return {
      ok: false,
      skipped: true,
      missingTables: [...REQUIRED_TABLES],
      missingIndexes: REQUIRED_INDEXES.map((i) => i.index),
      errors: ["DATABASE_URL not set — cannot verify migrations."],
    };
  }

  const missingTables: string[] = [];
  const missingIndexes: string[] = [];
  const errors: string[] = [];

  try {
    await dbQuery("SELECT 1");
    for (const statement of AUTH_SYNC_SCHEMA_STATEMENTS) {
      await dbQuery(statement);
    }

    for (const table of REQUIRED_TABLES) {
      const result = await dbQuery<{ regclass: string | null }>(
        `SELECT to_regclass($1::text) AS regclass`,
        [`public.${table}`],
      );
      if (!result.rows[0]?.regclass) missingTables.push(table);
    }

    for (const { table, index } of REQUIRED_INDEXES) {
      const result = await dbQuery<{ exists: boolean }>(
        `SELECT EXISTS (
           SELECT 1 FROM pg_indexes
           WHERE schemaname = 'public' AND tablename = $1 AND indexname = $2
         ) AS exists`,
        [table, index],
      );
      if (!result.rows[0]?.exists) missingIndexes.push(index);
    }
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
  }

  return {
    ok: missingTables.length === 0 && missingIndexes.length === 0 && errors.length === 0,
    skipped: false,
    missingTables,
    missingIndexes,
    errors,
  };
}
