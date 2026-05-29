#!/usr/bin/env node
import { spawnSync } from "node:child_process";

const codeOnly =
  process.argv.includes("--code-only") || process.env.VOICEMEMORY_APLUS_CODE_ONLY === "1";

const steps = [];
if (!codeOnly) {
  steps.push([
    "validate:production-env",
    "node",
    ["scripts/validate-production-env.mjs", "--strict"],
  ]);
}
steps.push(
  ["validate:migrations", "npm", ["run", "validate:migrations"]],
  ["validate:email-mode", "npm", ["run", "validate:email-mode"]],
  ["validate:billing", "npm", ["run", "validate:billing"]],
  ["validate:rate-limits", "npm", ["run", "validate:rate-limits"]],
  ["validate:journal", "npm", ["run", "validate:journal"]],
  ["validate:internal-routes", "npm", ["run", "validate:internal-routes"]],
  ["validate:emotional-quality", "npm", ["run", "validate:emotional-quality"]],
  ["validate:health", "npm", ["run", "validate:health"]],
  ["validate:grade-a-blockers-tests", "npm", ["run", "validate:grade-a-blockers-tests"]],
  ["validate:api-guard", "npm", ["run", "validate:api-guard"]],
  ["validate:debug-guard", "npm", ["run", "validate:debug-guard"]],
  ["build", "npm", ["run", "build"]],
);

const optionalE2e = process.env.VOICEMEMORY_SKIP_E2E !== "1";

if (optionalE2e) {
  steps.push(["test:e2e:prod", "npm", ["run", "test:e2e:prod"]]);
}

let failed = false;
for (const [name, cmd, args] of steps) {
  console.log(`\n— ${name} —`);
  const env = {
    ...process.env,
    NODE_ENV: process.env.NODE_ENV ?? "production",
    ...(codeOnly
      ? {
          EMAIL_DISABLED: "true",
          VOICEMEMORY_SKIP_E2E: process.env.VOICEMEMORY_SKIP_E2E,
          AUTH_SECRET:
            process.env.AUTH_SECRET ??
            "aplus-code-only-validation-secret-32chars-minimum",
        }
      : { VOICEMEMORY_GRADE_A_STRICT: "1" }),
  };
  const result = spawnSync(cmd, args, { stdio: "inherit", env, shell: false });
  if (result.status !== 0) {
    console.error(`FAILED: ${name}`);
    failed = true;
    break;
  }
}

if (failed) process.exit(1);
console.log("\nvalidate:grade-a — all steps passed\n");
