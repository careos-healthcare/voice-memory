#!/usr/bin/env node
import { runEmailLiveCheck, writeEmailLiveReport } from "../packages/shared/lib/proof/email-live-check.ts";
import { formatProofChecks } from "../packages/shared/lib/proof/proof-result.ts";

const report = await runEmailLiveCheck();
formatProofChecks(report.checks);
writeEmailLiveReport(report);

console.log(`\nvalidate:email-live — ${report.label}\n`);

if (report.verdict === "FAIL") process.exit(1);
if (report.verdict === "DEPLOY_BLOCKED") process.exit(2);
process.exit(0);
