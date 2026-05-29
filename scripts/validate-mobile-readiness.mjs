#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/mobile/platform.ts",
  "lib/mobile/mobile-readiness.ts",
  "lib/mobile/microphone.ts",
  "lib/mobile/storage-audit.ts",
  "lib/notifications/scheduler.ts",
  "lib/notifications/triggers.ts",
  "lib/notifications/notification-copy.ts",
  "app/manifest.ts",
  "app/icon.tsx",
  "app/apple-icon.tsx",
  "public/sw.js",
  "app/offline/page.tsx",
  "components/mobile/PwaBootstrap.tsx",
  "components/mobile/InstallPrompt.tsx",
  "app/internal/mobile-readiness/page.tsx",
  "docs/MOBILE_SUBSCRIPTION_STRATEGY.md",
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const platform = fs.readFileSync(path.join(ROOT, "lib/mobile/platform.ts"), "utf8");
for (const fn of ["isNativeWrapper", "isPWA", "supportsPush", "supportsBackgroundAudio"]) {
  if (!platform.includes(`export function ${fn}`)) {
    failures.push(`platform.ts missing ${fn}`);
  }
}

const install = fs.readFileSync(path.join(ROOT, "components/mobile/InstallPrompt.tsx"), "utf8");
if (!install.includes("DISMISS_KEY") || !install.includes("Not now")) {
  failures.push("InstallPrompt must support dismiss without nag loops");
}

const copy = fs.readFileSync(path.join(ROOT, "lib/notifications/notification-copy.ts"), "utf8");
for (const banned of ["come back", "streak", "don't forget", "upgrade now"]) {
  if (copy.toLowerCase().includes(banned)) {
    failures.push(`notification-copy contains banned phrase: ${banned}`);
  }
}

const providers = fs.readFileSync(path.join(ROOT, "app/providers.tsx"), "utf8");
if (!providers.includes("PwaBootstrap")) {
  failures.push("providers must mount PwaBootstrap");
}

const storageBootstrap = fs.readFileSync(
  path.join(ROOT, "components/providers/StorageBootstrap.tsx"),
  "utf8",
);
if (!storageBootstrap.includes("runWhenIdle")) {
  failures.push("StorageBootstrap must defer work via runWhenIdle");
}

if (failures.length > 0) {
  console.error("Mobile readiness validation failed:\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}

console.log("Mobile readiness validation passed.");
