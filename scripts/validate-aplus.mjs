#!/usr/bin/env node
/**
 * A+ validation — code-proven checks must pass; live/deploy/device gaps exit 2.
 * Exit 0 = full A+ (code + deploy + staging + device proof)
 * Exit 1 = code failure
 * Exit 2 = DEPLOY_BLOCKED / STAGING_BLOCKED / DEVICE_BLOCKED (honest incomplete proof)
 */
import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const categories = [];

function runStep(name, cmd, args, env = {}) {
  console.log(`\n— ${name} —`);
  const result = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: "inherit",
    env: {
      ...process.env,
      EMAIL_DISABLED: process.env.EMAIL_DISABLED ?? "true",
      AUTH_SECRET:
        process.env.AUTH_SECRET ??
        "aplus-code-only-validation-secret-32chars-minimum",
      ...env,
    },
    shell: false,
  });
  const ok = result.status === 0;
  categories.push({ name, status: ok ? "PASS" : "FAIL", kind: "code", exitCode: result.status });
  return ok;
}

function runBlockedAware(name, cmd, args, env = {}) {
  console.log(`\n— ${name} —`);
  const result = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: "inherit",
    env: { ...process.env, ...env },
    shell: false,
  });
  let status = "PASS";
  if (result.status === 2) status = "BLOCKED";
  else if (result.status !== 0) status = "FAIL";
  categories.push({ name, status, kind: "proof", exitCode: result.status });
  return result.status === 0;
}

const codeSteps = [
  [
    "validate:grade-a (code-only)",
    "node",
    ["scripts/validate-grade-a.mjs", "--code-only"],
  ],
  ["validate:billing", "npm", ["run", "validate:billing"]],
  ["validate:rate-limits", "npm", ["run", "validate:rate-limits"]],
  ["validate:journal", "npm", ["run", "validate:journal"]],
  ["validate:emotional-quality", "npm", ["run", "validate:emotional-quality"]],
  ["validate:security-aplus", "npm", ["run", "validate:security-aplus"]],
  ["validate:data-aplus", "npm", ["run", "validate:data-aplus"]],
  ["validate:field-metrics", "npm", ["run", "validate:field-metrics"]],
  ["validate:privacy-logs", "npm", ["run", "validate:privacy-logs"]],
  ["validate:observability-aplus", "npm", ["run", "validate:observability-aplus"]],
  ["validate:supply-chain", "npm", ["run", "validate:supply-chain"]],
  ["validate:internal-routes", "npm", ["run", "validate:internal-routes"]],
  ["validate:api-guard", "npm", ["run", "validate:api-guard"]],
  ["validate:debug-guard", "npm", ["run", "validate:debug-guard"]],
  ["validate:debug-surface", "npm", ["run", "validate:debug-surface"]],
  ["validate:migrations", "npm", ["run", "validate:migrations"]],
  ["validate:grade-a-blockers-tests", "npm", ["run", "validate:grade-a-blockers-tests"]],
  ["validate:validator-confidence", "npm", ["run", "validate:validator-confidence"]],
  ["build", "npm", ["run", "build"]],
];

let codeFail = false;
for (const [name, cmd, args] of codeSteps) {
  if (!runStep(name, cmd, args)) codeFail = true;
}

const liveProofSteps = [
  ["validate:database-live", "npm", ["run", "validate:database-live"]],
  ["validate:stripe-webhook-proof", "npm", ["run", "validate:stripe-webhook-proof"]],
  ["validate:email-live", "npm", ["run", "validate:email-live"]],
  ["validate:deploy-secrets", "npm", ["run", "validate:deploy-secrets"]],
  ["validate:staging-proof", "npm", ["run", "validate:staging-proof"]],
  [
    "validate:device-proof",
    "npm",
    ["run", "validate:device-proof"],
    { VOICEMEMORY_DEVICE_PROOF_REQUIRED: process.env.VOICEMEMORY_DEVICE_PROOF_REQUIRED ?? "1" },
  ],
];

let proofBlocked = false;
let proofFail = false;
for (const [name, cmd, args, env] of liveProofSteps) {
  const ok = runBlockedAware(name, cmd, args, env);
  if (!ok) {
    const entry = categories.find((c) => c.name === name);
    if (entry?.status === "BLOCKED") proofBlocked = true;
    else proofFail = true;
  }
}

if (!codeFail && process.env.VOICEMEMORY_SKIP_E2E !== "1") {
  if (!runStep("validate:launch-proof", "npm", ["run", "validate:launch-proof"])) codeFail = true;
  if (!runStep("test:e2e:prod", "npm", ["run", "test:e2e:prod"])) codeFail = true;
}

const reportPath = resolve(
  process.env.HOME ?? "/Users/chiragpatel",
  "Desktop/spp20/aplus_validation_categories.json",
);
writeFileSync(reportPath, JSON.stringify({ at: new Date().toISOString(), categories }, null, 2));

console.log("\n=== A+ SUMMARY ===");
for (const c of categories) {
  console.log(`${String(c.status).padEnd(14)} ${c.name}`);
}

if (codeFail || proofFail) {
  console.error("\nA+ FAIL — code or proof validator failure (exit 1)\n");
  process.exit(1);
}

if (proofBlocked) {
  console.warn(
    "\nA+ DEPLOY_BLOCKED — code OK; complete staging/deploy/device proof on host (exit 2)\n",
  );
  process.exit(2);
}

console.log("\nA+ PASS — code and live proof verified (exit 0)\n");
process.exit(0);
