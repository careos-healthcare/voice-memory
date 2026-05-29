#!/usr/bin/env node
import { runApiGuardTests } from "../lib/reliability/api-guard-tests.ts";
import { runJournalPersistenceTests } from "../lib/reliability/journal-persistence-tests.ts";
import { runResurfacingFeedbackTests } from "../lib/reliability/resurfacing-feedback-tests.ts";

const failures = [];

const api = runApiGuardTests();
failures.push(...api.failures);

failures.push(...runJournalPersistenceTests().failures);
failures.push(...runResurfacingFeedbackTests().failures);

if (failures.length > 0) {
  console.error("grade-a-fix-tests failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("grade-a-fix-tests ok");
