#!/usr/bin/env node
/**
 * Launch proof bundle — full-surface a11y, runtime, hostile, validator confidence.
 */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function runStep(name, cmd, args) {
  console.log(`\n=== launch-proof: ${name} ===`);
  const r = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: "inherit",
    env: {
      ...process.env,
      EMAIL_DISABLED: "true",
      AUTH_SECRET:
        process.env.AUTH_SECRET ?? "launch-proof-e2e-secret-32-chars-minimum",
    },
  });
  if (r.status !== 0) {
    console.error(`\nlaunch-proof FAILED at: ${name}\n`);
    process.exit(1);
  }
}

runStep("validate:validator-confidence", "node", [
  "scripts/validate-validator-confidence.mjs",
]);
runStep("validate:wcag-launch-surface", "node", [
  "scripts/validate-wcag-launch-surface.mjs",
]);
runStep("validate:accessibility-full", "npm", ["run", "validate:accessibility-full"]);
runStep("validate:runtime-proof", "npm", ["run", "validate:runtime-proof"]);
runStep("validate:hostile-proof", "npm", ["run", "validate:hostile-proof"]);

console.log("\n=== launch-proof: validate:staging-proof (honest skip locally) ===");
const staging = spawnSync("npm", ["run", "validate:staging-proof"], {
  cwd: ROOT,
  stdio: "inherit",
  env: process.env,
});
if (staging.status !== 0) {
  console.error("\nlaunch-proof FAILED at: validate:staging-proof\n");
  process.exit(1);
}

console.log("\n=== launch-proof: validate:device-proof (honest skip unless required) ===");
const device = spawnSync("npm", ["run", "validate:device-proof"], {
  cwd: ROOT,
  stdio: "inherit",
  env: process.env,
});
if (device.status !== 0) {
  console.error("\nlaunch-proof FAILED at: validate:device-proof\n");
  process.exit(1);
}

console.log("\nvalidate:launch-proof passed\n");
