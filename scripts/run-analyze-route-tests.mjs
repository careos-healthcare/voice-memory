#!/usr/bin/env node
import { runAnalyzeRouteTests } from "../lib/reliability/analyze-route-tests.ts";

const { failures } = await runAnalyzeRouteTests();

if (failures.length) {
  console.error("validate-analyze-route failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-analyze-route ok");
