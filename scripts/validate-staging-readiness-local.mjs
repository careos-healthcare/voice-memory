#!/usr/bin/env node
/**
 * Local staging package sanity — files/scripts only, no live secrets.
 * Exit 0 = package ready to execute on staging host.
 * Exit 1 = missing doc, template, script, or proof module.
 */
import { existsSync, readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SPP20 = resolve(
  process.env.SPP20_DIR ?? resolve(process.env.HOME ?? "/Users/chiragpatel", "Desktop/spp20"),
);

const SPP20_REQUIRED = [
  "STAGING_EXECUTION_ORDER.md",
  "HOST_SETUP_CHECKLIST.md",
  "my_staging_execution_steps.md",
  "staging_command_cheatsheet.md",
  "staging_signoff_how_to.md",
  "production_env_required_template.env",
  "production_host_setup_guide.md",
  "final_blocker_resolution_workflow.md",
  "production_proof_runbook.md",
  "aplus_exit_zero_requirements.md",
  "remaining_external_actions.md",
  "staging_proof_status.template.json",
  "stripe_webhook_proof_status.template.json",
  "email_delivery_proof_status.template.json",
  "device_proof_signoff.template.json",
  "staging_proof_status.json",
  "stripe_webhook_proof_status.json",
  "email_delivery_proof_status.json",
  "device_proof_signoff.json",
  "real_device_runtime_proof_checklist.md",
];

const REPO_SCRIPTS = [
  "scripts/validate-database-live.mjs",
  "scripts/validate-stripe-webhook-proof.mjs",
  "scripts/validate-email-live.mjs",
  "scripts/validate-deploy-secrets.mjs",
  "scripts/validate-staging-proof.mjs",
  "scripts/validate-device-proof.mjs",
  "scripts/validate-aplus.mjs",
  "scripts/validate-staging-readiness-local.mjs",
];

const REPO_LIB_PROOF = [
  "packages/shared/lib/proof/signoff-files.ts",
  "packages/shared/lib/proof/signoff-validation.ts",
  "packages/shared/lib/proof/database-live-check.ts",
  "packages/shared/lib/proof/stripe-webhook-proof-check.ts",
  "packages/shared/lib/proof/email-live-check.ts",
  "packages/shared/lib/proof/deploy-proof-orchestrator.ts",
  "packages/shared/lib/proof/proof-result.ts",
];

const NPM_SCRIPTS = [
  "validate:database-live",
  "validate:stripe-webhook-proof",
  "validate:email-live",
  "validate:deploy-secrets",
  "validate:staging-proof",
  "validate:device-proof",
  "validate:aplus",
  "validate:staging-readiness-local",
  "staging:setup-check",
  "staging:proof-guide",
  "staging:run-proof",
  "staging:signoff-status",
];

const STAGING_SCRIPTS = [
  "scripts/staging-setup-check.mjs",
  "scripts/staging-proof-guide.mjs",
  "scripts/staging-run-proof.mjs",
  "scripts/staging-signoff-status.mjs",
];

const failures = [];

function requirePath(label, path) {
  if (!existsSync(path)) failures.push(`${label}: missing ${path}`);
}

for (const name of SPP20_REQUIRED) {
  requirePath("spp20", resolve(SPP20, name));
}

for (const rel of [...REPO_SCRIPTS, ...STAGING_SCRIPTS]) {
  requirePath("script", resolve(ROOT, rel));
}

const STAGING_LIB = [
  "packages/shared/lib/staging/staging-setup-check.ts",
  "packages/shared/lib/staging/staging-signoff-status.ts",
  "packages/shared/lib/staging/staging-proof-guide.ts",
];
for (const rel of STAGING_LIB) {
  requirePath("lib", resolve(ROOT, rel));
}

for (const rel of REPO_LIB_PROOF) {
  requirePath("lib", resolve(ROOT, rel));
}

const pkg = JSON.parse(readFileSync(resolve(ROOT, "package.json"), "utf8"));
for (const name of NPM_SCRIPTS) {
  if (!pkg.scripts?.[name]) {
    failures.push(`package.json: missing script "${name}"`);
  }
}

for (const signoff of [
  "staging_proof_status.json",
  "stripe_webhook_proof_status.json",
  "device_proof_signoff.json",
]) {
  const path = resolve(SPP20, signoff);
  if (existsSync(path)) {
    try {
      const data = JSON.parse(readFileSync(path, "utf8"));
      const proofKeys = Object.keys(data).filter(
        (k) =>
          typeof data[k] === "boolean" &&
          k !== "version" &&
          !k.startsWith("_"),
      );
      const faked = proofKeys.filter((k) => data[k] === true);
      if (faked.length) {
        failures.push(
          `${signoff}: proof booleans must stay false until real sign-off (${faked.join(", ")} are true)`,
        );
      }
    } catch {
      failures.push(`${signoff}: invalid JSON`);
    }
  }
}

console.log("\n=== validate:staging-readiness-local ===\n");
console.log(`SPP20_DIR: ${SPP20}`);
console.log(`REPO_ROOT: ${ROOT}\n`);

if (failures.length) {
  console.error("FAIL — staging package incomplete:\n");
  for (const f of failures) console.error(`  - ${f}`);
  console.error("\n");
  process.exit(1);
}

console.log("PASS — staging docs, sign-off stubs, scripts, and npm entries present.");
console.log("Next: run steps in ~/Desktop/spp20/STAGING_EXECUTION_ORDER.md on the staging host.\n");
process.exit(0);
