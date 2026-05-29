#!/usr/bin/env node
import { runPrivacyLogsTests } from "../lib/reliability/privacy-logs-tests.ts";

const { failures } = runPrivacyLogsTests();
if (failures.length) {
  console.error("privacy-logs-tests failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("privacy-logs-tests ok");
