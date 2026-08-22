#!/usr/bin/env node
import { runRecoveryToneTests } from "../packages/shared/lib/reliability/recovery-tone-tests.ts";

const { failures } = await runRecoveryToneTests();

if (failures.length) {
  console.error("validate-recovery-tone failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-recovery-tone ok");
