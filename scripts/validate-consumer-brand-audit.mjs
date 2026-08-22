#!/usr/bin/env node
import { runConsumerBrandAuditTests } from "../packages/shared/lib/reliability/consumer-brand-audit-tests.ts";

const { failures } = runConsumerBrandAuditTests(process.cwd());

if (failures.length > 0) {
  console.error("validate-consumer-brand-audit failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-consumer-brand-audit ok");
