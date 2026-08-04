#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import pg from "pg";

const databaseUrl = process.env.DATABASE_URL?.trim();
if (!databaseUrl) {
  console.error("Monetized usage migration failed: DATABASE_URL is required.");
  process.exit(1);
}

const expectedTables = [
  "billing_entitlement_sources",
  "revenuecat_webhook_events",
  "usage_reservations",
];
const expectedIndexes = [
  "billing_entitlement_sources_status_idx",
  "usage_reservations_allowance_idx",
];
const client = new pg.Client({ connectionString: databaseUrl });

try {
  const sql = (
    await Promise.all(
      [
        "docs/sql/010_monetized_usage.sql",
        "docs/sql/011_monetized_usage_ledger_metadata.sql",
      ].map((relativePath) =>
        readFile(path.join(process.cwd(), relativePath), "utf8"),
      ),
    )
  ).join("\n");
  await client.connect();
  await client.query("BEGIN");
  await client.query(sql);
  const tables = await client.query(
    `SELECT tablename AS name FROM pg_tables
     WHERE schemaname = current_schema() AND tablename = ANY($1::text[])`,
    [expectedTables],
  );
  const indexes = await client.query(
    `SELECT indexname AS name FROM pg_indexes
     WHERE schemaname = current_schema() AND indexname = ANY($1::text[])`,
    [expectedIndexes],
  );
  const foundTables = new Set(tables.rows.map((row) => row.name));
  const foundIndexes = new Set(indexes.rows.map((row) => row.name));
  if (
    expectedTables.some((name) => !foundTables.has(name)) ||
    expectedIndexes.some((name) => !foundIndexes.has(name))
  ) {
    throw new Error("schema verification incomplete");
  }
  await client.query("COMMIT");
  console.log(JSON.stringify({
    ok: true,
    verified: {
      tables: expectedTables.length,
      indexes: expectedIndexes.length,
    },
  }));
} catch {
  await client.query("ROLLBACK").catch(() => undefined);
  console.error(
    "Monetized usage migration failed: schema was not activated completely.",
  );
  process.exitCode = 1;
} finally {
  await client.end().catch(() => undefined);
}
