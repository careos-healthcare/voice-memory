#!/usr/bin/env node
import { runPromptContextContractTests } from "../lib/reliability/prompt-context-contract-tests.ts";

const { failures } = await runPromptContextContractTests();

if (failures.length) {
  console.error("validate-prompt-context-contract failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-prompt-context-contract ok");
