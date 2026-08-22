#!/usr/bin/env node
import { runJournalProductionTests } from "../packages/shared/lib/reliability/journal-production-tests.ts";
import { runJournalServerTests } from "../packages/shared/lib/reliability/journal-server-tests.ts";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const engine = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/persistence/journal-sync-engine.ts"),
  "utf8",
);
for (const token of [
  "pending_sync",
  "sync_failed",
  "syncEntryServerFirst",
  "enqueueJournalSync",
  "reconcileJournalWithServer",
]) {
  if (!engine.includes(token)) failures.push(`journal-sync-engine missing ${token}`);
}

failures.push(...(await runJournalServerTests()).failures);
failures.push(...(await runJournalProductionTests()).failures);

if (failures.length) {
  console.error("validate-journal failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-journal ok");
