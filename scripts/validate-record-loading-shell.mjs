#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const banned = [/Recorder loading/i, /bg-white\b/, /background:\s*white/i];

const files = [
  "apps/web/components/capture/RecordLoadingShell.tsx",
  "apps/web/components/capture/MicCaptureFallback.tsx",
  "apps/web/app/record/loading.tsx",
];

for (const rel of files) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const shell = fs.readFileSync(
  path.join(ROOT, "apps/web/components/capture/RecordLoadingShell.tsx"),
  "utf8",
);
if (!shell.includes("Opening recorder")) failures.push("RecordLoadingShell needs Opening recorder…");
if (!shell.includes("bg-red-500")) failures.push("RecordLoadingShell needs red mic visual");
if (!shell.includes("bg-zinc-950") && !shell.includes("RecordFullscreenCapture")) {
  failures.push("RecordLoadingShell must use dark capture chrome");
}

for (const rel of ["apps/web/components/capture/MicCaptureFallback.tsx", "apps/web/app/record/page.tsx"]) {
  const text = fs.readFileSync(path.join(ROOT, rel), "utf8");
  for (const re of banned) {
    if (re.test(text)) failures.push(`${rel} must not match ${re}`);
  }
}

const recordLayout = fs.readFileSync(path.join(ROOT, "apps/web/app/record/layout.tsx"), "utf8");
if (!recordLayout.includes("RecordFullscreenCapture")) {
  failures.push("record layout must use RecordFullscreenCapture");
}

if (failures.length > 0) {
  console.error("validate-record-loading-shell failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-record-loading-shell ok");
