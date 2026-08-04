#!/usr/bin/env node
/**
 * Structural screen-reader readiness — static source checks + Playwright runtime.
 * Does NOT replace VoiceOver/TalkBack on device.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

const srSources = [
  ["components/Recorder.tsx", "aria-live"],
  ["components/recording/MicPermissionPanel.tsx", "aria-live"],
  ["components/system/SyncStatus.tsx", 'role="status"'],
  ["components/capture/RecordCaptureChrome.tsx", "aria-live"],
  ["components/system/LoadingState.tsx", "aria-live"],
];

for (const [rel, needle] of srSources) {
  const text = read(rel);
  if (!text.includes(needle)) {
    failures.push(`${rel} missing ${needle} for SR structure`);
  }
}

const deleteEntry = read("app/entry/[id]/page.tsx");
if (!deleteEntry.includes('aria-label="Delete moment"')) {
  failures.push("entry delete control needs aria-label");
}

const pkg = read("package.json");
if (!pkg.includes('"validate:screen-reader-structure"')) {
  failures.push("package.json missing validate:screen-reader-structure script");
}

if (failures.length) {
  console.error("validate:screen-reader-structure static FAILED:\n");
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}

if (process.env.VOICEMEMORY_SKIP_E2E === "1") {
  console.warn(
    "validate:screen-reader-structure — static OK; E2E skipped (VOICEMEMORY_SKIP_E2E=1)",
  );
  process.exit(0);
}

if (!fs.existsSync(path.join(ROOT, "e2e/fixtures/a11y-dynamic-permutations.json"))) {
  console.error("Missing a11y-dynamic-permutations.json — run generate:a11y-dynamic-permutations");
  process.exit(1);
}

const e2e = spawnSync(
  "npx",
  ["playwright", "test", "-c", "playwright.ui.config.ts", "--project=sr-structure"],
  { cwd: ROOT, stdio: "inherit", env: process.env },
);

if (e2e.status !== 0) process.exit(1);
console.log("validate:screen-reader-structure passed (static + runtime)");
