#!/usr/bin/env node
import { runJournalSyncTests } from "../lib/reliability/journal-sync-tests.ts";

const { failures } = await runJournalSyncTests();

if (failures.length > 0) {
  console.error("journal-sync-tests failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("journal-sync-tests ok");
