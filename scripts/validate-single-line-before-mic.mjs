#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

const quiet = fs.readFileSync(
  path.join(ROOT, "packages/shared/lib/refinement/quiet-presentation.ts"),
  "utf8",
);
if (!quiet.includes("preMicContinuityLine")) {
  failures.push("quiet-presentation must use preMicContinuityLine");
}
if (quiet.includes("homepageContinuationNotes")) {
  failures.push("quiet-presentation must not stack homepage continuation notes before mic");
}

const recorder = fs.readFileSync(path.join(ROOT, "apps/web/components/Recorder.tsx"), "utf8");
const micHome = fs.readFileSync(path.join(ROOT, "apps/web/components/reflex/MicCentricHome.tsx"), "utf8");
if (!recorder.includes("continuityLine") && !micHome.includes("preserveQuote")) {
  failures.push("recorder/mic home must support a single continuity line");
}

const reflex = fs.readFileSync(path.join(ROOT, "apps/web/app/page.tsx"), "utf8");
if (!reflex.includes("reflexContinuityLine")) {
  failures.push("homepage must wire reflexContinuityLine");
}

const bannedBeforeMic = [
  "MemoryTimelineDashboard",
  "PatternsDetectedSection",
  "Mood snapshot",
];
for (const token of bannedBeforeMic) {
  if (recorder.includes(token) || micHome.includes(token)) {
    failures.push(`pre-mic surface must not include ${token}`);
  }
}

if (failures.length > 0) {
  console.error("validate-single-line-before-mic failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-single-line-before-mic ok");
