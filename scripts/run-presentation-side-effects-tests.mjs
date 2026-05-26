#!/usr/bin/env node
/**
 * Firefox recursion regression — no sync storage during presentation build.
 */

import { runPresentationSideEffectsTestsForCi } from "../lib/reliability/presentation-side-effects-tests.ts";

const report = await runPresentationSideEffectsTestsForCi();

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
  console.error(`\n${report.failed}/${report.results.length} presentation side-effect test(s) failed.`);
  process.exit(1);
}

console.log(`\nAll ${report.results.length} presentation side-effect tests passed.`);
