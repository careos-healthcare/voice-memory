#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/reflection/reflection-friction-report.ts",
  "lib/reflection/record-return.ts",
  "lib/reflection/after-save-continuity.ts",
  "lib/reflection/quick-reflection.ts",
  "lib/reflection/start-record-return.ts",
  "types/reflection-friction.ts",
  "types/record-return.ts",
  "app/debug/reflection-friction/page.tsx",
  "components/debug/ReflectionFrictionPanel.tsx",
  "components/recording/RecordReturnAnchor.tsx",
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const report = fs.readFileSync(
  path.join(ROOT, "lib/reflection/reflection-friction-report.ts"),
  "utf8",
);
if (!report.includes("buildReflectionFrictionReport")) {
  failures.push("reflection-friction-report must export buildReflectionFrictionReport");
}

const page = fs.readFileSync(
  path.join(ROOT, "app/debug/reflection-friction/page.tsx"),
  "utf8",
);
for (const token of ["ReflectionFrictionPanel", "buildReflectionFrictionReport"]) {
  if (!page.includes(token)) {
    failures.push(`reflection-friction page missing ${token}`);
  }
}

const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
if (!recorder.includes("RecordReturnAnchor") || !recorder.includes("recordReturn")) {
  failures.push("Recorder must wire recordReturn and RecordReturnAnchor");
}

if (failures.length > 0) {
  console.error("validate-reflection-friction failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-reflection-friction ok");
