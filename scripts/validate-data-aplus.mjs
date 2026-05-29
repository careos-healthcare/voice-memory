#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const engine = fs.readFileSync(
  path.join(ROOT, "lib/persistence/journal-sync-engine.ts"),
  "utf8",
);

for (const token of [
  "syncEntryServerFirst",
  "enqueueJournalSync",
  "reconcileJournalWithServer",
  "mergeJournalByNewest",
  "pending_sync",
  "sync_failed",
  "flushJournalSyncQueue",
]) {
  if (!engine.includes(token)) failures.push(`journal-sync-engine missing ${token}`);
}

if (!fs.existsSync(path.join(ROOT, "app/api/journal/export/route.ts"))) {
  failures.push("missing journal export route");
}

const storage = fs.readFileSync(path.join(ROOT, "lib/storage.ts"), "utf8");
if (!storage.includes("syncEntryServerFirst")) {
  failures.push("saveEntry must use server-first sync");
}

if (failures.length) {
  console.error("validate-data-aplus failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-data-aplus ok");
