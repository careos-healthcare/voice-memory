#!/usr/bin/env node
import {
  printDeployProofSummary,
  runDeployProofOrchestrator,
} from "../packages/shared/lib/proof/deploy-proof-orchestrator.ts";

const report = await runDeployProofOrchestrator();
printDeployProofSummary(report);

if (report.verdict === "FAIL") {
  console.error("\nvalidate:deploy-secrets — FAIL\n");
  process.exit(1);
}
if (report.verdict === "DEPLOY_BLOCKED") {
  console.warn("\nvalidate:deploy-secrets — DEPLOY_BLOCKED (configure deploy host + sign-offs)\n");
  process.exit(2);
}
console.log("\nvalidate:deploy-secrets — PASS\n");
process.exit(0);
