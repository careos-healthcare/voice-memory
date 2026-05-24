#!/usr/bin/env node
/**
 * CI archive stress tests — executes lib/reliability/stress-tests.ts.
 * Requires tsx for TypeScript + path alias resolution.
 */

import { runAllArchiveStressTests, STRESS_TEST_SEED } from "../lib/reliability/stress-tests.ts";

const report = runAllArchiveStressTests();

for (const result of report.results) {
  if (result.passed) {
    console.log(`OK ${result.scenario} (${result.durationMs}ms · ${result.recoveryPath})`);
    continue;
  }

  console.error(`FAIL ${result.scenario}`);
  console.error(`  recovery: ${result.recoveryPath}`);
  for (const assertion of result.failedAssertions) {
    console.error(`  - ${assertion}`);
  }
  if (result.corruptedPayloadPreview) {
    console.error(`  corrupted preview: ${result.corruptedPayloadPreview}`);
  }
  if (result.rollbackPreview) {
    console.error(`  rollback preview: ${result.rollbackPreview}`);
  }
}

if (!report.allPassed) {
  console.error(
    `\n${report.failed}/${report.results.length} archive stress test(s) failed (seed ${STRESS_TEST_SEED}).`,
  );
  process.exit(1);
}

console.log(
  `\nAll ${report.results.length} archive stress tests passed (seed ${STRESS_TEST_SEED}).`,
);
