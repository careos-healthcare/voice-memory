#!/usr/bin/env node
import { runVisionExtractionContractTests } from "../lib/reliability/vision-extraction-contract-tests.ts";

await runVisionExtractionContractTests();
console.log("Vision extraction contract tests passed.");
