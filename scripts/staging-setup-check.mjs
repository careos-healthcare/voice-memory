#!/usr/bin/env node
import {
  printStagingSetupCheck,
  runStagingSetupCheck,
} from "../packages/shared/lib/staging/staging-setup-check.ts";

const report = runStagingSetupCheck();
printStagingSetupCheck(report);

if (report.verdict === "FAIL") process.exit(1);
if (report.verdict === "BLOCKED") process.exit(2);
process.exit(0);
