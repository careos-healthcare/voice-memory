#!/usr/bin/env node
/**
 * Archive Prompt Engine v1 — conversation starters only.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];
const fail = (msg) => failures.push(msg);

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function mustExist(rel) {
  if (!fs.existsSync(path.join(ROOT, rel))) fail(`missing ${rel}`);
}

const FORBIDDEN = [
  /\byou should\b/i,
  /\byou need to\b/i,
  /\btry to\b/i,
  /\brecommend/i,
  /\badvice\b/i,
  /\bcoach/i,
  /\btherapy\b/i,
  /\bself-improvement\b/i,
  /\bjournaling exercise\b/i,
  /\bwork on yourself\b/i,
];

const PROMPT_FILES = [
  "packages/shared/lib/archive/archive-prompt-engine.ts",
  "packages/shared/lib/archive/archive-prompt-copy.ts",
  "packages/shared/lib/archive/archive-record-copy.ts",
  "apps/web/components/recording/LowEffortMode.tsx",
  "apps/web/components/recording/ArchivePostSaveLoop.tsx",
];

for (const rel of [
  "packages/shared/types/archive-prompt.ts",
  ...PROMPT_FILES,
  "packages/shared/lib/metrics/archive-prompt-events.ts",
  "scripts/validate-archive-prompt-engine.mjs",
]) {
  mustExist(rel);
}

const engine = read("packages/shared/lib/archive/archive-prompt-engine.ts");
if (!engine.includes("buildArchivePrompts")) fail("missing buildArchivePrompts");
if (!engine.includes("pickArchiveDisplayPrompts")) fail("missing pickArchiveDisplayPrompts");
if (!engine.includes("buildPostSaveFollowUp")) fail("missing buildPostSaveFollowUp");
for (const dep of [
  "buildArchiveBeliefView",
  "buildArchiveImplications",
  "buildArchiveOpenQuestions",
  "buildArchiveSilenceView",
  "buildBeliefSurvivalView",
  "readBeliefTimelineHistory",
]) {
  if (!engine.includes(dep)) fail(`engine must use ${dep}`);
}
if (/\bfetch\s*\(/.test(engine) || /\bopenai\b/i.test(engine)) {
  fail("archive-prompt-engine must not call LLM APIs");
}

for (const type of [
  "SUPPORT_PROMPT",
  "CHALLENGE_PROMPT",
  "MISSING_AREA_PROMPT",
  "RECENT_CHANGE_PROMPT",
  "OPEN_QUESTION_PROMPT",
  "GENERAL_CAPTURE_PROMPT",
]) {
  if (!engine.includes(type)) fail(`engine missing type ${type}`);
}

for (const rel of PROMPT_FILES) {
  const src = read(rel).replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
  for (const pattern of FORBIDDEN) {
    if (pattern.test(src)) fail(`${rel} contains forbidden tone (${pattern})`);
  }
}

const recordCopy = read("packages/shared/lib/archive/archive-record-copy.ts");
if (!recordCopy.includes("What's on your mind?")) {
  fail("record copy missing headline");
}
if (!recordCopy.includes("I don't know what to talk about")) {
  fail("record copy missing low effort button");
}

const lowEffort = read("apps/web/components/recording/LowEffortMode.tsx");
if (!lowEffort.includes("low-effort-mode")) fail("LowEffortMode missing test id");
if (!lowEffort.includes("trackArchivePromptShown")) fail("LowEffortMode must track shown");
if (!lowEffort.includes("trackArchivePromptRefreshed")) fail("LowEffortMode must track refresh");

const events = read("packages/shared/lib/metrics/archive-prompt-events.ts");
for (const name of [
  "archive_prompt_shown",
  "archive_prompt_selected",
  "archive_prompt_refreshed",
  "archive_prompt_recorded",
]) {
  if (!events.includes(name)) fail(`missing event ${name}`);
}

const recorder = read("apps/web/components/Recorder.tsx");
if (!recorder.includes("LowEffortMode")) fail("Recorder must include LowEffortMode");
if (!recorder.includes("ArchivePostSaveLoop")) fail("Recorder must include post-save loop");

const shell = read("apps/web/components/capture/ZeroStateRecorderShell.tsx");
if (!shell.includes("RECORD_SCREEN_HEADLINE")) fail("ZeroStateRecorderShell must show record framing");

const mobileRecord = read("apps/mobile/lib/screens/record_screen.dart");
const mobilePrompts = read("apps/mobile/lib/widgets/low_effort_prompts.dart");
if (!mobileRecord.includes("What's on your mind")) {
  fail("mobile record screen missing headline");
}
if (!mobileRecord.includes("LowEffortPrompts") && !mobilePrompts.includes("talk about")) {
  fail("mobile must wire low effort prompts");
}
if (!read("apps/mobile/lib/features/archive_prompt/archive_prompt_engine.dart").includes(
  "buildArchivePrompts",
)) {
  fail("mobile archive_prompt_engine missing buildArchivePrompts");
}

const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
if (!pkg.scripts?.["validate:archive-prompt-engine"]) {
  fail("package.json missing validate:archive-prompt-engine");
}

if (failures.length) {
  console.error("validate-archive-prompt-engine failed:\n", failures.join("\n"));
  process.exit(1);
}
console.log("validate-archive-prompt-engine ok");
