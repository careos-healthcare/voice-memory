#!/usr/bin/env node
import { runGlobalRateLimitSubjectTests } from "../apps/api/lib/rate-limit/global-rate-limit-subject-tests.ts";
import { runGlobalRateLimitTests } from "../apps/api/lib/rate-limit/global-rate-limit-tests.ts";
import { runRateLimitTests } from "../packages/shared/lib/reliability/rate-limit-tests.ts";
import { runRateLimitProductionTests } from "../packages/shared/lib/reliability/rate-limit-production-tests.ts";

const failures = [];

failures.push(...(await runRateLimitTests()).failures);
failures.push(...(await runRateLimitProductionTests()).failures);
failures.push(...(await runGlobalRateLimitTests()).failures);
failures.push(...(await runGlobalRateLimitSubjectTests()).failures);

if (failures.length) {
  console.error("validate-rate-limits failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-rate-limits ok");
