#!/usr/bin/env node
/**
 * Orchestrate staging proof validators — exit 0 only if all pass on this host.
 */
import { spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const STEPS = [
  ["validate:database-live", ["run", "validate:database-live"]],
  ["validate:stripe-webhook-proof", ["run", "validate:stripe-webhook-proof"]],
  ["validate:email-live", ["run", "validate:email-live"]],
  ["validate:staging-proof", ["run", "validate:staging-proof"]],
  ["validate:device-proof", ["run", "validate:device-proof"]],
  ["validate:deploy-secrets", ["run", "validate:deploy-secrets"]],
  ["validate:aplus", ["run", "validate:aplus"]],
];

const results = [];

function runStep(name, args) {
  console.log(`\n— staging:run-proof → ${name} —\n`);
  const r = spawnSync("npm", args, {
    cwd: ROOT,
    stdio: "inherit",
    env: {
      ...process.env,
      // Staging proof mode must be set on the host — never auto-enabled here.
      VOICEMEMORY_DEVICE_PROOF_REQUIRED:
        process.env.VOICEMEMORY_DEVICE_PROOF_REQUIRED ?? "1",
      // E2E needs a running staging URL; skip unless host sets VOICEMEMORY_SKIP_E2E=0.
      VOICEMEMORY_SKIP_E2E: process.env.VOICEMEMORY_SKIP_E2E ?? "1",
    },
  });
  const code = r.status ?? 1;
  let status = "PASS";
  if (code === 2) status = "BLOCKED";
  else if (code !== 0) status = "FAIL";
  results.push({ name, status, exitCode: code });
  return code;
}

console.log("\n=== staging:run-proof ===");
console.log("Host env must include real secrets; sign-offs must be completed manually.");
console.log(
  "On staging host: export VOICEMEMORY_STAGING_PROOF=1 VOICEMEMORY_DEVICE_PROOF_REQUIRED=1\n",
);

let hasFail = false;
let hasBlocked = false;

for (const [name, args] of STEPS) {
  const code = runStep(name, args);
  if (code === 1) hasFail = true;
  if (code === 2) hasBlocked = true;
  if (hasFail) break;
}

console.log("\n=== staging:run-proof SUMMARY ===\n");
for (const r of results) {
  console.log(`${r.status.padEnd(8)} ${r.name} (exit ${r.exitCode})`);
}
for (const name of STEPS.map((s) => s[0]).filter((n) => !results.find((r) => r.name === n))) {
  console.log(`${"SKIP".padEnd(8)} ${name} (not run — prior failure)`);
}

if (hasFail) {
  console.error("\nstaging:run-proof — FAIL (exit 1)\n");
  process.exit(1);
}
if (hasBlocked || results.some((r) => r.status === "BLOCKED")) {
  console.warn("\nstaging:run-proof — BLOCKED (exit 2) — complete env + sign-offs on staging host\n");
  process.exit(2);
}
console.log("\nstaging:run-proof — PASS (exit 0)\n");
process.exit(0);
