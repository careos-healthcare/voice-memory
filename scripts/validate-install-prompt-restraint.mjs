#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const gate = fs.readFileSync(
  path.join(ROOT, "lib/mobile/install-prompt-gate.ts"),
  "utf8",
);
for (const token of [
  "hasInstallPromptEligibility",
  "shouldShowInstallPrompt",
  "countCompletedReflections",
  "isRecorderSurfaceActive",
  "isMicPermissionRequestActive",
  "/record",
  "/entry/",
]) {
  if (!gate.includes(token)) failures.push(`install-prompt-gate missing ${token}`);
}

const install = fs.readFileSync(
  path.join(ROOT, "components/mobile/InstallPrompt.tsx"),
  "utf8",
);
if (!install.includes("shouldShowInstallPrompt") || !install.includes("usePathname")) {
  failures.push("InstallPrompt must gate on route and eligibility");
}

if (failures.length > 0) {
  console.error("validate-install-prompt-restraint failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-install-prompt-restraint ok");
