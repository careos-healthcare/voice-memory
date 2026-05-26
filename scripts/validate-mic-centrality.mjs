#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

const failures = [];

const micHome = fs.readFileSync(
  path.join(ROOT, "components/reflex/MicCentricHome.tsx"),
  "utf8",
);
const bannedInMicHome = [
  "HabitLoopCard",
  "ContextualReminderCards",
  "PrimaryCallbackNote",
  "ContinuationNotes",
  "CirclingThoughtsSection",
  "SortThisOutAloudPrompt",
  "OpenLoopReturnPrompt",
];
for (const token of bannedInMicHome) {
  if (micHome.includes(token)) {
    failures.push(`MicCentricHome must not include ${token}`);
  }
}

const home = fs.readFileSync(path.join(ROOT, "app/page.tsx"), "utf8");
if (!home.includes("micCentric")) {
  failures.push("homepage must branch on micCentric");
}

const micBranch = home.match(/\{micCentric \?\s*\(\s*<MicCentricHome[\s\S]*?\/>/);
if (!micBranch) {
  failures.push("mic-centric branch must render only MicCentricHome");
} else {
  for (const token of bannedInMicHome) {
    if (micBranch[0].includes(token)) {
      failures.push(`mic-centric homepage branch must not include ${token}`);
    }
  }
}

if (!home.includes("{!micCentric ?")) {
  failures.push("homepage continuity stack must be gated behind !micCentric");
}

const recordPage = fs.readFileSync(path.join(ROOT, "app/record/page.tsx"), "utf8");
if (!recordPage.includes("reflexFastBoot") || !recordPage.includes("Recorder")) {
  failures.push("/record quick-entry must open Recorder with reflexFastBoot");
}

const quickEntry = fs.readFileSync(
  path.join(ROOT, "lib/mobile/quick-entry.ts"),
  "utf8",
);
if (!quickEntry.includes("QUICK_ENTRY_PATH") || !quickEntry.includes("parseQuickEntryIntent")) {
  failures.push("quick-entry must export path and intent parsing");
}

const pkg = fs.readFileSync(path.join(ROOT, "package.json"), "utf8");
if (!pkg.includes("validate:mic-centrality")) {
  failures.push("package.json must wire validate:mic-centrality");
}

if (failures.length > 0) {
  console.error("validate-mic-centrality failed:\n", failures.join("\n"));
  process.exit(1);
}

console.log("validate-mic-centrality ok");
