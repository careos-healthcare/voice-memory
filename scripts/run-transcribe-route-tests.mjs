#!/usr/bin/env node
import { runTranscribeRouteTests } from "../packages/shared/lib/reliability/transcribe-route-tests.ts";

const { failures } = await runTranscribeRouteTests();

if (failures.length) {
  console.error("validate-transcribe-route failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-transcribe-route ok");
