#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "packages/shared/lib/server/db.ts",
  "packages/shared/lib/server/auth-diagnostics.ts",
  "packages/shared/lib/server/auth-store-postgres.ts",
  "packages/shared/lib/server/sync-store-postgres.ts",
  "docs/sql/001_auth_sync_schema.sql",
  "packages/shared/lib/server/auth-storage.ts",
  "packages/shared/lib/server/auth-store.ts",
  "packages/shared/lib/server/sync-store.ts",
];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Durable storage validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const authStorage = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/auth-storage.ts"), "utf8");
const authStore = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/auth-store.ts"), "utf8");
const syncStore = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/sync-store.ts"), "utf8");
const db = fs.readFileSync(path.join(ROOT, "packages/shared/lib/server/db.ts"), "utf8");
const schema = fs.readFileSync(path.join(ROOT, "docs/sql/001_auth_sync_schema.sql"), "utf8");
const envExample = fs.readFileSync(path.join(ROOT, ".env.example"), "utf8");
const sendCodeRoute = fs.readFileSync(
  path.join(ROOT, "apps/api/app/api/auth/send-code/route.ts"),
  "utf8",
);

for (const table of ["auth_codes", "sessions", "sync_blobs"]) {
  if (!schema.includes(`CREATE TABLE IF NOT EXISTS ${table}`)) {
    console.error(`Durable storage validation failed — schema missing table ${table}.`);
    process.exit(1);
  }
}

if (!db.includes("AUTH_SYNC_SCHEMA_STATEMENTS") || db.includes("readFileSync")) {
  console.error("Durable storage validation failed — db.ts must bundle schema SQL for serverless.");
  process.exit(1);
}

if (!db.includes("shouldUsePostgresStorage") || !db.includes("ensureDatabaseSchema")) {
  console.error("Durable storage validation failed — db.ts missing Postgres helpers.");
  process.exit(1);
}

if (!authStorage.includes("shouldUsePostgresStorage")) {
  console.error("Durable storage validation failed — auth-storage must branch on DATABASE_URL.");
  process.exit(1);
}

if (authStorage.includes("throw new AuthStorageNotConfiguredError()")) {
  console.error(
    "Durable storage validation failed — DATABASE_URL must not trap auth with AuthStorageNotConfiguredError.",
  );
  process.exit(1);
}

if (!authStore.includes("shouldUsePostgresStorage") || !authStore.includes("issueAuthCodePostgres")) {
  console.error("Durable storage validation failed — auth-store must delegate to Postgres.");
  process.exit(1);
}

if (!syncStore.includes("shouldUsePostgresStorage") || !syncStore.includes("upsertEncryptedBlobsPostgres")) {
  console.error("Durable storage validation failed — sync-store must delegate to Postgres.");
  process.exit(1);
}

if (!syncStore.includes("shouldUseFilesystemStorage")) {
  console.error("Durable storage validation failed — sync-store must gate filesystem to local dev.");
  process.exit(1);
}

if (!syncStore.includes("syncStorageUsesFilesystemInProduction")) {
  console.error("Durable storage validation failed — sync-store must expose production filesystem guard.");
  process.exit(1);
}

if (!authStorage.includes("authStorageUsesFilesystemInProduction")) {
  console.error("Durable storage validation failed — auth-storage must expose production filesystem guard.");
  process.exit(1);
}

if (authStorage.includes('mode: "filesystem"') && !authStorage.includes("isProduction()")) {
  console.error("Durable storage validation failed — filesystem auth backend must be dev-only.");
  process.exit(1);
}

if (syncStore.includes("writeJsonFile") && !syncStore.includes("shouldUseFilesystemStorage()")) {
  console.error("Durable storage validation failed — sync filesystem writes must be dev-gated.");
  process.exit(1);
}

if (!envExample.includes("DATABASE_URL")) {
  console.error("Durable storage validation failed — .env.example must document DATABASE_URL.");
  process.exit(1);
}

if (!sendCodeRoute.includes("AUTH_DATABASE_FAILED") || !sendCodeRoute.includes("logAuthError")) {
  console.error("Durable storage validation failed — send-code must log and surface database failures.");
  process.exit(1);
}

const sessionRoute = fs.readFileSync(
  path.join(ROOT, "apps/api/app/api/auth/session/route.ts"),
  "utf8",
);
if (!sessionRoute.includes("logAuthError") || !sessionRoute.includes("AUTH_SESSION_FAILED")) {
  console.error("Durable storage validation failed — session route must handle auth failures.");
  process.exit(1);
}

const syncPostgres = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/server/sync-store-postgres.ts"),
  "utf8",
);
if (
  !syncPostgres.includes("assertEncryptedPayloadOnly") ||
  !syncPostgres.includes("rejectPlaintextBlobFields")
) {
  console.error("Durable storage validation failed — sync postgres store must reject plaintext fields.");
  process.exit(1);
}

for (const doc of [
  "docs/DURABLE_STORAGE_MIGRATION.md",
  "docs/PRODUCTION_DEPLOY.md",
  "docs/DEPLOY_READINESS_REPORT.md",
]) {
  const text = fs.readFileSync(path.join(ROOT, doc), "utf8");
  if (!text.includes("DATABASE_URL") || !text.toLowerCase().includes("postgres")) {
    console.error(`Durable storage validation failed — ${doc} must document Postgres + DATABASE_URL.`);
    process.exit(1);
  }
}

console.log("Durable storage validation passed.");
