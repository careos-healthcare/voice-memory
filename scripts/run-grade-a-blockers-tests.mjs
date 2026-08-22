#!/usr/bin/env node
import { runApiGuardTests } from "../packages/shared/lib/reliability/api-guard-tests.ts";
import { runBillingTestsAsync } from "../packages/shared/lib/reliability/billing-tests.ts";
import { runJournalServerTests } from "../packages/shared/lib/reliability/journal-server-tests.ts";
import { runJournalSyncTests } from "../packages/shared/lib/reliability/journal-sync-tests.ts";
import { runJournalPersistenceTests } from "../packages/shared/lib/reliability/journal-persistence-tests.ts";
import { runOpenAiBudgetTests } from "../packages/shared/lib/reliability/openai-budget-tests.ts";
import { runRateLimitTests } from "../packages/shared/lib/reliability/rate-limit-tests.ts";
import { runResurfacingFeedbackTests } from "../packages/shared/lib/reliability/resurfacing-feedback-tests.ts";
import { runResurfacingFeedbackApiTests } from "../packages/shared/lib/reliability/resurfacing-feedback-api-tests.ts";
import { runE2eTestIpTests } from "../packages/shared/lib/reliability/e2e-test-ip-tests.ts";

const failures = [];

const api = runApiGuardTests();
failures.push(...api.failures);

failures.push(...(await runBillingTestsAsync()).failures);
failures.push(...(await runRateLimitTests()).failures);
failures.push(...(await runOpenAiBudgetTests()).failures);
failures.push(...(await runJournalServerTests()).failures);
failures.push(...(await runJournalSyncTests()).failures);

const journal = runJournalPersistenceTests();
failures.push(...journal.failures);

const feedback = runResurfacingFeedbackTests();
failures.push(...feedback.failures);

failures.push(...(await runResurfacingFeedbackApiTests()).failures);
failures.push(...(await runE2eTestIpTests()).failures);

if (failures.length > 0) {
  console.error("grade-a-blockers-tests failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("grade-a-blockers-tests ok");
