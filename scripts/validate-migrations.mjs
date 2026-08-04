#!/usr/bin/env node
import { DATABASE_SCHEMA_STATEMENTS } from "../lib/server/db.ts";
import { REQUIRED_INDEXES, REQUIRED_TABLES } from "../lib/server/migration-manifest.ts";
import { verifyMigrations } from "../lib/server/migration-verify.ts";

const failures = [];

if (DATABASE_SCHEMA_STATEMENTS.length < 10) {
  failures.push("DATABASE_SCHEMA_STATEMENTS too short");
}

for (const table of REQUIRED_TABLES) {
  const found = DATABASE_SCHEMA_STATEMENTS.some((s) => s.includes(table));
  if (!found) failures.push(`schema statements missing table ${table}`);
}

if (!REQUIRED_INDEXES.length) failures.push("no required indexes defined");

const result = await verifyMigrations();
if (result.skipped) {
  console.warn(
    "validate-migrations: DATABASE_URL not set — structural checks only (tables defined in manifest)",
  );
} else if (!result.ok) {
  failures.push(
    ...result.missingTables.map((t) => `missing table ${t}`),
    ...result.missingIndexes.map((i) => `missing index ${i}`),
    ...result.errors,
  );
}

if (failures.length) {
  console.error("validate-migrations failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-migrations ok");
