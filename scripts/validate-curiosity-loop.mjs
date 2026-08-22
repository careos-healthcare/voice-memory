#!/usr/bin/env node
import { runCuriosityLoopTests } from "../apps/api/src/services/loops/curiosity-loop-tests.ts";

const failures = [...(await runCuriosityLoopTests()).failures];

if (failures.length) {
  console.error("validate-curiosity-loop failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-curiosity-loop ok");
