#!/usr/bin/env node
import { runAuthSecurityTests } from "../packages/shared/lib/reliability/auth-security-tests.ts";

const { failures } = await runAuthSecurityTests();

if (failures.length) {
  console.error("validate-auth-security failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-auth-security ok");
