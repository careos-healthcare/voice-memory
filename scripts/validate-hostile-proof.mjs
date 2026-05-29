#!/usr/bin/env node
/**
 * Hostile-user proof — integration blockers + abuse E2E (unless skipped).
 */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: ROOT, stdio: "inherit", env: process.env });
  return r.status === 0;
}

console.log("\n— hostile proof: validate:grade-a-blockers-tests —");
if (!run("npm", ["run", "validate:grade-a-blockers-tests"])) process.exit(1);

if (process.env.VOICEMEMORY_SKIP_E2E === "1") {
  console.warn(
    "validate:hostile-proof — integration passed; HTTP E2E skipped (VOICEMEMORY_SKIP_E2E=1)",
  );
  process.exit(0);
}

if (!run("npm", ["run", "build"])) process.exit(1);
console.log("\n— hostile proof: e2e/hostile-proof.spec.ts —");
if (
  !run("npx", [
    "playwright",
    "test",
    "-c",
    "playwright.ui.config.ts",
    "--project=hostile-proof",
  ])
) {
  process.exit(1);
}

console.log("validate:hostile-proof passed");
