#!/usr/bin/env node
import { runMobileWebParityAuditTests } from "../packages/shared/lib/reliability/mobile-web-parity-audit-tests.ts";

const { failures } = runMobileWebParityAuditTests();

if (failures.length > 0) {
  console.error("validate-mobile-web-parity-audit failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-mobile-web-parity-audit ok");
