#!/usr/bin/env node
import { runUnitEconomicsTests } from "../lib/reliability/unit-economics-tests.ts";

const { failures } = await runUnitEconomicsTests();
if (failures.length > 0) {
  console.error("unit-economics tests failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("unit-economics tests ok");
