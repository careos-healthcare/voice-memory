#!/usr/bin/env node
import {
  printStagingSignoffStatus,
  runStagingSignoffStatus,
} from "../packages/shared/lib/staging/staging-signoff-status.ts";

const report = runStagingSignoffStatus();
printStagingSignoffStatus(report);
process.exit(report.aplusExitZeroPossible ? 0 : 2);
