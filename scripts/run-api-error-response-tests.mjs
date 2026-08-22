#!/usr/bin/env node
import { runApiErrorResponseTests } from "../packages/shared/lib/reliability/api-error-response-tests.ts";

const { failures, passed } = await runApiErrorResponseTests();
if (failures.length > 0) {
  console.error("validate:api-error-response failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log(`validate:api-error-response ok (${passed} checks)`);
