#!/usr/bin/env node
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pathToFileURL } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const gatePath = path.join(ROOT, "packages/shared/lib/reflection/reflection-quality-gate.ts");
const labelPath = path.join(ROOT, "packages/shared/lib/reflection/recorder-primary-label.ts");

const failures = [];

const fs = await import("node:fs");
const gateSrc = fs.readFileSync(gatePath, "utf8");
if (!gateSrc.includes("isJunkReflectionTranscript")) {
  failures.push("reflection-quality-gate missing junk detector");
}
if (!gateSrc.includes("isPrimarySurfacedReflection")) {
  failures.push("reflection-quality-gate missing primary surface filter");
}

const labelSrc = fs.readFileSync(labelPath, "utf8");
if (!labelSrc.includes("Say it now")) {
  failures.push('recorder-primary-label must use "Say it now"');
}

const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
if (!recorder.includes("RECORDER_PRIMARY_LABEL")) {
  failures.push("Recorder must use RECORDER_PRIMARY_LABEL");
}

const mod = await import(pathToFileURL(gatePath).href);

const junk = [
  "thank you for watching",
  "this is just a test",
  "test",
  "1, 2, 3, 4, 5",
  "one two three four five",
  "please please please",
];
for (const sample of junk) {
  if (!mod.isJunkReflectionTranscript(sample)) {
    failures.push(`expected junk: ${sample}`);
  }
}

if (mod.isJunkReflectionTranscript("I keep thinking about the conversation with my sister and what I should say tomorrow.")) {
  failures.push("meaningful reflection should not be junk");
}

if (failures.length > 0) {
  console.error("validate-reflection-quality-gate failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-reflection-quality-gate ok");
