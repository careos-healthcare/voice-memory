#!/usr/bin/env node
import { runRateLimitTests } from "../lib/reliability/rate-limit-tests.ts";
import { runRateLimitProductionTests } from "../lib/reliability/rate-limit-production-tests.ts";

const failures = [];

failures.push(...(await runRateLimitTests()).failures);
failures.push(...(await runRateLimitProductionTests()).failures);

if (failures.length) {
  console.error("validate-rate-limits failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-rate-limits ok");
