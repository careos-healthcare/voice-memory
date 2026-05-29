#!/usr/bin/env node
import { runApiGuardTests } from "../lib/reliability/api-guard-tests.ts";
import { runBillingTestsAsync } from "../lib/reliability/billing-tests.ts";
import { runJournalServerTests } from "../lib/reliability/journal-server-tests.ts";
import { runJournalPersistenceTests } from "../lib/reliability/journal-persistence-tests.ts";
import { runRateLimitTests } from "../lib/reliability/rate-limit-tests.ts";
import { runResurfacingFeedbackTests } from "../lib/reliability/resurfacing-feedback-tests.ts";
import { runResurfacingFeedbackApiTests } from "../lib/reliability/resurfacing-feedback-api-tests.ts";

const failures = [];

const api = runApiGuardTests();
failures.push(...api.failures);

failures.push(...(await runBillingTestsAsync()).failures);
failures.push(...(await runRateLimitTests()).failures);
failures.push(...(await runJournalServerTests()).failures);

const journal = runJournalPersistenceTests();
failures.push(...journal.failures);

const feedback = runResurfacingFeedbackTests();
failures.push(...feedback.failures);

failures.push(...(await runResurfacingFeedbackApiTests()).failures);

if (failures.length > 0) {
  console.error("grade-a-blockers-tests failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("grade-a-blockers-tests ok");
