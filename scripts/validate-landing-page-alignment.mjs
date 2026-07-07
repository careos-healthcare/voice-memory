#!/usr/bin/env node
import { runLandingPageAlignmentTests } from "../lib/reliability/landing-page-alignment-tests.ts";

const { failures } = runLandingPageAlignmentTests();
if (failures.length > 0) {
  console.error("validate-landing-page-alignment failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-landing-page-alignment ok");
