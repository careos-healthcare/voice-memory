#!/usr/bin/env node
/**
 * PRD Goal #4 — strict insight-quality gate sequence.
 *
 * Order is intentional: genericness + evidence pipeline must pass before
 * lens tone validators and deferred insight-science suites run.
 */
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const STEPS = [
  {
    label: "validate:genericness-qa (core + careerTransition + recovery lenses)",
    args: ["run", "validate:genericness-qa"],
  },
  {
    label: "validate:evidence-pipeline",
    args: ["run", "validate:evidence-pipeline"],
  },
  {
    label: "validate:recovery-tone",
    args: ["run", "validate:recovery-tone"],
  },
  {
    label: "validate:insight-science",
    args: ["run", "validate:insight-science"],
  },
];

const failures = [];

for (const step of STEPS) {
  process.stdout.write(`\n==> ${step.label}\n`);
  const result = spawnSync("npm", step.args, {
    cwd: ROOT,
    stdio: "inherit",
    env: process.env,
  });
  if (result.status !== 0) {
    failures.push(step.label);
  }
}

if (failures.length > 0) {
  console.error(
    `\nvalidate-insight-quality-gate failed after ${STEPS.length - failures.length}/${STEPS.length} steps:\n${failures.join("\n")}`,
  );
  process.exit(1);
}

console.log("\nvalidate-insight-quality-gate ok — all insight-quality validators passed in order");
