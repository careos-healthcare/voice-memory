#!/usr/bin/env node
/**
 * Full proof closure — exit 0 only when all code + live sign-offs pass.
 * Exit 2 = PROOF_BLOCKED. Exit 1 = FAIL.
 */
import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SPP20 = resolve(process.env.HOME ?? "/Users/chiragpatel", "Desktop/spp20");

const results = [];

function runStep(name, cmd, args, extraEnv = {}) {
  console.log(`\n— proof-complete: ${name} —`);
  const r = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: ["inherit", "pipe", "pipe"],
    encoding: "utf8",
    env: {
      ...process.env,
      EMAIL_DISABLED: process.env.EMAIL_DISABLED ?? "true",
      AUTH_SECRET:
        process.env.AUTH_SECRET ?? "proof-complete-e2e-secret-32-chars-minimum",
      VOICEMEMORY_DEVICE_PROOF_REQUIRED:
        process.env.VOICEMEMORY_DEVICE_PROOF_REQUIRED ?? "1",
      ...extraEnv,
    },
  });
  const combined = `${r.stdout ?? ""}\n${r.stderr ?? ""}`;
  let status = "PASS";
  if (
    r.status === 2 ||
    /DEPLOY_BLOCKED|DEVICE_BLOCKED|STAGING_BLOCKED|PROOF_BLOCKED|CODE-PROVEN/i.test(
      combined,
    )
  ) {
    status = "PROOF_BLOCKED";
  } else if (r.status !== 0) {
    status = "FAIL";
  }
  results.push({ name, status, exitCode: r.status ?? 1 });
  console.log(`${status}: ${name} (exit ${r.status ?? 1})`);
  return status;
}

const steps = [
  ["build", "npm", ["run", "build"]],
  ["validate:database-live", "npm", ["run", "validate:database-live"]],
  ["validate:stripe-webhook-proof", "npm", ["run", "validate:stripe-webhook-proof"]],
  ["validate:email-live", "npm", ["run", "validate:email-live"]],
  ["validate:deploy-secrets", "npm", ["run", "validate:deploy-secrets"]],
  ["validate:wcag-launch-surface", "npm", ["run", "validate:wcag-launch-surface"]],
  ["validate:validator-confidence", "npm", ["run", "validate:validator-confidence"]],
  ["validate:screen-reader-structure", "npm", ["run", "validate:screen-reader-structure"]],
  ["validate:runtime-proof", "npm", ["run", "validate:runtime-proof"]],
  ["validate:hostile-proof", "npm", ["run", "validate:hostile-proof"]],
  ["validate:staging-proof", "npm", ["run", "validate:staging-proof"]],
  ["validate:device-proof", "npm", ["run", "validate:device-proof"]],
  ["validate:launch-proof", "npm", ["run", "validate:launch-proof"]],
  ["validate:aplus", "npm", ["run", "validate:aplus"]],
];

for (const [name, cmd, args] of steps) {
  runStep(name, cmd, args);
}

const hardFail = results.some((r) => r.status === "FAIL");
const blocked = results.some((r) => r.status === "PROOF_BLOCKED");
const overall = hardFail ? "FAIL" : blocked ? "PROOF_BLOCKED" : "PASS";

const md = [
  "# Proof complete status report",
  "",
  `**At:** ${new Date().toISOString()}`,
  "",
  "| Step | Status | Exit |",
  "|------|--------|------|",
  ...results.map((r) => `| ${r.name} | ${r.status} | ${r.exitCode} |`),
  "",
  `**Overall:** ${overall}`,
  "",
  "## Interpretation",
  "",
  "- **PASS** — code and live/device sign-offs complete.",
  "- **PROOF_BLOCKED** (exit 2) — code gates OK; staging/deploy/device/billing/email proof still required.",
  "- **FAIL** (exit 1) — fix code or tests before launch.",
].join("\n");

writeFileSync(resolve(SPP20, "proof_complete_status_report.md"), md);
console.log(`\nWrote ${resolve(SPP20, "proof_complete_status_report.md")}`);

if (hardFail) process.exit(1);
if (blocked) process.exit(2);
console.log("\nvalidate:proof-complete PASS\n");
