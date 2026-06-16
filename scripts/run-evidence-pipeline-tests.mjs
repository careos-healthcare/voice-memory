#!/usr/bin/env node
import { runEvidencePipelineTests } from "../lib/reliability/evidence-pipeline-tests.ts";

const { failures } = await runEvidencePipelineTests();

if (failures.length) {
  console.error("validate-evidence-pipeline failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-evidence-pipeline ok");
