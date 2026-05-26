#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED = [
  "lib/reflex/reflex-capture.ts",
  "lib/reflex/reflex-restraint.ts",
  "lib/reflex/read-vs-speak.ts",
  "lib/reflex/reflex-score.ts",
  "lib/reflex/reflex-observation.ts",
  "lib/reflex/reflex-copy.ts",
  "lib/reflex/reflex-context.ts",
  "lib/reflex/open-without-record.ts",
  "lib/mobile/quick-entry.ts",
  "types/reflex.ts",
  "components/reflex/MicCentricHome.tsx",
  "app/record/page.tsx",
];

const BANNED = [
  /\byou should\b/i,
  /\btherapy\b/i,
  /\bcoach\b/i,
  /\baction plan\b/i,
  /\brecommendation\b/i,
  /\bemotional score\b/i,
  /\bdashboard\b/i,
  /\bhabit streak\b/i,
  /\bthoughts that kept circling\b/i,
];

const failures = [];

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(ROOT, rel))) {
    failures.push(`missing ${rel}`);
  }
}

const capture = fs.readFileSync(
  path.join(ROOT, "lib/reflex/reflex-capture.ts"),
  "utf8",
);
for (const token of [
  "detectReflexCapture",
  "likelyReflexMoment",
  "shouldBypassHomepage",
  "bypassScore",
  "triggerType",
]) {
  if (!capture.includes(token)) {
    failures.push(`reflex-capture missing ${token}`);
  }
}

const home = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
if (!home.includes("MicCentricHome") || !home.includes("detectReflexCapture")) {
  failures.push("homepage must wire reflex capture and MicCentricHome");
}
if (!home.includes("shouldActivateReflexSilenceFirst")) {
  failures.push("homepage must support silence-first reflex");
}

const micHome = fs.readFileSync(
  path.join(ROOT, "components/reflex/MicCentricHome.tsx"),
  "utf8",
);
if ((micHome.match(/<Recorder/g) ?? []).length !== 1) {
  failures.push("MicCentricHome must render exactly one Recorder");
}
const continuityBlocks = (micHome.match(/<p className=/g) ?? []).length;
if (continuityBlocks > 1) {
  failures.push("MicCentricHome must have at most one continuity line before mic");
}

const recorder = fs.readFileSync(path.join(ROOT, "components/Recorder.tsx"), "utf8");
if (!recorder.includes("reflexFastBoot") || !recorder.includes("reflexCapture")) {
  failures.push("Recorder must accept reflexFastBoot and reflexCapture");
}

const report = fs.readFileSync(
  path.join(ROOT, "lib/behavior/behavior-truth-report.ts"),
  "utf8",
);
if (!report.includes("buildReadVsSpeakReport") || !report.includes("buildReflexScoreSnapshot")) {
  failures.push("behavior-truth-report must include read-vs-speak and reflex score");
}

const panel = fs.readFileSync(
  path.join(ROOT, "components/debug/BehaviorTruthPanel.tsx"),
  "utf8",
);
if (!panel.includes("Read vs speak") || !panel.includes("Reflex decompression score")) {
  failures.push("BehaviorTruthPanel must surface read-vs-speak and reflex score");
}

const scanDirs = ["lib/reflex", "components/reflex", "lib/mobile/quick-entry.ts"];
for (const rel of scanDirs) {
  const full = path.join(ROOT, rel);
  if (!fs.existsSync(full)) continue;
  const files =
    rel.endsWith(".ts")
      ? [full]
      : fs.readdirSync(full).map((f) => path.join(full, f));
  for (const file of files) {
    if (!file.endsWith(".ts") && !file.endsWith(".tsx")) continue;
    const text = fs.readFileSync(file, "utf8");
    for (const re of BANNED) {
      if (re.test(text)) {
        failures.push(`${path.relative(ROOT, file)}: banned ${re}`);
      }
    }
  }
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:reflex-loop")) {
  failures.push("package.json must wire validate:reflex-loop");
}

if (failures.length > 0) {
  console.error("validate-reflex-loop failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-reflex-loop ok");
