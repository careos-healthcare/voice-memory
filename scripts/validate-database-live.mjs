#!/usr/bin/env node
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  formatDatabaseLiveReport,
  runDatabaseLiveCheck,
} from "../lib/proof/database-live-check.ts";
import { formatProofChecks } from "../lib/proof/proof-result.ts";

const report = await runDatabaseLiveCheck();
formatProofChecks(report.checks);

const out = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/database_live_proof_report.md",
);
writeFileSync(out, formatDatabaseLiveReport(report));
console.log(`\nWrote ${out}`);
console.log(`\nvalidate:database-live — ${report.label}\n`);

if (report.verdict === "FAIL") process.exit(1);
if (report.verdict === "DEPLOY_BLOCKED") process.exit(2);
process.exit(0);
