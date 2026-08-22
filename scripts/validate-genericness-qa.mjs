#!/usr/bin/env node
/** Core + careerTransition + recovery lens genericness QA (PRD Goal #4). */
import { runGenericnessQaTest } from "../apps/api/src/__tests__/genericness_qa.test.ts";

const result = await runGenericnessQaTest();

if (result.skipped) {
  console.warn(`validate-genericness-qa skipped: ${result.skipReason}`);
  process.exit(0);
}

if (result.failures.length) {
  console.error("validate-genericness-qa failed:\n", result.failures.join("\n"));
  process.exit(1);
}

console.log("validate-genericness-qa ok");
