#!/usr/bin/env node
/**
 * Runtime proof — integration blockers + HTTP E2E (unless skipped).
 */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: ROOT, stdio: "inherit", env: process.env });
  return r.status === 0;
}

const integrationSteps = [
  ["validate:grade-a-blockers-tests", "npm", ["run", "validate:grade-a-blockers-tests"]],
  ["validate:privacy-logs-tests", "npm", ["run", "validate:privacy-logs-tests"]],
  ["validate:health", "npm", ["run", "validate:health"]],
];

for (const [name, cmd, args] of integrationSteps) {
  console.log(`\n— runtime proof: ${name} —`);
  if (!run(cmd, args)) process.exit(1);
}

if (process.env.VOICEMEMORY_SKIP_E2E === "1") {
  console.warn(
    "validate:runtime-proof — integration passed; HTTP E2E skipped (VOICEMEMORY_SKIP_E2E=1)",
  );
  process.exit(0);
}

if (!run("npm", ["run", "build"])) process.exit(1);
console.log("\n— runtime proof: e2e/runtime-proof.spec.ts —");
if (
  !run("npx", [
    "playwright",
    "test",
    "-c",
    "playwright.ui.config.ts",
    "--project=runtime-proof",
  ])
) {
  process.exit(1);
}

console.log("validate:runtime-proof passed");
