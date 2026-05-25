#!/usr/bin/env node
/**
 * Sync parse / recovery tests — lib/reliability/sync-parse-tests.ts
 */

import { runSyncParseTestsForCi } from "../lib/reliability/sync-parse-tests.ts";

const report = await runSyncParseTestsForCi();

for (const result of report.results) {
  if (result.passed) {
    console.log(`OK ${result.scenario}`);
    continue;
  }

  console.error(`FAIL ${result.scenario}`);
  for (const assertion of result.failedAssertions) {
    console.error(`  - ${assertion}`);
  }
}

if (!report.allPassed) {
  console.error(`\n${report.failed}/${report.results.length} sync parse test(s) failed.`);
  process.exit(1);
}

console.log(`\nAll ${report.results.length} sync parse tests passed.`);
