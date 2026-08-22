#!/usr/bin/env node
import { runClinicalQuarantineAuditTests } from "../apps/api/src/internal/clinical/quarantine-audit-tests.ts";
import { runLoggerSanitizationTests } from "../apps/api/lib/utils/logger-sanitization-tests.ts";

const failures = [];

failures.push(...(await runLoggerSanitizationTests()).failures);
failures.push(...(await runClinicalQuarantineAuditTests()).failures);

if (failures.length) {
  console.error("validate-clinical-quarantine failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-clinical-quarantine ok");
