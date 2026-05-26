#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const INSTALL_FILE = path.join(ROOT, "components/mobile/InstallPrompt.tsx");
const SCAN = [
  path.join(ROOT, "components/mobile/InstallPrompt.tsx"),
  path.join(ROOT, "components/mobile/PwaBootstrap.tsx"),
  path.join(ROOT, "app/pricing/page.tsx"),
];

const BANNED = [
  /\binstall now\b/i,
  /\bact now\b/i,
  /\bhurry\b/i,
  /\blimited time\b/i,
  /\byou must install\b/i,
  /\bdon't miss\b/i,
];

const failures = [];

const install = fs.readFileSync(INSTALL_FILE, "utf8");
if (!install.includes("beforeinstallprompt")) {
  failures.push("InstallPrompt must listen for beforeinstallprompt");
}
if (!install.match(/dismiss|Not now/i)) {
  failures.push("InstallPrompt must allow dismiss");
}

for (const file of SCAN) {
  const content = fs.readFileSync(file, "utf8");
  for (const re of BANNED) {
    if (re.test(content)) {
      failures.push(`${path.relative(ROOT, file)}: banned phrase ${re}`);
    }
  }
}

const manifest = fs.readFileSync(path.join(ROOT, "app/manifest.ts"), "utf8");
if (!manifest.includes('display: "standalone"')) {
  failures.push("manifest must use standalone display");
}

if (failures.length > 0) {
  console.error("PWA restraint validation failed:\n");
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}

console.log("PWA restraint validation passed.");
