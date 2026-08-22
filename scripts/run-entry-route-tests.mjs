#!/usr/bin/env node

import { runEntryRouteTestsForCi } from "../packages/shared/lib/reliability/entry-route-tests.ts";

const report = await runEntryRouteTestsForCi();

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
  console.error(`\n${report.failed}/${report.results.length} entry route test(s) failed.`);
  process.exit(1);
}

console.log(`\nAll ${report.results.length} entry route tests passed.`);
