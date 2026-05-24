#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const REQUIRED_FILES = [
  "lib/restraint/silence-intelligence.ts",
  "lib/restraint/silence-intelligence-observation.ts",
  "lib/debug/silence-intelligence.ts",
  "app/debug/silence-intelligence/page.tsx",
  "components/restraint/QuietSilenceLine.tsx",
  "types/silence-intelligence.ts",
];

const REQUIRED_EVENTS = [
  "silence_state_entered",
  "silence_state_exited",
  "return_after_silence",
  "reflection_during_silence",
];

const REQUIRED_USER_LINES = [
  "Nothing needs to surface right now.",
  "You can just leave this here.",
];

const FORBIDDEN_IN_USER_COMPONENTS = [
  { re: /\bguilt\b/i, label: "guilt" },
  { re: /\bwe miss you\b/i, label: "we miss you" },
  { re: /\bdon't forget\b/i, label: "don't forget" },
  { re: /\byou haven't\b/i, label: "you haven't" },
];

const missing = REQUIRED_FILES.filter((rel) => !fs.existsSync(path.join(ROOT, rel)));
if (missing.length > 0) {
  console.error("Silence intelligence validation failed — missing files:\n");
  for (const file of missing) console.error(`  ${file}`);
  process.exit(1);
}

const core = fs.readFileSync(path.join(ROOT, "lib/restraint/silence-intelligence.ts"), "utf8");
for (const line of REQUIRED_USER_LINES) {
  if (!core.includes(line)) {
    console.error(`Silence intelligence validation failed — missing user line: "${line}"`);
    process.exit(1);
  }
}

for (const state of ["normal", "quiet", "very_quiet", "almost_silent"]) {
  if (!core.includes(state)) {
    console.error(`Silence intelligence validation failed — missing state: ${state}`);
    process.exit(1);
  }
}

const observation = fs.readFileSync(
  path.join(ROOT, "lib/restraint/silence-intelligence-observation.ts"),
  "utf8",
);
for (const event of REQUIRED_EVENTS) {
  if (!observation.includes(event)) {
    console.error(`Silence intelligence validation failed — missing event: ${event}`);
    process.exit(1);
  }
}

if (!core.includes("isSilenceIntelligenceEnabled") || !core.includes("setSilenceIntelligenceEnabled")) {
  console.error("Silence intelligence validation failed — missing settings preference API.");
  process.exit(1);
}

const settings = fs.readFileSync(
  path.join(ROOT, "components/settings/PersonalizationSettings.tsx"),
  "utf8",
);
if (!settings.includes("Silence intelligence")) {
  console.error("Silence intelligence validation failed — missing settings toggle.");
  process.exit(1);
}

const quietLine = fs.readFileSync(
  path.join(ROOT, "components/restraint/QuietSilenceLine.tsx"),
  "utf8",
);
for (const { re, label } of FORBIDDEN_IN_USER_COMPONENTS) {
  if (re.test(quietLine)) {
    console.error(`Silence intelligence validation failed — banned phrase in QuietSilenceLine: ${label}`);
    process.exit(1);
  }
}

console.log("Silence intelligence restraint validation passed.");
