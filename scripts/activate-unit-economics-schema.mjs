#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import pg from "pg";

const { Client } = pg;
const databaseUrl = process.env.DATABASE_URL?.trim();
if (!databaseUrl) {
  console.error("Unit economics migration failed: DATABASE_URL is required.");
  process.exit(1);
}

const expected = {
  tables: [
    "ue_pricing_versions",
    "ue_price_lines",
    "ue_usage_ledger",
    "ue_daily_subject_rollups",
    "ue_threshold_breaches",
  ],
  functions: ["ue_dimensions_are_safe", "ue_reject_source_mutation"],
  triggers: [
    "ue_pricing_versions_immutable",
    "ue_price_lines_immutable",
    "ue_usage_ledger_immutable",
    "ue_threshold_breaches_immutable",
  ],
  indexes: [
    "ue_pricing_versions_effective_from_idx",
    "ue_usage_ledger_subject_day_idx",
    "ue_usage_ledger_day_category_idx",
    "ue_usage_ledger_day_subject_idx",
    "ue_daily_subject_rollups_day_idx",
    "ue_threshold_breaches_subject_day_idx",
  ],
};

const client = new Client({ connectionString: databaseUrl });
try {
  const sql = await readFile(
    path.join(process.cwd(), "docs/sql/004_unit_economics.sql"),
    "utf8",
  );
  await client.connect();
  await client.query("BEGIN");
  await client.query(sql);

  const tables = await client.query(
      `SELECT tablename AS name FROM pg_tables
       WHERE schemaname = current_schema() AND tablename = ANY($1::text[])`,
      [expected.tables],
    );
  const functions = await client.query(
      `SELECT DISTINCT p.proname AS name
       FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = current_schema() AND p.proname = ANY($1::text[])`,
      [expected.functions],
    );
  const triggers = await client.query(
      `SELECT DISTINCT t.tgname AS name
       FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = current_schema() AND NOT t.tgisinternal
         AND t.tgname = ANY($1::text[])`,
      [expected.triggers],
    );
  const indexes = await client.query(
      `SELECT indexname AS name FROM pg_indexes
       WHERE schemaname = current_schema() AND indexname = ANY($1::text[])`,
      [expected.indexes],
    );
  const observed = { tables: tables.rows, functions: functions.rows, triggers: triggers.rows, indexes: indexes.rows };
  const missing = Object.fromEntries(
    Object.entries(expected).map(([kind, names]) => {
      const found = new Set(observed[kind].map((row) => row.name));
      return [kind, names.filter((name) => !found.has(name))];
    }),
  );
  if (Object.values(missing).some((names) => names.length > 0)) {
    throw new Error("schema verification incomplete");
  }
  await client.query("COMMIT");
  console.log(JSON.stringify({
    ok: true,
    verified: Object.fromEntries(Object.entries(expected).map(([kind, names]) => [kind, names.length])),
  }));
} catch {
  try {
    await client.query("ROLLBACK");
  } catch {
    // Connection may have failed before a transaction began.
  }
  console.error("Unit economics migration failed: schema was not activated completely.");
  process.exitCode = 1;
} finally {
  await client.end().catch(() => undefined);
}
