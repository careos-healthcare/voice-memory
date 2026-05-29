#!/usr/bin/env node
/**
 * Final measurable UI proof — runs static validators + Playwright UI/a11y/mobile/debug suites.
 */
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PLAYWRIGHT_BROWSERS_PATH = path.join(
  ROOT,
  "node_modules",
  "playwright-core",
  ".local-browsers",
);

const baseEnv = {
  ...process.env,
  CI: "1",
  EMAIL_DISABLED: "true",
  VOICEMEMORY_UI_E2E: "1",
  PLAYWRIGHT_BROWSERS_PATH,
  AUTH_SECRET:
    process.env.AUTH_SECRET ?? "e2e-test-auth-secret-min-32-chars-long",
};

const steps = [
  ["validate:ui", "npm", ["run", "validate:ui"]],
  ["validate:ux-copy", "npm", ["run", "validate:ux-copy"]],
  ["validate:accessibility-strict", "npm", ["run", "validate:accessibility-strict"]],
  [
    "playwright install chromium",
    "npx",
    ["playwright", "install", "chromium"],
  ],
  ["build", "npm", ["run", "build"]],
  ["test:e2e:ui (smoke)", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=smoke"]],
  ["test:e2e:ui (mobile 375)", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=mobile"]],
  ["test:a11y", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=a11y"]],
  ["debug regression", "npx", ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=debug"]],
];

let failed = false;

for (const [name, cmd, args] of steps) {
  console.log(`\n— ${name} —`);
  const result = spawnSync(cmd, args, {
    stdio: "inherit",
    env: baseEnv,
  });
  if (result.status !== 0) {
    console.error(`FAILED: ${name}`);
    failed = true;
    break;
  }
}

if (failed) {
  console.error("\nvalidate-ui-final FAILED");
  process.exit(1);
}

console.log("\nvalidate-ui-final ok");
process.exit(0);
