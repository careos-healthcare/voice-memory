#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/capture/zero-state-recorder.ts",
  "components/capture/ZeroStateRecorderShell.tsx",
  "app/record/page.tsx",
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) failures.push(`missing ${rel}`);
}

const zero = fs.readFileSync(path.join(ROOT, "lib/capture/zero-state-recorder.ts"), "utf8");
for (const fn of [
  "shouldUseZeroStateRecorder",
  "getZeroStateRecorderLine",
  "getZeroStateRecorderMode",
]) {
  if (!zero.includes(fn)) failures.push(`zero-state-recorder missing ${fn}`);
}

const record = fs.readFileSync(path.join(ROOT, "app/record/page.tsx"), "utf8");
if (!record.includes("ZeroStateRecorderShell")) {
  failures.push("/record must use ZeroStateRecorderShell");
}
for (const heavy of [
  "LivingResurfacingNote",
  "OpenLoopReturnPrompt",
  "CirclingThoughtsSection",
  "buildQuietHomepagePresentation",
]) {
  if (record.includes(heavy)) failures.push(`/record must not import ${heavy}`);
}

const shell = fs.readFileSync(
  path.join(ROOT, "components/capture/ZeroStateRecorderShell.tsx"),
  "utf8",
);
if (!shell.includes("Recorder")) failures.push("ZeroStateRecorderShell must render Recorder");

if (failures.length > 0) {
  console.error("validate-capture-transition failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-capture-transition ok");
