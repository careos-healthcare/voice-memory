#!/usr/bin/env node
/**
 * Full-surface accessibility — static launch-surface gate + axe E2E (unless skipped).
 */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function run(cmd, args, env = {}) {
  const r = spawnSync(cmd, args, {
    cwd: ROOT,
    stdio: "inherit",
    env: { ...process.env, ...env },
  });
  return r.status === 0;
}

if (!run("node", ["scripts/validate-accessibility-strict.mjs"])) {
  process.exit(1);
}
if (!run("node", ["scripts/validate-wcag-launch-surface.mjs"])) {
  process.exit(1);
}

if (process.env.VOICEMEMORY_SKIP_E2E === "1") {
  console.warn(
    "validate:accessibility-full — static gates passed; E2E skipped (VOICEMEMORY_SKIP_E2E=1)",
  );
  process.exit(0);
}

if (!run("npm", ["run", "build"])) {
  process.exit(1);
}
if (!run("npm", ["run", "test:a11y:full"])) {
  process.exit(1);
}
if (!run("npm", ["run", "test:a11y:dynamic"])) {
  process.exit(1);
}
if (!run("npm", ["run", "test:a11y:dynamic-permutations"])) {
  process.exit(1);
}
if (!run("npm", ["run", "validate:screen-reader-structure"])) {
  process.exit(1);
}

console.log(
  "validate:accessibility-full passed (static + full + dynamic + permutations + SR structure)",
);
